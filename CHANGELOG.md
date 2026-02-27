# Changelog

All notable changes to vim-grok will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.3.1] - 2026-02-25

### Fixed
- **Help file**: Added missing documentation for `g:grok_no_mappings` and `g:grok_plugin_version` options introduced in v0.3.0. The `:help grok` docs now match all available configuration options.

## [0.3.0] - 2026-02-25

### Changed
- **Output buffer no longer steals focus**: `:GrokAsk`, `:GrokExplain`, `:GrokReview`, etc. open the response buffer as a split but return focus to the code window immediately. You can keep editing while the response streams in.
- **`:GrokChat` is now async**: Chat responses stream in real-time instead of blocking the editor. Session ID is captured from the streaming `end` event.
- **`:GrokGenerate` is now async**: Code generation no longer blocks. Generated code is inserted at the saved cursor position when the response completes, and the staging buffer auto-closes.
- **Output buffer sizing**: New buffers open at 1/3 screen height (min 8 lines) instead of a half-height split.

### Added
- **`g:grok_no_mappings`**: Set to `1` to suppress all default key mappings. Commands still work — users can define their own bindings.
- **`g:grok_plugin_version`**: Version tracking variable (`0.3.0`).
- **Neovim ghost text support**: Inline completions now work in Neovim using `nvim_buf_set_extmark` with virtual text. Previously only Vim's `prop_add` was supported — Neovim users got no ghost text silently.

### Fixed
- **Shell injection in `:GrokModels`**: Changed from string `system()` to list form `system([binary, 'models'])` to safely handle binary paths with spaces.
- **`Accept()` fallback**: When no suggestion is active, `<C-g><C-g>` now passes the literal keys through instead of inserting a Tab character.

## [0.2.1] - 2026-02-09

### Changed
- Comprehensive documentation rewrite for inline completion feature
- README: added step-by-step API key setup (environment variable and vimrc),
  Quick Start split into grok-cli and completion sections, Insert Mode
  keybinding table, Architecture table showing dual backends, full example
  .vimrc
- doc/grok.txt: added Installation section, expanded Inline Completion
  with 3-step setup guide, shell-specific export instructions (bash/zsh),
  How to Use workflow, example .vimrc

## [0.2.0] - 2026-02-09

### Added
- Inline code completion via xAI API (ghost-text suggestions as you type)
- `:GrokCompleteToggle` command and `<leader>gt` mapping
- `<C-g><C-g>` Insert-mode mapping to accept suggestions
- `<Plug>(grok-complete-accept)` and `<Plug>(grok-complete-dismiss)` for
  custom keybinding
- Configurable: `g:grok_completion_enabled`, `g:grok_xai_api_key`,
  `g:grok_completion_model`, `g:grok_completion_debounce`,
  `g:grok_completion_max_tokens`, `g:grok_completion_context_lines`
- Per-buffer disable via `b:grok_completion_enabled`

### Fixed
- grok-cli blocking on stdin when launched from Vim (`in_io: 'null'`)
- Plugin conflicts with airline, gitgutter, codeium, auto-pairs, and
  RainbowParentheses caused by BufEnter/WinEnter autocmd cascades during
  async callbacks (switched to `noautocmd` and buffer-level APIs)
- Async callback dictionary funcrefs being garbage-collected (moved to
  script-local functions with `s:grok_ctx`)

## [0.1.0] - 2026-02-09

### Added
- `:GrokAsk` — freeform questions with async streaming response
- `:GrokExplain` — explain selected code or entire buffer
- `:GrokRefactor` — suggest refactoring improvements
- `:GrokReview` — thorough code review (bugs, security, performance)
- `:GrokFix` — fix bugs and errors in code
- `:GrokGenerate` — generate code and insert at cursor (sync)
- `:GrokInline` — ask about code around cursor with ±20 lines of context
- `:GrokChat` / `:GrokChatReset` — multi-turn chat with session persistence
- `:GrokModels` / `:GrokSetModel` — list and switch models
- `:GrokStop` — cancel a running async request
- Normal and Visual mode key mappings under configurable `<leader>g` prefix
- Custom `grok` filetype with syntax highlighting for output buffers
- Full Vim help documentation (`:help grok`)

### Fixed
- NDJSON streaming split across callbacks (`out_mode: 'nl'`)
- Buffer not clearing stale content on update
- No stderr capture from grok-cli
- Broken range detection with `-range` + `<count>`
- `split()` not respecting quoted arguments in `g:grok_extra_args`
- `bufnr('[Grok]')` glob pattern matching brackets as character class
- `exit_cb`/`out_cb` race condition (replaced with `close_cb` + `exit_cb`
  + `on_done` pattern)