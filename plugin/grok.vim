" ============================================================================
" File:        plugin/grok.vim
" Description: Vim plugin for interfacing with grok-cli
" Author:      vim-grok contributors
" License:     MIT
" ============================================================================

" ---- Guard ----------------------------------------------------------------
if exists('g:loaded_grok_plugin')
  finish
endif
let g:loaded_grok_plugin = 1

" Require Vim 8.0+ for job/channel support
if v:version < 800
  echoerr 'vim-grok requires Vim 8.0 or later'
  finish
endif

" ---- Configuration Variables (user-overridable) ---------------------------
" g:grok_binary       — Path to grok binary (default: ~/.grok/bin/grok)
" g:grok_model        — Model to use (default: '' = CLI default)
" g:grok_extra_args   — Extra CLI arguments (default: '')
" g:grok_yolo         — Enable yolo/auto-approve mode (default: 0)
" g:grok_map_prefix   — Key mapping prefix (default: '<leader>g')

let s:prefix = get(g:, 'grok_map_prefix', '<leader>g')

" ---- Commands -------------------------------------------------------------

" Freeform ask
command! -nargs=+ GrokAsk        call grok#ask(<q-args>)

" Code analysis (work on visual selection or entire buffer)
command! -range=% -nargs=0 GrokExplain  call grok#explain(<line1>, <line2>)
command! -range=% -nargs=0 GrokRefactor call grok#refactor(<line1>, <line2>)
command! -range=% -nargs=0 GrokReview   call grok#review(<line1>, <line2>)
command! -range=% -nargs=0 GrokFix      call grok#fix(<line1>, <line2>)

" Code generation (inserts at cursor)
command! -nargs=+ GrokGenerate   call grok#generate(<q-args>)

" Inline question about code at cursor
command! -nargs=+ GrokInline     call grok#inline(<q-args>)

" Multi-turn chat
command! -nargs=* GrokChat       call grok#chat(<q-args>)
command! -nargs=0 GrokChatReset  call grok#chat_reset()

" Model management
command! -nargs=0 GrokModels     call grok#models()
command! -nargs=? GrokSetModel   call grok#set_model(<q-args>)

" Stop current request
command! -nargs=0 GrokStop       call grok#stop()

" ---- Key Mappings (Normal mode) -------------------------------------------
" All prefixed with <leader>g by default

" <leader>ga — Ask Grok (prompts for input)
execute 'nnoremap ' . s:prefix . 'a :GrokAsk '

" <leader>ge — Explain current buffer
execute 'nnoremap <silent> ' . s:prefix . 'e :GrokExplain<CR>'

" <leader>gr — Refactor current buffer
execute 'nnoremap <silent> ' . s:prefix . 'r :GrokRefactor<CR>'

" <leader>gv — Review current buffer
execute 'nnoremap <silent> ' . s:prefix . 'v :GrokReview<CR>'

" <leader>gf — Fix current buffer
execute 'nnoremap <silent> ' . s:prefix . 'f :GrokFix<CR>'

" <leader>gg — Generate code (prompts for input)
execute 'nnoremap ' . s:prefix . 'g :GrokGenerate '

" <leader>gc — Chat (prompts for input)
execute 'nnoremap ' . s:prefix . 'c :GrokChat '

" <leader>gi — Inline question about cursor context
execute 'nnoremap ' . s:prefix . 'i :GrokInline '

" <leader>gm — List models
execute 'nnoremap <silent> ' . s:prefix . 'm :GrokModels<CR>'

" <leader>gs — Stop current request
execute 'nnoremap <silent> ' . s:prefix . 's :GrokStop<CR>'

" ---- Key Mappings (Visual mode) -------------------------------------------
" Apply to visual selection

" <leader>ge — Explain selection
execute 'xnoremap <silent> ' . s:prefix . 'e :GrokExplain<CR>'

" <leader>gr — Refactor selection
execute 'xnoremap <silent> ' . s:prefix . 'r :GrokRefactor<CR>'

" <leader>gv — Review selection
execute 'xnoremap <silent> ' . s:prefix . 'v :GrokReview<CR>'

" <leader>gf — Fix selection
execute 'xnoremap <silent> ' . s:prefix . 'f :GrokFix<CR>'

" ---- Inline Completion (xAI API) -----------------------------------------
" g:grok_completion_enabled  — Set to 1 to enable (default: 0, opt-in)
" g:grok_xai_api_key         — xAI API key (or set $XAI_API_KEY)
" g:grok_completion_model    — Model for completions (default: grok-3-mini-fast)
" g:grok_completion_debounce — Debounce delay in ms (default: 300)
" g:grok_completion_max_tokens — Max tokens per completion (default: 256)
" g:grok_completion_context_lines — Lines of context above/below cursor (default: 50)

command! -nargs=0 GrokCompleteToggle call grok#completion#Toggle()

" Default style for ghost text
hi def GrokSuggestion guifg=#808080 ctermfg=244

" Autocmds for triggering completions (only active when enabled)
augroup grok_completion
  autocmd!
  autocmd TextChangedI * call grok#completion#Trigger()
  autocmd InsertLeave  * call grok#completion#Clear()
  autocmd BufLeave     * if mode() =~# '^[iR]' | call grok#completion#Clear() | endif
augroup END

" Key mappings for completion
" Tab to accept (insert mode, expression map)
if !get(g:, 'grok_completion_no_map_tab', 0) && !get(g:, 'grok_disable_completion_bindings', 0)
  imap <script><silent><nowait><expr> <C-g><C-g> grok#completion#Accept()
endif

" Plug mappings for user customization
imap <Plug>(grok-complete-accept)  <Cmd>call grok#completion#Accept()<CR>
imap <Plug>(grok-complete-dismiss) <Cmd>call grok#completion#Clear()<CR>

" <leader>gt — Toggle completion on/off
execute 'nnoremap <silent> ' . s:prefix . 't :GrokCompleteToggle<CR>'
