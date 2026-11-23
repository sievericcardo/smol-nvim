local config = require('smol.config')

local M = {}

---Resolve a keymap entry: `false`/`nil` disables it, a string maps it.
---@param bufnr integer
---@param lhs string|false|nil
---@param rhs string
---@param desc string
local function map(bufnr, lhs, rhs, desc)
  if not lhs then
    return
  end
  vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = 'SMOL: ' .. desc, silent = true })
end

---Create the FileType autocmd that wires up LSP, tree-sitter and keymaps.
function M.setup()
  if M._installed then
    return
  end
  M._installed = true

  local group = vim.api.nvim_create_augroup('SmolNvim', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'smol',
    desc = 'SMOL: attach lockpick-lsp and tree-sitter',
    callback = function(args)
      local cfg = config.get()

      if cfg.syntax and cfg.syntax.enabled == false then
        vim.bo[args.buf].syntax = ''
      end

      if cfg.treesitter.enabled and cfg.treesitter.auto_start then
        pcall(require('smol.treesitter').start, args.buf)
      end
      if cfg.lsp.enabled and cfg.lsp.auto_start then
        pcall(require('smol.lsp').start, args.buf)
      end

      map(args.buf, cfg.keymaps.check, '<cmd>SmolCheck<cr>', 'check project')
      map(args.buf, cfg.keymaps.check_buffer, '<cmd>SmolCheckBuffer<cr>', 'check buffer')
    end,
  })
end

---Attach to all currently open SMOL buffers (used when setup() runs late).
function M.attach_open_buffers()
  local cfg = config.get()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == 'smol' then
      if cfg.treesitter.enabled and cfg.treesitter.auto_start then
        pcall(require('smol.treesitter').start, bufnr)
      end
      if cfg.lsp.enabled and cfg.lsp.auto_start then
        pcall(require('smol.lsp').start, bufnr)
      end
      map(bufnr, cfg.keymaps.check, '<cmd>SmolCheck<cr>', 'check project')
      map(bufnr, cfg.keymaps.check_buffer, '<cmd>SmolCheckBuffer<cr>', 'check buffer')
    end
  end
end

return M
