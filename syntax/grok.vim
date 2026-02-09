" Syntax highlighting for Grok output buffers
if exists('b:current_syntax')
  finish
endif

" Thinking block delimiters
syntax match grokThinkOpen  /^╭─ Thinking ─.*$/
syntax match grokThinkClose /^╰─.*$/
syntax match grokThinkLine  /^│.*$/

" Chat decorations
syntax match grokUserHeader  /^── You ──.*$/
syntax match grokGrokHeader  /^── Grok ──.*$/
syntax match grokBoxLine     /^[╔╚╗╝║═].*$/

" Spinner
syntax match grokSpinner /⏳.*/

" Code fences in response
syntax region grokCodeBlock start=/^```/ end=/^```/ contains=ALL keepend

" Highlights
highlight default link grokThinkOpen   Comment
highlight default link grokThinkClose  Comment
highlight default link grokThinkLine   Comment
highlight default link grokUserHeader  Title
highlight default link grokGrokHeader  Statement
highlight default link grokBoxLine     Special
highlight default link grokSpinner     WarningMsg
highlight default link grokCodeBlock   String

let b:current_syntax = 'grok'
