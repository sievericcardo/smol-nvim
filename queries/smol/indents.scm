; SMOL indentation.

(class_declaration) @indent.begin
(class_body) @indent.begin
(main_declaration) @indent.begin

(member_declaration
  parameters: (parameter_list)) @indent.begin

(if_statement) @indent.begin
(while_statement) @indent.begin

(field_parameter_list) @indent.begin
(parameter_list) @indent.begin
(argument_list) @indent.begin

(generic_type) @indent.begin
(fmo_type) @indent.begin

["end" "else"] @indent.branch
