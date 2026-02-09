" ============================================================================
" File:        autoload/grok/completion.vim
" Description: Inline code completion via xAI API (ghost-text suggestions)
" Author:      vim-grok contributors
" License:     MIT
" ============================================================================

" ---- Guard ----------------------------------------------------------------
if exists('g:autoloaded_grok_completion')
  finish
endif
let g:autoloaded_grok_completion = 1

" ---- Highlight & text-property setup -------------------------------------
let s:hlgroup = 'GrokSuggestion'
if !has('nvim')
  if empty(prop_type_get(s:hlgroup))
    call prop_type_add(s:hlgroup, {'highlight': s:hlgroup})
  endif
endif

" ---- State ---------------------------------------------------------------
let s:timer_id = -1
let s:completion_job = v:null
let s:current_suggestion = ''    " full text to insert on accept
let s:suggestion_lnum = 0        " line where suggestion was placed
let s:suggestion_col = 0         " col where suggestion starts
let s:request_seq = 0            " monotonic counter to discard stale responses

" ---- Config helpers ------------------------------------------------------
function! s:api_key() abort
  let l:key = get(g:, 'grok_xai_api_key', $XAI_API_KEY)
  return l:key
endfunction

function! s:model() abort
  return get(g:, 'grok_completion_model', 'grok-3-mini-fast')
endfunction

function! s:api_url() abort
  return get(g:, 'grok_xai_api_url', 'https://api.x.ai/v1/chat/completions')
endfunction

function! s:debounce_ms() abort
  return get(g:, 'grok_completion_debounce', 300)
endfunction

function! s:max_tokens() abort
  return get(g:, 'grok_completion_max_tokens', 256)
endfunction

function! s:context_lines() abort
  return get(g:, 'grok_completion_context_lines', 50)
endfunction

function! s:enabled() abort
  if !get(g:, 'grok_completion_enabled', 0)
    return 0
  endif
  if empty(s:api_key())
    return 0
  endif
  " Respect per-buffer disable
  if !get(b:, 'grok_completion_enabled', 1)
    return 0
  endif
  " Skip special buffers
  if &buftype !=# ''
    return 0
  endif
  return 1
endfunction

" ---- Public API ----------------------------------------------------------

" Called on TextChangedI / CursorMovedI (debounced)
function! grok#completion#Trigger() abort
  if !s:enabled()
    return
  endif
  " Cancel pending timer
  if s:timer_id != -1
    call timer_stop(s:timer_id)
  endif
  let s:timer_id = timer_start(s:debounce_ms(), function('s:RequestCompletion'))
endfunction

" Clear current ghost text
function! grok#completion#Clear() abort
  if s:timer_id != -1
    call timer_stop(s:timer_id)
    let s:timer_id = -1
  endif
  " Kill in-flight request
  if s:completion_job isnot v:null
    try
      call job_stop(s:completion_job)
    catch
    endtry
    let s:completion_job = v:null
  endif
  call s:ClearGhostText()
  let s:current_suggestion = ''
  return ''
endfunction

" Accept the current suggestion (returns keystrokes to insert)
function! grok#completion#Accept() abort
  if empty(s:current_suggestion) || mode() !~# '^[iR]'
    " No suggestion — fall through to normal Tab
    return get(g:, 'grok_completion_tab_fallback', pumvisible() ? "\<C-N>" : "\t")
  endif
  let l:text = s:current_suggestion
  call grok#completion#Clear()
  " Insert via expression register to handle special chars
  let s:_insert_text = l:text
  return "\<C-R>\<C-O>=grok#completion#_ConsumeInsert()\<CR>"
endfunction

" Helper consumed by Accept via <C-R>=
function! grok#completion#_ConsumeInsert() abort
  try
    return remove(s:, '_insert_text')
  catch
    return ''
  endtry
endfunction

" Dismiss suggestion (Esc key passthrough)
function! grok#completion#Dismiss() abort
  call grok#completion#Clear()
  return ''
endfunction

" Toggle completion on/off
function! grok#completion#Toggle() abort
  let g:grok_completion_enabled = !get(g:, 'grok_completion_enabled', 0)
  if !g:grok_completion_enabled
    call grok#completion#Clear()
  endif
  echo 'Grok completion ' . (g:grok_completion_enabled ? 'enabled' : 'disabled')
endfunction

" ---- Ghost text rendering ------------------------------------------------
function! s:ClearGhostText() abort
  call prop_remove({'type': s:hlgroup, 'all': v:true})
endfunction

function! s:RenderGhostText(text, lnum, col) abort
  call s:ClearGhostText()
  if empty(a:text) || mode() !~# '^[iR]'
    return
  endif

  let l:lines = split(a:text, "\n", 1)
  if empty(l:lines)
    return
  endif

  " First line: inline after cursor
  call prop_add(a:lnum, a:col, {'type': s:hlgroup, 'text': l:lines[0]})

  " Subsequent lines: below
  if len(l:lines) > 1
    for l:i in range(1, len(l:lines) - 1)
      let l:line = l:lines[l:i]
      " Convert leading tabs to spaces for display
      let l:ntabs = 0
      for l:c in split(l:line, '\zs')
        if l:c ==# "\t"
          let l:ntabs += 1
        else
          break
        endif
      endfor
      let l:line = repeat(' ', l:ntabs * shiftwidth()) . strpart(l:line, l:ntabs)
      call prop_add(a:lnum, 0, {'type': s:hlgroup, 'text_align': 'below', 'text': l:line})
    endfor
  endif
