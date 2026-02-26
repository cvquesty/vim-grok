" ============================================================================
" File:        autoload/grok.vim
" Description: Core functions for the vim-grok plugin (grok-cli interface)
" Author:      vim-grok contributors
" License:     MIT
" ============================================================================

" ---- Guard ----------------------------------------------------------------
if exists('g:autoloaded_grok')
  finish
endif
let g:autoloaded_grok = 1

" ---- Configuration Defaults -----------------------------------------------
function! s:get_binary() abort
  return get(g:, 'grok_binary', $HOME . '/.grok/bin/grok')
endfunction

function! s:get_model() abort
  return get(g:, 'grok_model', '')
endfunction

function! s:get_extra_args() abort
  return get(g:, 'grok_extra_args', '')
endfunction

function! s:get_yolo() abort
  return get(g:, 'grok_yolo', 0)
endfunction

" ---- State ----------------------------------------------------------------
let s:chat_session_id = ''
let s:grok_job = v:null

" ---- Utility: Shell-like string splitting (respects quotes) ---------------
function! s:shellsplit(str) abort
  let l:args = []
  let l:current = ''
  let l:in_quote = ''
  let l:i = 0
  while l:i < len(a:str)
    let l:c = a:str[l:i]
    if empty(l:in_quote)
      if l:c ==# '"' || l:c ==# "'"
        let l:in_quote = l:c
      elseif l:c ==# ' ' || l:c ==# "\t"
        if !empty(l:current)
          call add(l:args, l:current)
          let l:current = ''
        endif
      else
        let l:current .= l:c
      endif
    else
      if l:c ==# l:in_quote
        let l:in_quote = ''
      else
        let l:current .= l:c
      endif
    endif
    let l:i += 1
  endwhile
  if !empty(l:current)
    call add(l:args, l:current)
  endif
  return l:args
endfunction

" ---- Utility: Build the base command list ---------------------------------
function! s:base_cmd() abort
  let l:cmd = [s:get_binary()]
  let l:model = s:get_model()
  if !empty(l:model)
    call extend(l:cmd, ['-m', l:model])
  endif
  if s:get_yolo()
    call add(l:cmd, '--yolo')
  endif
  let l:extra = s:get_extra_args()
  if type(l:extra) == type([])
    call extend(l:cmd, l:extra)
  elseif type(l:extra) == type('') && !empty(l:extra)
    call extend(l:cmd, s:shellsplit(l:extra))
  endif
  return l:cmd
endfunction

" ---- Utility: Get visual selection ----------------------------------------
function! s:get_visual_selection() abort
  let [l:lnum1, l:col1] = getpos("'<")[1:2]
  let [l:lnum2, l:col2] = getpos("'>")[1:2]
  let l:lines = getline(l:lnum1, l:lnum2)
  if empty(l:lines)
    return ''
  endif
  " Trim last line to selection end, first line to selection start
  let l:lines[-1] = l:lines[-1][:l:col2 - 1]
  let l:lines[0]  = l:lines[0][l:col1 - 1:]
  return join(l:lines, "\n")
endfunction

" ---- Utility: Find a buffer by exact name (avoids glob pattern pitfalls) --
function! s:find_buf_exact(name) abort
  for l:i in range(1, bufnr('$'))
    if bufexists(l:i) && bufname(l:i) ==# a:name
      return l:i
    endif
  endfor
  return -1
endfunction

" ---- Utility: Open or reuse a Grok output buffer --------------------------
" Uses noautocmd for all window operations to prevent other plugins
" (airline, gitgutter, codeium, etc.) from interfering during setup.
" After opening/reusing the buffer, returns focus to the original window
" so the user can keep editing.
function! s:open_grok_buffer(name) abort
  let l:orig_win = winnr()
  let l:bufname = '[Grok] ' . a:name
  let l:existing = s:find_buf_exact(l:bufname)
  if l:existing != -1 && bufloaded(l:existing)
    " Jump to the window if visible, otherwise split
    let l:winnr = bufwinnr(l:existing)
    if l:winnr != -1
      noautocmd execute l:winnr . 'wincmd w'
    else
      noautocmd execute 'botright split'
      noautocmd execute 'buffer ' . l:existing
    endif
    " Clear the buffer
    setlocal modifiable
    silent %delete _
  else
    noautocmd execute 'botright split'
    noautocmd execute 'resize ' . max([8, &lines / 3])
    noautocmd execute 'enew'
    noautocmd execute 'file ' . fnameescape(l:bufname)
  endif
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal filetype=grok
  setlocal wrap linebreak
  setlocal modifiable
  let l:bufnr = bufnr('%')
  " Return focus to the original code window
  noautocmd execute l:orig_win . 'wincmd w'
  return l:bufnr
