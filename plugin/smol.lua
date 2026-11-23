-- Filetype detection so `:set ft=smol` works even without setup().
vim.filetype.add({
  extension = {
    smol = 'smol',
  },
})

-- Map the filetype to the tree-sitter language name. They are identical by
-- default, but registering explicitly documents the relationship and makes
-- `vim.treesitter.language.get_lang('smol')` work on older Neovim releases.
pcall(vim.treesitter.language.register, 'smol', 'smol')

require('smol.commands').setup()
require('smol.autocmds').setup()
