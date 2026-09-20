; Soufflé Datalog — highlights
; Grammar: https://github.com/langston-barrett/tree-sitter-souffle
; Later patterns win, so this file goes generic -> specific.

; ── Punctuation ─────────────────────────────────────────────────────────
[
  "(" ")"
  "[" "]"
  "{" "}"
] @punctuation.bracket

[
  ","
  "."
  ":"
] @punctuation.delimiter

; ── Operators ───────────────────────────────────────────────────────────
[
  "+" "-" "*" "/" "%" "^"
  "&" "|" "&&" "||" "**" "^^"
  "<<" ">>" ">>>"
  "~" "!"
  "=" "!=" "<" ">" "<=" ">="
  "<:"
  ":-"
] @operator

[
  "land" "lor" "lxor"
  "band" "bor" "bxor"
  "bshl" "bshr" "bshru"
  "bnot" "lnot"
] @operator

(negation) @operator

; `,` is conjunction and `;` is disjunction inside a rule body.
(conjunction "," @operator)
(disjunction ";" @operator)

(comparison ["=" "!=" "<" ">" "<=" ">="] @operator)

; ── Keywords ────────────────────────────────────────────────────────────
[
  ".decl"
  ".type"
  ".comp"
  ".init"
  ".functor"
  ".pragma"
  ".plan"
  ".override"
  ".number_type"
  ".symbol_type"
] @keyword

[
  ".input"
  ".output"
  ".printsize"
  ".limitsize"
] @keyword.import

(preprocessor "#line" @keyword.directive)
(preprocessor file: (string) @string.special.path)

; Relation qualifiers: .decl A(x:number) btree inline
[
  "brie" "btree" "btree_delete" "eqrel"
  "inline" "no_inline"
  "magic" "no_magic"
  "override" "overridable"
  "input" "output" "printsize"
  "stateful"
  "choice-domain"
] @keyword.modifier

["as" "match" "contains"] @keyword.operator

; ── Literals ────────────────────────────────────────────────────────────
(string) @string
(number) @number
(float) @number.float
(ipv4) @constant
(bool) @boolean
(nil) @constant.builtin
(anonymous) @variable.builtin

; ── Variables ───────────────────────────────────────────────────────────
(variable) @variable

; ── Relations (predicates) ──────────────────────────────────────────────
(relation_decl head: (ident) @function)
(atom relation: (qualified_name (ident) @function))
(directive relation: (qualified_name (ident) @function))

; Directive arguments: .output A(IO=file, filename="a.csv")
(directive key: (ident) @property)
(directive value: (ident) @constant)

; ── Attributes: x:number ────────────────────────────────────────────────
(attribute var: (ident) @property)
(attribute type: (qualified_name (ident) @type))

; ── Types ───────────────────────────────────────────────────────────────
(subtype left: (ident) @type)
(subtype right: (qualified_name (ident) @type))
(type_synonym left: (ident) @type)
(type_synonym right: (qualified_name (ident) @type))
(type_union left: (ident) @type)
(type_union branch: (qualified_name (ident) @type))
(type_record left: (ident) @type)
(legacy_bare_type_decl name: (ident) @type)
(legacy_type_decl subtype: (qualified_name (ident) @type))
(as type: (qualified_name (ident) @type))

; ── Components ──────────────────────────────────────────────────────────
(component_type name: (ident) @module)
(component_type param: (ident) @type)
(component_init name: (ident) @variable)

; ── Constructors: $Branch(...) and ADT declarations ─────────────────────
; `constructor:` can't be matched as a field here (tree-sitter's static analysis
; rejects it), so capture every direct ident and let `left:` below win.
(adt (ident) @constructor)
(adt left: (ident) @type)
(adt_constructor "$" @punctuation.special)
(adt_constructor constructor: (qualified_name (ident) @constructor))

; ── Functors ────────────────────────────────────────────────────────────
(functor_decl name: (ident) @function)
(functor_decl return: (qualified_name (ident) @type))
(user_defined_functor "@" @punctuation.special)
(user_defined_functor name: (ident) @function.call)

; ── Builtins (most specific, so they come last) ─────────────────────────
(intrinsic_functor) @function.builtin
(aggregator ["max" "mean" "min" "sum" "count"] @function.builtin)
(range "range" @function.builtin)
(primitive_type) @type.builtin

; ── Comments ────────────────────────────────────────────────────────────
[
  (line_comment)
  (block_comment)
] @comment @spell