endfunction

" ---- Utility: Show a spinner while job runs --------------------------------
function! s:show_waiting(msg) abort
  echohl MoreMsg
  echo a:msg . '...'
  echohl None
endfunction

" ---- Core: Run grok synchronously & return parsed result ------------------
function! s:run_grok_sync(prompt) abort
  let l:cmd = s:base_cmd()
  call extend(l:cmd, ['-p', a:prompt, '--output-format', 'json'])
  call s:show_waiting('Asking Grok')

  let l:raw = system(join(map(copy(l:cmd), 'shellescape(v:val)'), ' '))
  if v:shell_error
    echoerr 'grok-cli failed (exit ' . v:shell_error . '): ' . l:raw
    return {}
  endif

  try
    let l:result = json_decode(l:raw)
  catch
    echoerr 'Failed to parse grok JSON output: ' . l:raw
    return {}
  endtry
  return l:result
endfunction

" ---- Core: Async callback handlers (script-local to survive GC) ----------
" The context dict is kept in s:grok_ctx so it cannot be garbage-collected
" after s:run_grok_async returns.
let s:grok_ctx = {}

function! s:on_stdout(channel, msg) abort
  let l:ctx = s:grok_ctx
  for l:line in split(a:msg, "\n")
    let l:trimmed = substitute(l:line, '^\s*\|\s*$', '', 'g')
    if empty(l:trimmed)
      continue
    endif
    try
      let l:event = json_decode(l:trimmed)
    catch
      continue
    endtry

    if type(l:event) != type({})
      continue
    endif

    let l:type = get(l:event, 'type', '')
    let l:data = get(l:event, 'data', '')

    if l:type ==# 'text'
      let l:ctx.output .= l:data
      call s:update_buffer(l:ctx.bufnr, l:ctx.output, l:ctx.thought)
    elseif l:type ==# 'thought'
      let l:ctx.thought .= l:data
    elseif l:type ==# 'end'
      let l:sid = get(l:event, 'sessionId', '')
      if !empty(l:sid) && l:ctx.use_session
        let s:chat_session_id = l:sid
      endif
    endif
  endfor
endfunction

function! s:on_stderr(channel, msg) abort
  let s:grok_ctx.stderr .= a:msg . "\n"
endfunction

function! s:on_close(channel) abort
  let s:grok_ctx.channel_closed = 1
  if s:grok_ctx.job_exited
    call s:on_done()
  endif
endfunction

function! s:on_exit(job, status) abort
  let s:grok_ctx.exit_code = a:status
  let s:grok_ctx.job_exited = 1
  if s:grok_ctx.channel_closed
    call s:on_done()
  endif
endfunction

function! s:on_done() abort
  let l:ctx = s:grok_ctx
  if empty(l:ctx.output) && empty(l:ctx.thought)
    if l:ctx.exit_code != 0
      let l:ctx.output = 'Error: grok-cli exited with code ' . l:ctx.exit_code
      if !empty(l:ctx.stderr)
        let l:ctx.output .= "\n\n" . l:ctx.stderr
      endif
    endif
  endif
  call s:update_buffer(l:ctx.bufnr, l:ctx.output, l:ctx.thought)
  " If this was a :GrokGenerate request, insert code at the saved cursor
  call s:try_generate_insert()
  echohl MoreMsg | echo 'Grok response complete.' | echohl None
  let s:grok_job = v:null
endfunction

