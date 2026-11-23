; SMOL highlights
;
; Used by Neovim (queries/smol/highlights.scm) and by `tree-sitter highlight`
; from the grammar directory.

; ── Comments ────────────────────────────────────────────────────────────────

(line_comment) @comment
(block_comment) @comment

; JML contracts live in `/*@ ... @*/` or `//@ ...` comments.
((block_comment) @comment.documentation
  (#match? @comment.documentation "^/[*][@]"))

((line_comment) @comment.documentation
  (#match? @comment.documentation "^//[@]"))

; ── Keywords ────────────────────────────────────────────────────────────────

[
  "abstract"
  "class"
  "extends"
  "hidden"
  "end"
  "main"
  "override"
  "rule"
  "domain"
  "context"
  "adapts"
  "classifies"
  "retrieves"
  "links"
] @keyword

["if" "then" "else"] @keyword.conditional

["while" "do" "decreases"] @keyword.repeat

"return" @keyword.return

["skip" "breakpoint"] @keyword.control

"new" @keyword.operator

"this" @variable.builtin

"super" @function.builtin

["null" "unit"] @constant.builtin

(boolean) @boolean

; ── Literals ────────────────────────────────────────────────────────────────

(integer) @number
(float) @number.float

(string) @string
(escape_sequence) @string.escape

; ── Types ───────────────────────────────────────────────────────────────────

(primitive_type) @type.builtin

(type_identifier) @type

(class_declaration
  name: (type_identifier) @type.class)

(type_parameters
  (type_identifier) @type.parameter)

; ── Functions and methods ───────────────────────────────────────────────────

(member_declaration
  name: (identifier) @function.method
  parameters: (parameter_list))

(abstract_method_declaration
  name: (identifier) @function.method)

(method_invocation
  name: (identifier) @function.method.call)

(call_expression
  function: (identifier) @function.call)

(access_expression "access" @function.builtin)
(construct_expression "construct" @function.builtin)
(classify_expression "classify" @function.builtin)
(adapt_expression "adapt" @function.builtin)
(member_expression "member" @function.builtin)
(validate_expression "validate" @function.builtin)
(simulate_expression "simulate" @function.builtin)
(influxdb_mode "INFLUXDB" @function.builtin)

(print_statement "print" @function.builtin)
(destroy_statement "destroy" @function.builtin)

(sparql_mode) @constant.builtin

; ── Variables, fields, parameters ───────────────────────────────────────────

(member_declaration
  name: (identifier) @property
  "=")

(declaration_statement
  name: (identifier) @variable)

(field_parameter
  name: (identifier) @variable.parameter)

(parameter
  name: (identifier) @variable.parameter)

(field_expression
  field: (identifier) @property)

; ── Embedded languages (SPARQL, Turtle, IRIs) ───────────────────────────────

(models_clause
  fragment: (string) @string.special)

(classifies_clause
  (string) @string.special)

(retrieves_clause
  (string) @string.special)

(access_expression
  arguments: (argument_list (string) @string.special))

(construct_expression
  arguments: (argument_list (string) @string.special))

(simulate_expression
  model: (string) @string.special)

(member_expression
  arguments: (argument_list (string) @string.special))

(validate_expression
  arguments: (argument_list (string) @string.special))

; ── Operators and punctuation ───────────────────────────────────────────────

(binary_expression
  [
    "=="
    "!="
    "<"
    "<="
    ">"
    ">="
    "+"
    "-"
    "*"
    "/"
    "%"
    "++"
    "&&"
    "||"
    "&"
    "|"
  ] @operator)

(unary_expression
  ["!" "-"] @operator)

(assignment_statement "=" @operator)
(declaration_statement "=" @operator)
(member_declaration "=" @operator)

["(" ")" "[" "]"] @punctuation.bracket

["," ";"] @punctuation.delimiter

"." @punctuation.delimiter
