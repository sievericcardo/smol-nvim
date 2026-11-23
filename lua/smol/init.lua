local config = require('smol.config')

local M = {}

---Set up smol.nvim.
---
---Calling this function is optional: the plugin works with defaults and can be
---lazy-loaded on `ft = "smol"`. Calling `setup()` is required to customise the
---configuration or to re-apply it after the plugin was lazy-loaded.
---
---@param opts table|nil
---@return table
function M.setup(opts)
  config.setup(opts)
  require('smol.commands').setup()
  require('smol.autocmds').setup()
  require('smol.autocmds').attach_open_buffers()
  return M
end

---Run `lockpick check` on the current project.
---@param opts table|nil
function M.check(opts)
  require('smol.check').run(opts)
end

---Attach lockpick-lsp to a buffer (defaults to the current buffer).
---@param bufnr integer|nil
function M.start_lsp(bufnr)
  return require('smol.lsp').start(bufnr)
end

---Compile the bundled tree-sitter parser.
---@param opts table|nil
function M.install_parser(opts)
  return require('smol.treesitter').install(opts)
end

---Install lockpick-lsp and lockpick from Git.
---@param opts table|nil
function M.install_lockpick(opts)
  return require('smol.lsp').install(opts)
end

---@return table
function M.get_config()
  return config.get()
end

return M
