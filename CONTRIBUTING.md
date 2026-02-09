# Contributing to vim-grok

Thanks for your interest in improving vim-grok! Here's how to get started.

## Reporting Issues

- Search [existing issues](../../issues) before opening a new one.
- Include your Vim version (`:version`), OS, and grok-cli version (`grok --version`).
- Paste the exact error message and the command or mapping that triggered it.

## Submitting Changes

1. Fork the repo and create a feature branch from `main`:
   ```bash
   git checkout -b my-feature
   ```
2. Make your changes. Follow the conventions below.
3. Test in Vim 8.0+ **and** confirm the synchronous fallback still works
   (`:let g:grok_test_sync = 1` or remove `has('job')` guard temporarily).
4. Open a pull request against `main`.

## Code Conventions

- **Vim script style** — Use `l:` for local variables, `s:` for script-local,
  `a:` for arguments. Guard autoload files with `g:autoloaded_*` and plugin
  files with `g:loaded_*`.
- **Indentation** — 2 spaces, no tabs.
- **Comments** — Use `"` comments. Section headers use the `---- Title ---`
  banner style already in the codebase.
- **Functions** — Prefer `abort` on all function definitions.

## Plugin Structure

```
autoload/grok.vim   Core logic (public API + private helpers)
plugin/grok.vim     Commands and key mappings (loaded once)
syntax/grok.vim     Syntax highlighting for [Grok] output buffers
doc/grok.txt        Vim help documentation
```

## Documentation

- If you add a new command or configuration variable, update **both**
  `doc/grok.txt` and `README.md`.
- Keep the help file in standard Vim `:help` format (see `:help help-writing`).

## License

By contributing you agree that your contributions will be licensed under the
[MIT License](LICENSE).