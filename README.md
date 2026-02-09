# vim-grok

> AI-powered code assistance in Vim via [grok-cli](https://docs.x.ai/docs/grok-cli) — ask questions,
> explain / refactor / review / fix code, generate snippets, and hold
> multi-turn chat sessions without ever leaving your editor.

## Requirements

- **Vim 8.0+** (async streaming via `job`/`channel`; synchronous fallback for older builds)
- **grok-cli** installed and authenticated (`grok login`)

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

" Extra CLI arguments
let g:grok_extra_args = '--rules "Be concise"'

" Enable YOLO mode (auto-approve tool usage)
let g:grok_yolo = 0

" Change key mapping prefix
let g:grok_map_prefix = '<leader>g'
```

## How It Works

- **Async streaming** — Commands like `:GrokAsk`, `:GrokExplain`, etc. use
  `--output-format streaming-json` to stream responses in real-time into a
  split buffer.
- **Sync mode** — `:GrokGenerate` uses `--output-format json` synchronously
  to insert code directly at your cursor.
- **Chat sessions** — `:GrokChat` passes `-s <session-id>` to maintain
  multi-turn conversations.
- **Context-aware** — Code commands automatically include the buffer's
  filetype for language-aware responses.
- **Syntax highlighting** — Output buffers use filetype `grok` with custom
  highlighting for thinking blocks, chat headers, and code fences.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for
guidelines.

## License

[MIT](LICENSE)