" ---- Core: Run grok asynchronously with streaming into a buffer -----------
function! s:run_grok_async(prompt, bufnr, ...) abort
  let l:use_session = a:0 >= 1 ? a:1 : 0
  let l:cmd = s:base_cmd()
  call extend(l:cmd, ['-p', a:prompt, '--output-format', 'streaming-json'])

  " If continuing a chat session, pass the session id
  if l:use_session && !empty(s:chat_session_id)
    call extend(l:cmd, ['-s', s:chat_session_id])
  endif

  " Store context in script-local so it survives after this function returns
  let s:grok_ctx = {
        \ 'bufnr': a:bufnr, 'output': '', 'use_session': l:use_session,
        \ 'thought': '', 'stderr': '', 'exit_code': -1,
        \ 'channel_closed': 0, 'job_exited': 0
        \ }

  " Start async job with script-local function references
  if has('job') && has('channel')
    let s:grok_job = job_start(l:cmd, {
          \ 'in_io': 'null',
          \ 'out_cb': function('s:on_stdout'),
          \ 'err_cb': function('s:on_stderr'),
          \ 'close_cb': function('s:on_close'),
          \ 'exit_cb': function('s:on_exit'),
          \ 'out_mode': 'nl',
          \ 'err_mode': 'nl',
          \ })
  else
    " Fallback: synchronous
    let l:result = s:run_grok_sync(a:prompt)
    if !empty(l:result)
      let l:text = get(l:result, 'text', '')
      let l:thought = get(l:result, 'thought', '')
      call s:update_buffer(a:bufnr, l:text, l:thought)
      if l:use_session
        let s:chat_session_id = get(l:result, 'sessionId', '')
      endif
    endif
  endif
endfunction

" ---- Utility: Update buffer content with thought + response ---------------
" Uses buffer-level operations to avoid triggering autocmds from other
" plugins (airline, gitgutter, auto-pairs, codeium, etc.) that fire on
" WinEnter/BufEnter and can corrupt window state during async callbacks.
function! s:update_buffer(bufnr, text, thought) abort
  let l:winnr = bufwinnr(a:bufnr)
  if l:winnr == -1
    return
  endif

  " Build the new content
  let l:lines = []
  if !empty(a:thought)
    call add(l:lines, '╭─ Thinking ─────────────────────────────────────')
    call extend(l:lines, split(a:thought, "\n"))
    call add(l:lines, '╰────────────────────────────────────────────────')
    call add(l:lines, '')
  endif
  call extend(l:lines, split(a:text, "\n"))
  if empty(l:lines)
    let l:lines = ['(No response received)']
  endif

  " Make buffer writable, update content, then lock it — all without
  " switching windows so BufEnter/WinEnter autocmds never fire.
  call setbufvar(a:bufnr, '&modifiable', 1)
  " Clear existing lines
  silent call deletebufline(a:bufnr, 1, '$')
  " Write new content
  call setbufline(a:bufnr, 1, l:lines)
  call setbufvar(a:bufnr, '&modifiable', 0)
  call setbufvar(a:bufnr, '&modified', 0)

  " Scroll to bottom using noautocmd to prevent plugin interference
  let l:cur_win = winnr()
  noautocmd execute l:winnr . 'wincmd w'
  noautocmd normal! G
  noautocmd execute l:cur_win . 'wincmd w'
  redraw
endfunction

" ============================================================================
" PUBLIC API
" ============================================================================

" ---- :GrokAsk <prompt> ---------------------------------------------------
function! grok#ask(prompt) abort
  if empty(a:prompt)
    echoerr 'Usage: :GrokAsk <prompt>'
    return
  endif
  let l:bufnr = s:open_grok_buffer('Ask')
  call setbufline(l:bufnr, 1, ['⏳ Asking Grok...'])
  call s:run_grok_async(a:prompt, l:bufnr)
endfunction

" ---- :GrokExplain (visual selection or entire buffer) ---------------------
function! grok#explain(line1, line2) abort
  let l:code = join(getline(a:line1, a:line2), "\n")
  let l:ft = &filetype
  let l:prompt = "Explain the following " . l:ft . " code clearly and concisely. " .
        \ "Include what it does, key concepts, and any notable patterns:\n\n```" . l:ft . "\n" . l:code . "\n```"
  let l:bufnr = s:open_grok_buffer('Explain')
  call setbufline(l:bufnr, 1, ['⏳ Grok is analyzing your code...'])
  call s:run_grok_async(l:prompt, l:bufnr)
endfunction

