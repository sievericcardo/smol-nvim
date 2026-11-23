; SMOL text objects (nvim-treesitter/nvim-treesitter-textobjects compatible).

(class_declaration) @class.outer
(class_declaration
  body: (class_body) @class.inner)

(member_declaration
  parameters: (parameter_list)) @function.outer
(member_declaration
  body: (block) @function.inner)

(if_statement) @conditional.outer
(if_statement
  consequence: (block) @conditional.inner)
(if_statement
  alternative: (block) @conditional.inner)

(while_statement) @loop.outer
(while_statement
  body: (block) @loop.inner)

(block) @block.outer
(block) @block.inner

(argument_list) @call.outer
(argument_list) @call.inner

(parameter) @parameter.outer
(parameter) @parameter.inner

(line_comment) @comment.outer
(block_comment) @comment.outer

(string) @string.outer
