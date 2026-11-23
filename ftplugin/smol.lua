-- Buffer-local settings for SMOL files.

vim.bo.commentstring = '// %s'
vim.bo.comments = 's1:/*,mb:*,ex:*/,://'

if vim.g.smol_indent ~= 0 then
  vim.bo.expandtab = true
  vim.bo.shiftwidth = 4
  vim.bo.softtabstop = 4
  vim.bo.tabstop = 4
end

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '| setlocal commentstring< comments<'
  .. (vim.g.smol_indent ~= 0 and ' expandtab< shiftwidth< softtabstop< tabstop<' or '')

-- `lockpick` reports byte offsets; keeping `iskeyword` at Vim's default (which
-- includes `_`) already gives the right word motions for SMOL identifiers.
