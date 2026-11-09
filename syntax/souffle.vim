" Soufflé (Datalog) syntax.
if exists("b:current_syntax")
  finish
endif

syn match   souffleDirective /^\s*\.\(decl\|type\|comp\|init\|input\|output\|printsize\|limitsize\|pragma\|functor\|plan\|override\)\>/
syn match   souffleInclude   /^\s*#\(include\|define\|ifdef\|ifndef\|if\|else\|endif\|undef\)\>.*/
syn keyword souffleKeyword   choice-domain inline no_inline magic no_magic brie btree btree_delete eqrel
syn keyword souffleKeyword   cat ord strlen substr to_number to_string to_float to_unsigned
syn match   souffleKeyword   /\<\(match\|contains\)\>/
syn keyword souffleKeyword   min max sum count mean range as nil
syn keyword souffleLogic     band bor bxor bnot bshl bshr bshru land lor lxor lnot
syn keyword souffleType      number unsigned float symbol
syn keyword souffleBool      true false
syn match   souffleNumber    /\<\(0x\x\+\|0b[01]\+\|\d\+\(\.\d\+\)\?\)\>/
syn region  souffleString    start=/"/ skip=/\\"/ end=/"/
syn match   souffleVar       /\<_\>/
syn match   souffleOp        /:-\|!=\|<=\|>=\|=\|<\|>\|!/
syn region  souffleComment   start=+/\*+ end=+\*/+
syn match   souffleComment   +//.*$+

hi def link souffleDirective Keyword
hi def link souffleInclude   PreProc
hi def link souffleKeyword   Keyword
hi def link souffleLogic     Operator
hi def link souffleType      Type
hi def link souffleBool      Boolean
hi def link souffleNumber    Number
hi def link souffleString    String
hi def link souffleVar       Special
hi def link souffleOp        Operator
hi def link souffleComment   Comment

let b:current_syntax = "souffle"
