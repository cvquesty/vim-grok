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

### grok-cli commands (no API key needed)

These work out of the box once grok-cli is installed and authenticated:

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

### Inline completions (requires xAI API key)

To enable ghost-text suggestions as you type:

**1. Get an API key** from [console.x.ai](https://console.x.ai/)

**2. Export the key** in your shell profile (`~/.bash_profile`, `~/.bashrc`,
or `~/.zshrc`):

```bash
export XAI_API_KEY='xai-your-key-here'
```

Then reload your shell: `source ~/.bash_profile`

**3. Enable in your `.vimrc`:**

```vim
let g:grok_completion_enabled = 1
```

That's it. Restart Vim, open a code file, enter Insert mode, and start
typing. After a brief pause (300ms), a grey ghost-text suggestion will
appear. Press **`Ctrl-g Ctrl-g`** to accept it.

> **Tip:** You can also set the key directly in your `.vimrc` instead of
> using an environment variable:
> ```vim
> let g:grok_xai_api_key = 'xai-your-key-here'
> ```
> However, using `$XAI_API_KEY` keeps the secret out of your dotfiles.

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

### Insert Mode (Inline Completion)

| Key | Action |
|-----|--------|
| `<C-g><C-g>` | Accept ghost-text suggestion |

## Configuration

### grok-cli Settings

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

### Inline Completion Settings

Inline completions show ghost-text suggestions as you type, similar to
GitHub Copilot or Codeium. They call the xAI API directly (not grok-cli)
and require an API key.

#### API Key Setup

Option A — Environment variable (recommended):

```bash
# Add to ~/.bash_profile, ~/.bashrc, or ~/.zshrc
export XAI_API_KEY='xai-your-key-here'
```

Option B — Vim variable:

```vim
" Add to ~/.vimrc (less secure — key is in plain text)
let g:grok_xai_api_key = 'xai-your-key-here'
```

The plugin checks `g:grok_xai_api_key` first, then falls back to `$XAI_API_KEY`.

#### Completion Options

```vim
" Enable inline completions (default: 0, opt-in)
let g:grok_completion_enabled = 1

" Model for completions (default: grok-3-mini-fast)
let g:grok_completion_model = 'grok-3-mini-fast'

" Debounce delay in ms before requesting a completion (default: 300)
let g:grok_completion_debounce = 300

" Max tokens per completion response (default: 256)
let g:grok_completion_max_tokens = 256

" Lines of context above/below cursor sent with each request (default: 50)
let g:grok_completion_context_lines = 50

" xAI API endpoint (default: https://api.x.ai/v1/chat/completions)
let g:grok_xai_api_url = 'https://api.x.ai/v1/chat/completions'
```

#### Keybinding Customization

The default accept binding is `<C-g><C-g>` in Insert mode. To change it:

```vim
" Disable the default binding
let g:grok_completion_no_map_tab = 1

" Use Tab to accept instead
imap <silent><expr> <Tab> grok#completion#Accept()

" Or use the Plug mapping
imap <Tab> <Plug>(grok-complete-accept)
```

#### Disabling for Specific Filetypes

```vim
autocmd FileType markdown let b:grok_completion_enabled = 0
autocmd FileType text     let b:grok_completion_enabled = 0
autocmd FileType help     let b:grok_completion_enabled = 0
```

### Example `.vimrc` (full setup)

```vim
" ---- grok-cli commands (works with grok login, no API key) ----
let g:grok_model = 'grok-code-fast-1'
let g:grok_yolo = 0
let g:grok_map_prefix = '<leader>g'
let g:grok_extra_args = '--rules "Be concise"'

" ---- Inline completions (requires xAI API key) ----
let g:grok_completion_enabled = 1
" API key loaded from $XAI_API_KEY environment variable
```

## How It Works

- **Async streaming** — Commands like `:GrokAsk`, `:GrokExplain`, etc. use
  `--output-format streaming-json` to stream responses in real-time into a
  split buffer via grok-cli.
- **Sync mode** — `:GrokGenerate` uses `--output-format json` synchronously
  to insert code directly at your cursor.
- **Chat sessions** — `:GrokChat` passes `-s <session-id>` to maintain
  multi-turn conversations.
- **Inline completion** — On each keystroke (debounced), sends the code
  surrounding your cursor to the xAI chat completions API
  (`api.x.ai/v1/chat/completions`) via async `curl`. The response is
  rendered as grey ghost text using Vim's text properties (`prop_add`).
  Press `<C-g><C-g>` to accept and insert the suggestion.
- **Context-aware** — Code commands automatically include the buffer's
  filetype for language-aware responses.
- **Syntax highlighting** — Output buffers use filetype `grok` with custom
  highlighting for thinking blocks, chat headers, and code fences.

## Architecture

vim-grok has two independent backends:

| Feature | Backend | Auth | Protocol |
|---------|---------|------|----------|
| Ask, Explain, Refactor, Review, Fix, Generate, Chat | **grok-cli** | `grok login` | Streaming NDJSON via `job_start` |
| Inline code completions | **xAI API** | API key | HTTPS via `curl` |

Both run asynchronously and do not block the editor.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for
guidelines.

## License

[MIT](LICENSE)
