# vim-grok

> AI-powered code assistance in Vim via [grok-cli](https://docs.x.ai/docs/grok-cli) — ask questions,
> explain / refactor / review / fix code, generate snippets, hold
> multi-turn chat sessions, and get **inline code completions** powered by
> the xAI API — all without ever leaving your editor.

## Requirements

- **Vim 8.0+** (async streaming via `job`/`channel`; synchronous fallback for older builds)
- **grok-cli** installed and authenticated (`grok login`)
- **Inline completions** (optional): an [xAI API key](https://console.x.ai/) and `curl`

## Installation

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'xai-org/vim-grok'
```

Then `:PlugInstall`.

### [Vundle](https://github.com/VundleVim/Vundle.vim)

```vim
Plugin 'xai-org/vim-grok'
```

Then `:PluginInstall`.

### [Pathogen](https://github.com/tpope/vim-pathogen)

```bash
cd ~/.vim/bundle
git clone https://github.com/xai-org/vim-grok.git
```

### Vim 8+ Native Packages

```bash
mkdir -p ~/.vim/pack/plugins/start
cd ~/.vim/pack/plugins/start
git clone https://github.com/xai-org/vim-grok.git
```

### Neovim

```bash
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
cd ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/xai-org/vim-grok.git
```

After installing, generate help tags inside Vim:

```vim
:helptags ALL
```

## Quick Start

```vim
" Ask any freeform question
:GrokAsk How do I reverse a linked list in Python?

" Explain the current buffer
:GrokExplain

" Select lines in Visual mode, then review them
:'<,'>GrokReview

" Generate code at cursor
:GrokGenerate a Python function that merges two sorted lists

" Start a multi-turn chat
:GrokChat What testing framework should I use for this project?
```

## Commands

| Command | Description |
|---------|-------------|
| `:GrokAsk <prompt>` | Ask Grok any freeform question |
| `:[range]GrokExplain` | Explain selected code or entire buffer |
| `:[range]GrokRefactor` | Suggest refactoring improvements |
| `:[range]GrokReview` | Thorough code review (bugs, security, perf) |
| `:[range]GrokFix` | Fix bugs and errors in code |
| `:GrokGenerate <prompt>` | Generate code and insert at cursor |
| `:GrokInline <prompt>` | Ask about code around cursor (±20 lines context) |
| `:GrokChat [message]` | Multi-turn chat with session persistence |
| `:GrokChatReset` | Start a new chat session |
| `:GrokModels` | List available models |
| `:GrokSetModel [model]` | Set or display current model |
| `:GrokStop` | Cancel running async request |
| `:GrokCompleteToggle` | Toggle inline completions on/off |

## Key Mappings

All mappings use the prefix `<leader>g` (configurable via `g:grok_map_prefix`).

### Normal Mode

| Key | Action |
|-----|--------|
| `<leader>ga` | Ask Grok (opens prompt) |
| `<leader>ge` | Explain buffer |
| `<leader>gr` | Refactor buffer |
| `<leader>gv` | Review buffer |
| `<leader>gf` | Fix buffer |
| `<leader>gg` | Generate code (opens prompt) |
| `<leader>gc` | Chat (opens prompt) |
| `<leader>gi` | Inline question (opens prompt) |
| `<leader>gm` | List models |
| `<leader>gs` | Stop request |
| `<leader>gt` | Toggle inline completions |

### Visual Mode

| Key | Action |
|-----|--------|
| `<leader>ge` | Explain selection |
| `<leader>gr` | Refactor selection |
| `<leader>gv` | Review selection |
| `<leader>gf` | Fix selection |

## Configuration

Add any of these to your `.vimrc`:

```vim
" Path to grok binary (default: ~/.grok/bin/grok)
let g:grok_binary = '~/.grok/bin/grok'

" Default model (empty = CLI default)
let g:grok_model = 'grok-code-fast-1'

" Extra CLI arguments (string with shell-style quoting)
let g:grok_extra_args = '--rules "Be concise"'

" Or as a List (avoids quoting issues)
let g:grok_extra_args = ['--rules', 'Be concise']

" Enable YOLO mode (auto-approve tool usage)
let g:grok_yolo = 0

" Change key mapping prefix
let g:grok_map_prefix = '<leader>g'
```

### Inline Completion (xAI API)

Inline completions show ghost-text suggestions as you type, similar to
Copilot or Codeium. They call the xAI API directly (not grok-cli).

```vim
" Enable inline completions (default: 0, opt-in)
let g:grok_completion_enabled = 1

" xAI API key (or set the XAI_API_KEY environment variable)
let g:grok_xai_api_key = 'xai-...'

" Model for completions (default: grok-3-mini-fast)
let g:grok_completion_model = 'grok-3-mini-fast'

" Debounce delay in ms before requesting a completion (default: 300)
let g:grok_completion_debounce = 300

" Max tokens per completion response (default: 256)
let g:grok_completion_max_tokens = 256

" Lines of context above/below cursor sent with each request (default: 50)
let g:grok_completion_context_lines = 50

" Disable default Ctrl-g Ctrl-g accept mapping
let g:grok_completion_no_map_tab = 1
```

**Default keybinding:** `<C-g><C-g>` in Insert mode accepts the suggestion.
You can remap it:

```vim
" Use Tab to accept instead
imap <silent><expr> <Tab> grok#completion#Accept()

" Or use a Plug mapping
imap <Tab> <Plug>(grok-complete-accept)
```

## How It Works

- **Async streaming** — Commands like `:GrokAsk`, `:GrokExplain`, etc. use
  `--output-format streaming-json` to stream responses in real-time into a
  split buffer.
- **Sync mode** — `:GrokGenerate` uses `--output-format json` synchronously
  to insert code directly at your cursor.
- **Chat sessions** — `:GrokChat` passes `-s <session-id>` to maintain
  multi-turn conversations.
- **Inline completion** — On each keystroke (debounced), sends the code
  surrounding your cursor to the xAI chat completions API via `curl`,
  then renders the suggestion as grey ghost text using Vim's text
  properties. Press `<C-g><C-g>` to accept.
- **Context-aware** — Code commands automatically include the buffer's
  filetype for language-aware responses.
- **Syntax highlighting** — Output buffers use filetype `grok` with custom
  highlighting for thinking blocks, chat headers, and code fences.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for
guidelines.

## License

[MIT](LICENSE)
