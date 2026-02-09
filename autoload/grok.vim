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

" ---- Utility: Open or reuse a Grok output buffer --------------------------
function! s:open_grok_buffer(name) abort
  let l:bufname = '[Grok] ' . a:name
  let l:existing = bufnr(l:bufname)
  if l:existing != -1 && bufloaded(l:existing)
    " Jump to the window if visible, otherwise split
    let l:winnr = bufwinnr(l:existing)
    if l:winnr != -1
      execute l:winnr . 'wincmd w'
    else
      execute 'botright split'
      execute 'buffer ' . l:existing
    endif
    " Clear the buffer
    setlocal modifiable
    silent %delete _
  else
    execute 'botright new'
    execute 'file ' . fnameescape(l:bufname)
  endif
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal filetype=grok
  setlocal wrap linebreak
  setlocal modifiable
  return bufnr('%')
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

" ---- Core: Run grok asynchronously with streaming into a buffer -----------
function! s:run_grok_async(prompt, bufnr, ...) abort
  let l:use_session = a:0 >= 1 ? a:1 : 0
  let l:cmd = s:base_cmd()
  call extend(l:cmd, ['-p', a:prompt, '--output-format', 'streaming-json'])

  " If continuing a chat session, pass the session id
  if l:use_session && !empty(s:chat_session_id)
    call extend(l:cmd, ['-s', s:chat_session_id])
  endif

  let l:ctx = {'bufnr': a:bufnr, 'output': '', 'use_session': l:use_session, 'thought': '', 'stderr': ''}

  function! l:ctx.on_stdout(channel, msg) dict abort
    " Each line is a JSON event from streaming-json
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

      let l:type = get(l:event, 'type', '')
      let l:data = get(l:event, 'data', '')

      if l:type ==# 'text'
        let self.output .= l:data
        call s:update_buffer(self.bufnr, self.output, self.thought)
      elseif l:type ==# 'thought'
        let self.thought .= l:data
      elseif l:type ==# 'end'
        " Capture session ID for multi-turn chat
        let l:sid = get(l:event, 'sessionId', '')
        if !empty(l:sid) && self.use_session
          let s:chat_session_id = l:sid
        endif
      endif
    endfor
  endfunction

  function! l:ctx.on_stderr(channel, msg) dict abort
    let self.stderr .= a:msg . "\n"
  endfunction

  function! l:ctx.on_exit(channel, code) dict abort
    " If no output was captured, show a meaningful message
    if empty(self.output) && empty(self.thought)
      if a:code != 0
        let self.output = 'Error: grok-cli exited with code ' . a:code
        if !empty(self.stderr)
          let self.output .= "\n\n" . self.stderr
        endif
      endif
    endif
    call s:update_buffer(self.bufnr, self.output, self.thought)
    " Mark buffer as not modified
    call setbufvar(self.bufnr, '&modified', 0)
    echohl MoreMsg | echo 'Grok response complete.' | echohl None
    let s:grok_job = v:null
  endfunction

  " Start async job
  if has('job') && has('channel')
    let s:grok_job = job_start(l:cmd, {
          \ 'out_cb': l:ctx.on_stdout,
          \ 'err_cb': l:ctx.on_stderr,
          \ 'exit_cb': l:ctx.on_exit,
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
function! s:update_buffer(bufnr, text, thought) abort
  let l:winnr = bufwinnr(a:bufnr)
  if l:winnr == -1
    return
  endif
  let l:cur_win = winnr()
  execute l:winnr . 'wincmd w'
  setlocal modifiable
  let l:lines = []
  if !empty(a:thought)
    call add(l:lines, '╭─ Thinking ─────────────────────────────────────')
    call extend(l:lines, split(a:thought, "\n"))
    call add(l:lines, '╰────────────────────────────────────────────────')
    call add(l:lines, '')
  endif
  call extend(l:lines, split(a:text, "\n"))
  " Clear old buffer content (spinner, stale lines) before writing
  silent 1,$delete _
  if empty(l:lines)
    call setbufline(a:bufnr, 1, ['(No response received)'])
  else
    call setbufline(a:bufnr, 1, l:lines)
  endif
  " Scroll to bottom
  normal! G
  setlocal nomodifiable
  execute l:cur_win . 'wincmd w'
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
function! grok#generate(prompt) abort
  if empty(a:prompt)
    echoerr 'Usage: :GrokGenerate <prompt>'
    return
  endif
  let l:ft = &filetype
  let l:full_prompt = "Generate " . l:ft . " code for the following request. " .
        \ "Return ONLY the code, no explanations, no markdown fences:\n\n" . a:prompt
  call s:show_waiting('Grok is generating code')
  let l:result = s:run_grok_sync(l:full_prompt)
  if empty(l:result)
    return
  endif
  let l:text = get(l:result, 'text', '')
  " Strip markdown code fences if present
  let l:text = substitute(l:text, '^```\w*\n', '', '')
  let l:text = substitute(l:text, '\n```\s*$', '', '')
  let l:lines = split(l:text, "\n")
  call append(line('.'), l:lines)
  echo 'Generated ' . len(l:lines) . ' lines.'
endfunction

" ---- :GrokChat -----------------------------------------------------------
function! grok#chat(prompt) abort
  let l:bufname = '[Grok] Chat'
  let l:existing = bufnr(l:bufname)

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
      execute l:winnr . 'wincmd w'
    else
      execute 'botright split'
      execute 'buffer ' . l:existing
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

  " Build command
  let l:cmd = s:base_cmd()
  call extend(l:cmd, ['-p', a:prompt, '--output-format', 'json'])
  if !empty(s:chat_session_id)
    call extend(l:cmd, ['-s', s:chat_session_id])
  endif

  " Run synchronously for chat (so we capture session ID reliably)
  let l:raw = system(join(map(copy(l:cmd), 'shellescape(v:val)'), ' '))
  let l:result = {}
  try
    let l:result = json_decode(l:raw)
  catch
    let l:result = {'text': 'Error: ' . l:raw}
  endtry

  let l:text = get(l:result, 'text', 'No response')
  let l:sid  = get(l:result, 'sessionId', '')
  if !empty(l:sid)
    let s:chat_session_id = l:sid
  endif

  " Replace the "Thinking..." line with the response
  let l:winnr2 = bufwinnr(l:bufnr)
  if l:winnr2 != -1
    execute l:winnr2 . 'wincmd w'
  endif
  setlocal modifiable
  " Find and remove the spinner line
  let l:total = line('$')
  for l:i in range(l:total, 1, -1)
    if getline(l:i) =~# '⏳'
      execute l:i . 'delete _'
      break
    endif
  endfor
  " Append the response
  let l:last = line('$')
  call append(l:last, split(l:text, "\n"))
  setlocal nomodifiable
  normal! G
endfunction

" ---- :GrokChatReset -------------------------------------------------------
function! grok#chat_reset() abort
  let s:chat_session_id = ''
  echo 'Grok chat session reset.'
endfunction

" ---- :GrokModels ----------------------------------------------------------
function! grok#models() abort
  let l:cmd = s:get_binary() . ' models'
  let l:raw = system(l:cmd)
  let l:bufnr = s:open_grok_buffer('Models')
  setlocal modifiable
  call setbufline(l:bufnr, 1, split(l:raw, "\n"))
  setlocal nomodifiable
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