" ---- :GrokRefactor (visual selection or entire buffer) --------------------
function! grok#refactor(line1, line2) abort
  let l:code = join(getline(a:line1, a:line2), "\n")
  let l:ft = &filetype
  let l:prompt = "Suggest refactoring improvements for this " . l:ft . " code. " .
        \ "Show the improved code with explanations of each change:\n\n```" . l:ft . "\n" . l:code . "\n```"
  let l:bufnr = s:open_grok_buffer('Refactor')
  call setbufline(l:bufnr, 1, ['⏳ Grok is refactoring your code...'])
  call s:run_grok_async(l:prompt, l:bufnr)
endfunction

" ---- :GrokReview (visual selection or entire buffer) ----------------------
function! grok#review(line1, line2) abort
  let l:code = join(getline(a:line1, a:line2), "\n")
  let l:ft = &filetype
  let l:prompt = "Perform a thorough code review of this " . l:ft . " code. " .
        \ "Cover: bugs, security issues, performance, readability, best practices. " .
        \ "Be specific with line references and provide fixed code where relevant:\n\n```" . l:ft . "\n" . l:code . "\n```"
  let l:bufnr = s:open_grok_buffer('Review')
  call setbufline(l:bufnr, 1, ['⏳ Grok is reviewing your code...'])
  call s:run_grok_async(l:prompt, l:bufnr)
endfunction

" ---- :GrokFix (visual selection or entire buffer) -------------------------
function! grok#fix(line1, line2) abort
  let l:code = join(getline(a:line1, a:line2), "\n")
  let l:ft = &filetype
  let l:prompt = "Fix any bugs, errors, or issues in this " . l:ft . " code. " .
        \ "Return the corrected code with explanations of what was wrong:\n\n```" . l:ft . "\n" . l:code . "\n```"
  let l:bufnr = s:open_grok_buffer('Fix')
  call setbufline(l:bufnr, 1, ['⏳ Grok is debugging your code...'])
  call s:run_grok_async(l:prompt, l:bufnr)
endfunction

" ---- :GrokGenerate <prompt> -----------------------------------------------
" Generates code and inserts at cursor. Uses async with a dedicated callback
" that strips markdown fences and inserts below the current line.
function! grok#generate(prompt) abort
  if empty(a:prompt)
    echoerr 'Usage: :GrokGenerate <prompt>'
    return
  endif
  let l:ft = &filetype
  let l:full_prompt = "Generate " . l:ft . " code for the following request. " .
        \ "Return ONLY the code, no explanations, no markdown fences:\n\n" . a:prompt

  " Store cursor position for insertion after async completion
  let s:generate_insert_line = line('.')
  let s:generate_insert_buf = bufnr('%')

  echohl MoreMsg | echon 'Grok: generating code...' | echohl None

  " Use the async path — stream into a hidden buffer, then extract on done
  let l:bufnr = s:open_grok_buffer('Generate')
  call setbufline(l:bufnr, 1, ['⏳ Generating...'])
  call s:run_grok_async(l:full_prompt, l:bufnr)
endfunction

" Called from s:on_done — if this was a generate request, insert the code
function! s:try_generate_insert() abort
  if !exists('s:generate_insert_line')
    return
  endif
  let l:bufname = '[Grok] Generate'
  let l:bufnr = s:find_buf_exact(l:bufname)
  if l:bufnr == -1
    return
  endif

  let l:lines = getbufline(l:bufnr, 1, '$')
  let l:text = join(l:lines, "\n")

  " Strip markdown code fences if model wraps output
  let l:text = substitute(l:text, '^```\w*\n', '', '')
  let l:text = substitute(l:text, '\n```\s*$', '', '')
  let l:text = substitute(l:text, '^\n\+', '', '')
  let l:text = substitute(l:text, '\n\+$', '', '')
  let l:code_lines = split(l:text, "\n")

  if !empty(l:code_lines)
    call appendbufline(s:generate_insert_buf, s:generate_insert_line, l:code_lines)
    echohl MoreMsg | echo 'Generated ' . len(l:code_lines) . ' lines.' | echohl None
  endif

  " Close the generate buffer (it was just a staging area)
  let l:winnr = bufwinnr(l:bufnr)
  if l:winnr != -1
    noautocmd execute l:winnr . 'wincmd w'
    noautocmd close
  endif

  unlet s:generate_insert_line
  unlet s:generate_insert_buf
endfunction

