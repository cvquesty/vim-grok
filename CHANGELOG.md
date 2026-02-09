# Changelog

All notable changes to vim-grok will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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