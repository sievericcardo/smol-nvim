; SMOL locals — powers `@definition.*`/`@reference.*` and LSP-like features
; such as `` (go to local definition) and text-object selection.

(class_declaration
  name: (type_identifier) @definition.class)

(member_declaration
  name: (identifier) @definition.method
  parameters: (parameter_list))

(abstract_method_declaration
  name: (identifier) @definition.method)

(member_declaration
  name: (identifier) @definition.field
  "=")

(parameter
  name: (identifier) @definition.parameter)

(field_parameter
  name: (identifier) @definition.field)

(declaration_statement
  name: (identifier) @definition.var)

(identifier) @reference
(type_identifier) @reference
