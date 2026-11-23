-- Minimal init for the headless test suite.
local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':h:h')

vim.opt.runtimepath:prepend(root)
vim.opt.swapfile = false
vim.opt.shadafile = 'NONE'
vim.opt.more = false

vim.cmd('filetype plugin indent on')
vim.cmd('syntax enable')

require('smol').setup({
  lsp = {
    enabled = true,
    auto_start = false,
    cmd = vim.env.SMOL_TEST_LSP and { vim.env.SMOL_TEST_LSP } or nil,
    notify_missing = false,
  },
  treesitter = {
    enabled = true,
    auto_start = false,
  },
  check = {
    cmd = vim.env.SMOL_TEST_LOCKPICK and { vim.env.SMOL_TEST_LOCKPICK } or nil,
  },
})