endfunction

" ---- API request ---------------------------------------------------------
function! s:RequestCompletion(timer_id) abort
  let s:timer_id = -1
  if !s:enabled() || mode() !~# '^[iR]'
    return
  endif

  " Build context: lines before and after cursor
  let l:lnum = line('.')
  let l:col = col('.')
  let l:ft = &filetype
  let l:file = expand('%:t')
  let l:ctx_lines = s:context_lines()

  " Prefix: lines before cursor + current line up to cursor
  let l:prefix_start = max([1, l:lnum - l:ctx_lines])
  let l:prefix_lines = getline(l:prefix_start, l:lnum - 1)
  let l:cur_line = getline(l:lnum)
  call add(l:prefix_lines, strpart(l:cur_line, 0, l:col - 1))
  let l:prefix = join(l:prefix_lines, "\n")

  " Suffix: rest of current line + lines after cursor
  let l:suffix_start = strpart(l:cur_line, l:col - 1)
  let l:suffix_end = min([line('$'), l:lnum + l:ctx_lines])
  let l:suffix_lines = [l:suffix_start]
  if l:lnum < l:suffix_end
    call extend(l:suffix_lines, getline(l:lnum + 1, l:suffix_end))
  endif
  let l:suffix = join(l:suffix_lines, "\n")

  " Build the prompt
  let l:system_prompt = 'You are a code completion engine. '
        \ . 'Given code before and after the cursor, output ONLY the code to insert at the cursor. '
        \ . 'Do not include explanations, markdown fences, or repeat existing code. '
        \ . 'If there is nothing to complete, output an empty string. '
        \ . 'Output raw code only.'

  let l:user_prompt = "File: " . l:file . "\nLanguage: " . l:ft
        \ . "\n\nCode before cursor:\n" . l:prefix
        \ . "\n\nCode after cursor:\n" . l:suffix
        \ . "\n\nProvide the code completion at the cursor position."

  " Build JSON payload
  let l:payload = json_encode({
        \ 'model': s:model(),
        \ 'messages': [
        \   {'role': 'system', 'content': l:system_prompt},
        \   {'role': 'user', 'content': l:user_prompt}
        \ ],
        \ 'max_tokens': s:max_tokens(),
        \ 'temperature': 0,
        \ 'stream': v:false
        \ })

  " Write payload to temp file (avoids shell quoting issues)
  let l:tmpfile = tempname()
  call writefile([l:payload], l:tmpfile)

  " Track this request
  let s:request_seq += 1
  let l:seq = s:request_seq
  let l:request_lnum = l:lnum
  let l:request_col = l:col

  " Build curl command
  let l:cmd = ['curl', '-s', '-X', 'POST', s:api_url(),
        \ '-H', 'Authorization: Bearer ' . s:api_key(),
        \ '-H', 'Content-Type: application/json',
        \ '-d', '@' . l:tmpfile]

  " Cancel any in-flight request
  if s:completion_job isnot v:null
    try | call job_stop(s:completion_job) | catch | endtry
  endif

  let l:ctx = {
        \ 'seq': l:seq, 'lnum': l:request_lnum, 'col': l:request_col,
        \ 'tmpfile': l:tmpfile, 'output': []
        \ }

  let s:completion_job = job_start(l:cmd, {
        \ 'in_io': 'null',
        \ 'out_cb': function('s:OnStdout', [l:ctx]),
        \ 'exit_cb': function('s:OnExit', [l:ctx]),
        \ 'out_mode': 'raw',
        \ 'err_io': 'null',
        \ })
endfunction

function! s:OnStdout(ctx, channel, msg) abort
  call add(a:ctx.output, a:msg)
endfunction

function! s:OnExit(ctx, job, status) abort
  " Clean up temp file
  call delete(a:ctx.tmpfile)
  let s:completion_job = v:null

  " Discard if stale (user moved or new request started)
  if a:ctx.seq != s:request_seq
    return
  endif
  if mode() !~# '^[iR]'
    return
  endif
  " Discard if cursor moved
  if line('.') != a:ctx.lnum || col('.') != a:ctx.col
    return
  endif
  if a:status != 0
    return
  endif

  " Parse response
  let l:raw = join(a:ctx.output, '')
  try
    let l:resp = json_decode(l:raw)
  catch
    return
  endtry

  let l:choices = get(l:resp, 'choices', [])
  if empty(l:choices)
    return
  endif
  let l:message = get(l:choices[0], 'message', {})
  let l:text = get(l:message, 'content', '')

  " Strip markdown fences if the model wraps output
  let l:text = substitute(l:text, '^```\w*\n', '', '')
  let l:text = substitute(l:text, '\n```\s*$', '', '')

  " Remove leading/trailing blank lines
  let l:text = substitute(l:text, '^\n\+', '', '')
  let l:text = substitute(l:text, '\n\+$', '', '')

  if empty(l:text)
    return
  endif

  let s:current_suggestion = l:text
  let s:suggestion_lnum = a:ctx.lnum
  let s:suggestion_col = a:ctx.col
  call s:RenderGhostText(l:text, a:ctx.lnum, a:ctx.col)
endfunction