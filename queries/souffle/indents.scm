; Soufflé Datalog — indentation
; Required: config/plugins.lua points 'indentexpr' at nvim-treesitter for every
; buffer with a parser, and nvim-treesitter indents everything to column 0 when
; this query is missing.

; Nodes whose contents indent one level when they span several lines.
[
  (component_decl)
  (aggregator)
  (monotonic_rule)
  (subsumptive_rule)
  (fact)
  (relation_decl)
  (functor_decl)
  (directive)
  (atom)
  (record_constructor)
  (type_record)
  (adt)
] @indent.begin

; A line that starts with a closing delimiter dedents.
[
  "}"
  ")"
  "]"
] @indent.branch

; Leave the inside of comments alone.
[
  (line_comment)
  (block_comment)
] @indent.auto
