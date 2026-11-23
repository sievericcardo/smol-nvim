local M = {}

---@class SmolLspConfig
---@field enabled boolean
---@field cmd string[]|fun(root: string|nil): string[]|nil
---@field source_dir string|nil        Directory of a local lockpick checkout (for :SmolBuildLsp)
---@field install_dir string|nil      Where :SmolInstallLsp installs binaries (default: stdpath('data')/smol)
---@field git { url: string, branch: string|nil, tag: string|nil, rev: string|nil }
---@field root_markers string[]
---@field capabilities table|nil
---@field settings table
---@field init_options table
---@field on_attach fun(client: vim.lsp.Client, bufnr: integer)|nil
---@field keymaps table<string, string|false>
---@field auto_start boolean
---@field notify_missing boolean

---@class SmolTreesitterConfig
---@field enabled boolean
---@field auto_start boolean
---@field cc string|nil
---@field folds boolean

---@class SmolCheckConfig
---@field cmd string[]|fun(root: string|nil): string[]|nil
---@field manifest string|nil
---@field extra_args string[]
---@field open_quickfix boolean
---@field timeout integer

---@class SmolConfig
---@field lsp SmolLspConfig
---@field treesitter SmolTreesitterConfig
---@field syntax { enabled: boolean }
---@field check SmolCheckConfig
---@field keymaps { check: string|false, check_buffer: string|false }

M.defaults = {
  lsp = {
    enabled = true,
    cmd = nil,
    source_dir = nil,
    install_dir = nil,
    git = {
      url = 'https://github.com/sievericcardo/lockpick',
      branch = nil,
      tag = nil,
      rev = nil,
    },
    root_markers = { 'smol.toml', '.git' },
    capabilities = nil,
    settings = {},
    init_options = {},
    on_attach = nil,
    keymaps = {},
    auto_start = true,
    notify_missing = true,
  },
  treesitter = {
    enabled = true,
    auto_start = true,
    cc = nil,
    folds = false,
  },
  syntax = {
    enabled = true,
  },
  check = {
    cmd = nil,
    manifest = nil,
    extra_args = {},
    open_quickfix = false,
    timeout = 120000,
  },
  keymaps = {
    check = false,
    check_buffer = false,
  },
}

local current = vim.deepcopy(M.defaults)

---Merge a partial config into the module defaults.
---@param opts table|nil
---@return SmolConfig
function M.setup(opts)
  opts = opts or {}
  current = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts)

  -- `cmd` is commonly given as a string for convenience.
  for _, section in ipairs({ 'lsp', 'check' }) do
    if type(current[section].cmd) == 'string' then
      current[section].cmd = { current[section].cmd }
    end
  end
  if current.check.manifest then
    current.check.manifest = vim.fn.expand(current.check.manifest)
  end
  if current.lsp.source_dir then
    current.lsp.source_dir = vim.fn.expand(current.lsp.source_dir)
  end
  if current.lsp.install_dir then
    current.lsp.install_dir = vim.fn.expand(current.lsp.install_dir)
  end
  if current.check.timeout and current.check.timeout <= 0 then
    current.check.timeout = M.defaults.check.timeout
  end
  -- Read by syntax/smol.vim. Set before any SMOL buffer is loaded (setup() is
  -- normally called from init.lua / a lazy.nvim `opts` function).
  vim.g.smol_syntax = current.syntax.enabled == false and 0 or 1
  return current
end

---@return SmolConfig
function M.get()
  return current
end

---Project root for a buffer: the closest directory containing one of the
---configured markers. Falls back to the directory of the buffer.
---@param bufnr integer|nil
---@return string|nil
function M.root_dir(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = current.lsp
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return nil
  end

  local markers = cfg.root_markers
  if type(markers) == 'function' then
    local ok, result = pcall(markers, bufnr)
    if ok then
      return result
    end
    return nil
  end

  -- `vim.fs.root` understands marker lists and walk-up semantics.
  local root = vim.fs.root(bufnr, markers)
  if root then
    return root
  end
  local dir = vim.fs.dirname(name)
  if dir and dir ~= '.' then
    return dir
  end
  return nil
end

---Resolve the lockpick checkout directory, if configured.
---@return string|nil
function M.lockpick_dir()
  local cfg = current.lsp
  return cfg.source_dir or vim.env.LOCKPICK_DIR
end

return M