" ---- :GrokChat -----------------------------------------------------------
function! grok#chat(prompt) abort
  let l:bufname = '[Grok] Chat'
  let l:existing = s:find_buf_exact(l:bufname)

  if empty(a:prompt)
    " Open a new chat session
    let s:chat_session_id = ''
    if l:existing != -1
      execute 'bwipeout! ' . l:existing
    endif
    let l:bufnr = s:open_grok_buffer('Chat')
    call setbufline(l:bufnr, 1, [
          \ '╔══════════════════════════════════════════════════╗',
          \ '║             Grok Interactive Chat                ║',
          \ '║                                                  ║',
          \ '║  Type your message with :GrokChat <message>      ║',
          \ '║  The conversation continues across messages.     ║',
          \ '║  Use :GrokChatReset to start a new session.      ║',
          \ '╚══════════════════════════════════════════════════╝',
          \ ])
    setlocal nomodifiable
    return
  endif

  " Append user message to chat buffer
  if l:existing != -1 && bufloaded(l:existing)
    let l:winnr = bufwinnr(l:existing)
    if l:winnr != -1
      noautocmd execute l:winnr . 'wincmd w'
    else
      noautocmd execute 'botright split'
      noautocmd execute 'buffer ' . l:existing
    endif
    setlocal modifiable
    let l:last = line('$')
    call append(l:last, ['', '── You ──────────────────────────────────────────', a:prompt, '', '── Grok ─────────────────────────────────────────', '⏳ Thinking...'])
    setlocal nomodifiable
    normal! G
    let l:bufnr = bufnr('%')
  else
    let l:bufnr = s:open_grok_buffer('Chat')
    call setbufline(l:bufnr, 1, [
          \ '── You ──────────────────────────────────────────',
          \ a:prompt,
          \ '',
          \ '── Grok ─────────────────────────────────────────',
          \ '⏳ Thinking...'])
  endif

  " Run async — the streaming callback captures session ID from 'end' event
  call s:run_grok_async(a:prompt, l:bufnr, 1)
endfunction

" ---- :GrokChatReset -------------------------------------------------------
function! grok#chat_reset() abort
  let s:chat_session_id = ''
  echo 'Grok chat session reset.'
endfunction

" ---- :GrokModels ----------------------------------------------------------
function! grok#models() abort
  " Use list form to avoid shell injection if binary path has spaces
  let l:raw = system([s:get_binary(), 'models'])
  let l:bufnr = s:open_grok_buffer('Models')
  call setbufvar(l:bufnr, '&modifiable', 1)
  call setbufline(l:bufnr, 1, split(l:raw, "\n"))
  call setbufvar(l:bufnr, '&modifiable', 0)
endfunction

" ---- :GrokSetModel <model> ------------------------------------------------
function! grok#set_model(model) abort
  if empty(a:model)
    echo 'Current model: ' . (empty(s:get_model()) ? '(default)' : s:get_model())
    return
  endif
  let g:grok_model = a:model
  echo 'Grok model set to: ' . a:model
endfunction

" ---- :GrokStop ------------------------------------------------------------
function! grok#stop() abort
  if s:grok_job isnot v:null && job_status(s:grok_job) ==# 'run'
    call job_stop(s:grok_job)
    echo 'Grok request cancelled.'
    let s:grok_job = v:null
  else
    echo 'No Grok request in progress.'
  endif
endfunction

" ---- :GrokInline <prompt> — ask about code context around cursor ----------
function! grok#inline(prompt) abort
  let l:ft = &filetype
  let l:file = expand('%:t')
  let l:line = line('.')
  " Grab ±20 lines of context around cursor
  let l:start = max([1, l:line - 20])
  let l:end   = min([line('$'), l:line + 20])
  let l:code  = join(getline(l:start, l:end), "\n")
  let l:full_prompt = "File: " . l:file . " (line " . l:line . ")\nLanguage: " . l:ft .
        \ "\n\nContext code (lines " . l:start . "-" . l:end . "):\n```" . l:ft . "\n" . l:code . "\n```" .
        \ "\n\nUser question about line " . l:line . ": " . a:prompt
  let l:bufnr = s:open_grok_buffer('Inline')
  call setbufline(l:bufnr, 1, ['⏳ Asking Grok about this code...'])
  call s:run_grok_async(l:full_prompt, l:bufnr)
endfunction
