# vim-grok

![Version](https://img.shields.io/badge/version-0.3.1-blue)
![Vim](https://img.shields.io/badge/vim-8.0%2B-green)
![Neovim](https://img.shields.io/badge/neovim-0.5%2B-green)
![License](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-stable-brightgreen)

AI-powered code assistance in Vim — ask questions, explain/refactor/review/fix code, generate snippets, hold multi-turn chat sessions, and get **inline code completions** as you type. All without ever leaving your editor.

---

## What Is This?

vim-grok is a Vim plugin that connects your editor to [Grok](https://x.ai), xAI's large language model. Think of it as having a knowledgeable coding partner inside Vim who can:

- **Answer questions** about code, languages, or concepts
- **Explain** what a block of code does
- **Suggest improvements** to make your code cleaner
- **Find and fix bugs** in your code
- **Generate new code** from a description
- **Complete code as you type** with ghost-text suggestions (like GitHub Copilot)

The plugin has **two independent backends** — you can use either or both:

1. **grok-cli** — The Grok command-line tool. Handles questions, code analysis, generation, and chat. Authenticates with `grok login` (no API key needed).
2. **xAI API** — Direct API calls for inline code completions (ghost text as you type). Requires an API key.

Everything runs **asynchronously** — the editor never freezes while waiting for a response.

---

## Requirements

Before installing, make sure you have:

- **Vim 8.0 or later** (for async job/channel support), or **Neovim 0.5+**
- **grok-cli** installed and authenticated — [installation docs](https://docs.x.ai/docs/grok-cli)

For inline completions (optional):
- An **xAI API key** — sign up at [console.x.ai](https://console.x.ai/)
- **curl** on your system PATH (usually pre-installed on macOS and Linux)

### Checking Your Setup

```bash
# Check your Vim version (need 8.0+)
vim --version | head -1

# Check grok-cli is installed
~/.grok/bin/grok --version

# Check you're logged in
~/.grok/bin/grok whoami

# Check curl is available (for inline completions)
curl --version
```

---

## Installation

Choose the plugin manager you use. If you're not sure, **vim-plug** is the most popular choice.

### vim-plug

[vim-plug](https://github.com/junegunn/vim-plug) is the most widely used Vim plugin manager.

1. Add this line to your `~/.vimrc` between `call plug#begin()` and `call plug#end()`:

```vim
Plug 'xai-org/vim-grok'
```

2. Save the file, restart Vim, and run:

```vim
:PlugInstall
```

### Vundle

[Vundle](https://github.com/VundleVim/Vundle.vim) is an older but still popular plugin manager.

1. Add this line to your `~/.vimrc` between `call vundle#begin()` and `call vundle#end()`:

```vim
Plugin 'xai-org/vim-grok'
```

2. Save, restart Vim, and run:

```vim
:PluginInstall
```

### Pathogen

[Pathogen](https://github.com/tpope/vim-pathogen) loads plugins from the `~/.vim/bundle/` directory.

```bash
cd ~/.vim/bundle
git clone https://github.com/xai-org/vim-grok.git
```

Restart Vim — Pathogen loads it automatically.

### Vim 8+ Native Packages

Vim 8 has a built-in package system. No plugin manager needed.

```bash
mkdir -p ~/.vim/pack/plugins/start
cd ~/.vim/pack/plugins/start
git clone https://github.com/xai-org/vim-grok.git
```

Restart Vim — it loads automatically from the `pack/*/start/` directory.

### Neovim

Neovim uses a similar native package system, just in a different directory:

```bash
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
cd ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/xai-org/vim-grok.git
```

### After Installing

Generate the help tags so you can use `:help grok` inside Vim:

```vim
:helptags ALL
```

---

## Quick Start

### Using grok-cli Commands (No API Key Needed)

Once grok-cli is installed and you've run `grok login`, these commands work immediately:

```vim
" Ask any freeform question
:GrokAsk How do I reverse a linked list in Python?

" Explain the code in your current file
:GrokExplain

" Select some lines in Visual mode (V), then review them
:'<,'>GrokReview

" Generate code and insert it at your cursor
:GrokGenerate a Python function that merges two sorted lists

" Start a multi-turn conversation
:GrokChat What testing framework should I use for this project?
```

Responses stream into a split window at the bottom of your screen. **Your cursor stays in the code window** — you can keep editing while the response appears.

### Enabling Inline Completions (Requires API Key)

Inline completions show grey "ghost text" suggestions as you type, similar to GitHub Copilot. This feature calls the xAI API directly.

**Step 1: Get an API key**

Sign up or log in at [console.x.ai](https://console.x.ai/) and create an API key. Keys start with `xai-`.

**Step 2: Export the key in your shell**

Add this line to your shell profile so Vim can read it from the environment:

```bash
# For bash — add to ~/.bash_profile or ~/.bashrc
export XAI_API_KEY='xai-your-key-here'

# For zsh — add to ~/.zshrc
export XAI_API_KEY='xai-your-key-here'
```

Reload your shell: `source ~/.bash_profile` (or `source ~/.zshrc`)

**Step 3: Enable in your `.vimrc`**

```vim
let g:grok_completion_enabled = 1
```

**Step 4: Try it out**

Restart Vim, open any code file, enter Insert mode (`i`), and start typing. After a brief pause (300ms), a grey suggestion will appear after your cursor. Press **`Ctrl-g Ctrl-g`** to accept it, or just keep typing to dismiss it.

> **Tip:** You can also set the API key directly in your `.vimrc`:
> ```vim
> let g:grok_xai_api_key = 'xai-your-key-here'
> ```
> However, using the `$XAI_API_KEY` environment variable is more secure since the key stays out of your dotfiles.

---

## Commands Reference

Every command is available from Vim's command line (type `:` then the command).

### Code Analysis Commands

These commands work on the entire buffer, or on a visual selection if you select lines first.

| Command | What It Does |
|---------|-------------|
| `:[range]GrokExplain` | Explains what the code does, key concepts, and patterns |
| `:[range]GrokRefactor` | Suggests improvements with the improved code shown |
| `:[range]GrokReview` | Thorough review: bugs, security, performance, readability |
| `:[range]GrokFix` | Finds and fixes bugs, returns corrected code |

**How to use with a selection:**
1. Enter Visual mode (`V` for line selection)
2. Select the lines you want to analyze
3. Type `:GrokReview` (Vim will show `:'<,'>GrokReview` — that's normal)
4. Press Enter — the response streams into the output window

### Question & Generation Commands

| Command | What It Does |
|---------|-------------|
| `:GrokAsk <your question>` | Ask any freeform question — coding, concepts, anything |
| `:GrokGenerate <description>` | Generate code from a description, inserted at your cursor |
| `:GrokInline <question>` | Ask about the code around your cursor (includes ±20 lines of context) |

### Chat Commands

| Command | What It Does |
|---------|-------------|
| `:GrokChat <message>` | Send a message in a multi-turn conversation |
| `:GrokChat` (no message) | Open a new chat window |
| `:GrokChatReset` | Clear the conversation history and start fresh |

Chat remembers previous messages in the session, so you can have back-and-forth conversations like "Explain this function" → "Now refactor it" → "Add error handling too."

### Model & Control Commands

| Command | What It Does |
|---------|-------------|
| `:GrokModels` | Show all available AI models |
| `:GrokSetModel <name>` | Switch to a different model for this session |
| `:GrokSetModel` (no args) | Show which model is currently active |
| `:GrokStop` | Cancel a request that's currently running |
| `:GrokCompleteToggle` | Turn inline completions on or off |

---

## Key Mappings

All mappings use the prefix **`<leader>g`** by default. If your leader key is `\` (the Vim default), then `<leader>ga` means pressing `\` then `g` then `a`.

> **What's a leader key?** It's a prefix key that Vim uses for custom shortcuts. The default is `\` (backslash). You can change it with `let mapleader = ","` in your `.vimrc`.

### Normal Mode

| Keys | Action | Equivalent Command |
|------|--------|-------------------|
| `<leader>ga` | Ask a question (opens command line) | `:GrokAsk ` |
| `<leader>ge` | Explain the entire buffer | `:GrokExplain` |
| `<leader>gr` | Refactor the entire buffer | `:GrokRefactor` |
| `<leader>gv` | Review the entire buffer | `:GrokReview` |
| `<leader>gf` | Fix bugs in the entire buffer | `:GrokFix` |
| `<leader>gg` | Generate code (opens command line) | `:GrokGenerate ` |
| `<leader>gc` | Chat with Grok (opens command line) | `:GrokChat ` |
| `<leader>gi` | Ask about code at cursor (opens command line) | `:GrokInline ` |
| `<leader>gm` | List available models | `:GrokModels` |
| `<leader>gs` | Stop the current request | `:GrokStop` |
| `<leader>gt` | Toggle inline completions on/off | `:GrokCompleteToggle` |

### Visual Mode

Select code first (using `V` or `v`), then press the shortcut:

| Keys | Action |
|------|--------|
| `<leader>ge` | Explain the selected code |
| `<leader>gr` | Refactor the selected code |
| `<leader>gv` | Review the selected code |
| `<leader>gf` | Fix bugs in the selected code |

### Insert Mode

| Keys | Action |
|------|--------|
| `Ctrl-g Ctrl-g` | Accept the current ghost-text suggestion |

> To dismiss a suggestion without accepting it, just keep typing — it disappears automatically.

---

## Configuration Reference

Add any of these settings to your `~/.vimrc` file. All settings are optional — the defaults work out of the box.

### grok-cli Settings

These control how the plugin talks to the Grok CLI tool.

```vim
" Path to the grok binary
" Default: ~/.grok/bin/grok
" Change this if you installed grok-cli somewhere else
let g:grok_binary = '/usr/local/bin/grok'

" AI model to use for all CLI requests
" Default: '' (empty = whatever the CLI defaults to)
" Use :GrokModels to see what's available
let g:grok_model = 'grok-3-mini-fast'

" Extra arguments passed to every grok-cli invocation
" Default: '' (none)
" Useful for setting custom rules or behavior
let g:grok_extra_args = '--rules "Be concise. Use bullet points."'

" You can also pass extra args as a List (avoids shell quoting issues)
let g:grok_extra_args = ['--rules', 'Be concise. Use bullet points.']

" YOLO mode: auto-approve all tool usage without prompting
" Default: 0 (off)
" Only enable this if you trust the model's tool decisions
let g:grok_yolo = 0
```

### Key Mapping Settings

```vim
" Change the key mapping prefix
" Default: '<leader>g'
" Example: use <leader>k instead of <leader>g
let g:grok_map_prefix = '<leader>k'

" Disable ALL default key mappings
" Default: 0 (mappings enabled)
" Set to 1 if you want to define your own bindings for every command
let g:grok_no_mappings = 1
```

### Inline Completion Settings

These control the ghost-text code suggestions that appear as you type.

```vim
" Enable inline completions
" Default: 0 (off — you must opt in)
" Requires an xAI API key (see below)
let g:grok_completion_enabled = 1

" xAI API key for inline completions
" Default: '' (falls back to $XAI_API_KEY environment variable)
" The environment variable method is recommended for security
let g:grok_xai_api_key = 'xai-your-key-here'

" AI model used for completions
" Default: 'grok-3-mini-fast'
" Smaller/faster models work best for real-time completions
let g:grok_completion_model = 'grok-3-mini-fast'

" How long to wait (in milliseconds) after you stop typing before
" requesting a completion. Higher = fewer API calls, lower = faster suggestions.
" Default: 300
let g:grok_completion_debounce = 300

" Maximum tokens (roughly words) in each completion response
" Default: 256
" Lower values = faster responses, higher = longer completions
let g:grok_completion_max_tokens = 256

" Lines of code above and below the cursor sent as context
" Default: 50
" More context = better suggestions but larger API requests
let g:grok_completion_context_lines = 50

" xAI API endpoint URL
" Default: 'https://api.x.ai/v1/chat/completions'
" You shouldn't need to change this unless xAI changes their API
let g:grok_xai_api_url = 'https://api.x.ai/v1/chat/completions'
```

### Completion Keybinding Customization

```vim
" Disable the default Ctrl-g Ctrl-g binding for accepting completions
" Default: 0 (binding enabled)
let g:grok_completion_no_map_tab = 1

" Then define your own binding. Example: use Tab to accept
imap <silent><expr> <Tab> grok#completion#Accept()

" Or use the Plug mappings for maximum flexibility
imap <Tab> <Plug>(grok-complete-accept)
imap <C-x> <Plug>(grok-complete-dismiss)
```

### Disabling Completions for Certain File Types

Some file types (like plain text or Markdown) don't benefit from code completions. You can disable them per file type:

```vim
autocmd FileType markdown let b:grok_completion_enabled = 0
autocmd FileType text     let b:grok_completion_enabled = 0
autocmd FileType help     let b:grok_completion_enabled = 0
autocmd FileType gitcommit let b:grok_completion_enabled = 0
```

---

## Example `.vimrc` Setup

Here's a complete example with all the commonly used settings:

```vim
" ============================================================
" vim-grok configuration
" ============================================================

" ---- grok-cli (no API key needed, uses `grok login`) ----
let g:grok_model = 'grok-3-mini-fast'   " Fast model for quick tasks
let g:grok_map_prefix = '<leader>g'      " All shortcuts start with \g
let g:grok_extra_args = '--rules "Be concise"'

" ---- Inline completions (requires $XAI_API_KEY) ----
let g:grok_completion_enabled = 1        " Turn on ghost-text suggestions
let g:grok_completion_debounce = 400     " Wait 400ms before suggesting
let g:grok_completion_max_tokens = 128   " Keep suggestions short

" ---- Disable completions in non-code files ----
autocmd FileType markdown,text,help let b:grok_completion_enabled = 0
```

---

## How It Works

### grok-cli Commands

When you run a command like `:GrokExplain`, the plugin:

1. Takes the code from your buffer (or visual selection)
2. Builds a prompt with the code and the file's language
3. Launches `grok-cli` as an async background job with `--output-format streaming-json`
4. Streams the response line-by-line into a split buffer as it arrives
5. Returns your cursor to the code window so you can keep editing

The response window appears at the bottom of your screen and updates in real-time. You don't need to wait for it to finish before continuing your work.

### Inline Completions

When you type in Insert mode:

1. After a brief pause (300ms by default), the plugin collects the code surrounding your cursor
2. Sends it to the xAI API via `curl` in the background
3. When the response arrives, renders it as grey "ghost text" after your cursor
4. If you press `Ctrl-g Ctrl-g`, the ghost text is inserted into your file
5. If you keep typing, the old suggestion is dismissed and a new one is requested

The completion engine tracks request sequence numbers to discard stale responses (if you type faster than the API responds).

### Output Buffer

Responses appear in a special `[Grok]` buffer that:

- Opens as a horizontal split (1/3 of screen height)
- Has custom syntax highlighting for thinking blocks, code fences, and chat headers
- Is read-only (you can't accidentally edit it)
- Is reused across requests (no buffer accumulation)
- Can be closed with `:q` or `:close` like any other window

---

## Architecture

vim-grok has two completely independent backends:

| Feature | Backend | Authentication | How It Communicates |
|---------|---------|---------------|-------------------|
| Ask, Explain, Refactor, Review, Fix, Generate, Inline, Chat | **grok-cli** | `grok login` (session-based) | Streaming NDJSON via Vim's `job_start()` |
| Ghost-text code completions | **xAI API** | API key (`$XAI_API_KEY`) | HTTPS POST via async `curl` |

You can use one without the other. For example:
- **CLI only**: Set up grok-cli, skip the API key — all commands work except ghost-text completions
- **API only**: Set the API key, skip grok-cli — only ghost-text completions work
- **Both**: Full functionality

---

## Troubleshooting

### "grok-cli failed" or "command not found"

Make sure grok-cli is installed and the path is correct:

```bash
# Check if grok is where the plugin expects it
ls -la ~/.grok/bin/grok

# Or set a custom path in your .vimrc
let g:grok_binary = '/path/to/your/grok'
```

### No inline completions appearing

1. Check that completions are enabled: `:echo g:grok_completion_enabled` (should say `1`)
2. Check that the API key is set: `:echo $XAI_API_KEY` (should show your key)
3. Check that you're in Insert mode and in a code file (not a special buffer)
4. Try toggling with `:GrokCompleteToggle`

### Response window doesn't appear

If the output split doesn't show up, check that you're running Vim 8.0+ with job support:

```vim
:echo has('job')
" Should print 1
```

### Ghost text looks wrong in Neovim

Neovim uses a different rendering method (extmarks). Make sure you're on Neovim 0.5+ which supports inline virtual text:

```vim
:echo has('nvim')
" Should print 1
```

---

## Tips & Tricks

- **Use visual selection** for precise code analysis — select just the function or block you care about instead of the entire file
- **Chain commands**: `:GrokReview` first to find problems, then `:GrokFix` to fix them
- **Use `:GrokSetModel`** to switch between fast models (for quick iteration) and powerful models (for complex tasks)
- **Custom rules**: Pass `--rules "Always respond in bullet points"` via `g:grok_extra_args` to shape all responses
- **Close the output window** with `:q` when you're done reading — it won't affect your code

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
