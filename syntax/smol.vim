" Vim syntax file for SMOL (Sensor Modelling and Ontology Language).
" Falls back from tree-sitter when a parser is not installed.
"
" Order matters: later definitions win when two items start at the same
" position, so comments and strings come last to beat operator characters.

if exists('b:current_syntax')
  finish
endif

if !get(g:, 'smol_syntax', 1)
  finish
endif

syn case match
syn sync fromstart

" ── Contract annotations inside JML comments ────────────────────────────────

syn keyword smolTodo TODO FIXME XXX NOTE contained
syn keyword smolJmlKeyword requires ensures decreases pure domain-reads domain-writes invariant old result contained

" ── Literals ────────────────────────────────────────────────────────────────

syn match smolNumber /\<\d\+\>/
syn match smolFloat /\<\d\+\.\d*\%([eE][+-]\?\d\+\)\?\>/
syn match smolFloat /\<\d\+[eE][+-]\?\d\+\>/

" ── Calls, methods and fields ───────────────────────────────────────────────

syn match smolFunctionCall /\<\h\w*\ze\s*(/
syn match smolField /\.\zs\h\w*\ze\%(\s*(\)\@!/
syn match smolMethod /\.\zs\h\w*\ze\s*(/

" ── Keywords ────────────────────────────────────────────────────────────────

syn keyword smolConditional if then else
syn keyword smolRepeat while do
syn keyword smolStatement return skip breakpoint
syn keyword smolKeyword abstract class hidden extends end main override rule domain context adapts classifies retrieves links new decreases
syn keyword smolFunction print destroy access construct classify adapt member validate simulate tick port super

" ── Types ───────────────────────────────────────────────────────────────────

syn keyword smolType Int Double String Boolean Bool Unit List ExplList Nullable FMO
syn match smolType /\<\u\w*\>/

" ── Constants (after smolType so True/False are not re-typed) ────────────────

syn keyword smolConstant True False null unit this in out
syn keyword smolSpecial SPARQL INFLUXDB

" ── Operators ───────────────────────────────────────────────────────────────

syn match smolOperator /++\|==\|!=\|<=\|>=\|&&\|||\|[-+*\/%<>=!&|]/

" ── Comments ────────────────────────────────────────────────────────────────

syn region smolBlockComment
      \ start="/\*\%(@\)\@!"
      \ end="\*/"
      \ contains=smolTodo,@Spell

syn region smolJmlComment
      \ start="/\*@"
      \ end="@\*/"
      \ contains=smolTodo,smolJmlKeyword,@Spell

syn region smolLineComment start="//" end="$" contains=smolTodo,@Spell

syn region smolJmlLineComment
      \ start="//@"
      \ end="$"
      \ contains=smolTodo,smolJmlKeyword,@Spell

" ── Strings ─────────────────────────────────────────────────────────────────
" Strings may span several lines (SPARQL, InfluxQL, Turtle fragments).

syn region smolString start=+"+ skip=+\\"+ end=+"+ contains=smolEscape,@Spell
syn match smolEscape /\\[\\"]/ contained

" ── Highlight links ─────────────────────────────────────────────────────────

hi def link smolTodo Todo
hi def link smolComment Comment
hi def link smolLineComment Comment
hi def link smolJmlLineComment Comment
hi def link smolBlockComment Comment
hi def link smolJmlComment Comment
hi def link smolJmlKeyword Identifier
hi def link smolString String
hi def link smolEscape SpecialChar
hi def link smolNumber Number
hi def link smolFloat Float
hi def link smolConstant Constant
hi def link smolSpecial Constant
hi def link smolKeyword Keyword
hi def link smolConditional Conditional
hi def link smolRepeat Repeat
hi def link smolStatement Statement
hi def link smolFunction Function
hi def link smolFunctionCall Function
hi def link smolMethod Function
hi def link smolField Identifier
hi def link smolType Type
hi def link smolOperator Operator

let b:current_syntax = 'smol'
