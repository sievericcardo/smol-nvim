local config = require('smol.config')
local util = require('smol.util')

local M = {}

M.name = 'lockpick'

local warned = {}

---@param root string|nil
---@return string[]
local function command_candidates(root)
  local cfg = config.get().lsp
  local candidates = {}

  if type(cfg.cmd) == 'table' and #cfg.cmd > 0 then
    return cfg.cmd
  end

  if vim.env.LOCKPICK_LSP and vim.env.LOCKPICK_LSP ~= '' then
    table.insert(candidates, vim.env.LOCKPICK_LSP)
  end

  local on_path = vim.fn.exepath('lockpick-lsp')
  if on_path ~= '' then
    table.insert(candidates, on_path)
  end

  local dir = config.lockpick_dir()
  local roots = { root, dir }
  for _, base in ipairs(roots) do
    if base and base ~= '' then
      table.insert(candidates, base .. '/target/release/lockpick-lsp')
      table.insert(candidates, base .. '/target/debug/lockpick-lsp')
    end
  end

  return candidates
end

---Resolve the language server command for a workspace.
---@param root string|nil
---@return string[]|nil
function M.resolve_cmd(root)
  local cfg = config.get().lsp

  if type(cfg.cmd) == 'function' then
    local ok, result = pcall(cfg.cmd, root)
    if not ok or not result then
      return nil
    end
    if type(result) == 'string' then
      result = { result }
    end
    if #result > 0 and util.is_executable(result[1]) then
      return result
    end
    return nil
  end

  if type(cfg.cmd) == 'table' and #cfg.cmd > 0 then
    if util.is_executable(cfg.cmd[1]) then
      return cfg.cmd
    end
    return nil
  end

  local exe = util.first_executable(command_candidates(root))
  if exe then
    return { exe }
  end
  return nil
end

---@param root string|nil
---@return boolean
local function notify_missing(root)
  local cfg = config.get().lsp
  if not cfg.notify_missing then
    return false
  end
  local key = root or '<no-root>'
  if warned[key] then
    return false
  end
  warned[key] = true
  util.notify(
    'lockpick-lsp not found. Install lockpick, put `lockpick-lsp` on your PATH, '
      .. 'set `lsp.cmd`, or use :SmolBuildLsp. Run :checkhealth smol for details.',
    vim.log.levels.WARN
  )
  return true
end

---Attach the lockpick language server to a buffer.
---@param bufnr integer|nil
---@return integer|nil client_id
function M.start(bufnr)
  bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
  local cfg = config.get().lsp
  if not cfg.enabled then
    return nil
  end
  if vim.bo[bufnr].filetype ~= 'smol' then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if not name:match('%.smol$') then
      return nil
    end
  end

  local root = config.root_dir(bufnr)
  local cmd = M.resolve_cmd(root)
  if not cmd then
    notify_missing(root)
    return nil
  end

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  if type(cfg.capabilities) == 'function' then
    capabilities = cfg.capabilities(capabilities) or capabilities
  elseif type(cfg.capabilities) == 'table' then
    capabilities = vim.tbl_deep_extend('force', capabilities, cfg.capabilities)
  end

  local user_on_attach = cfg.on_attach
  local function on_attach(client, buf)
    if user_on_attach then
      local ok, err = pcall(user_on_attach, client, buf)
      if not ok then
        util.notify('lsp.on_attach failed: ' .. tostring(err), vim.log.levels.ERROR)
      end
    end
  end

  local ok, client_or_err = pcall(vim.lsp.start, {
    name = M.name,
    cmd = cmd,
    cmd_cwd = root or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)),
    root_dir = root,
    capabilities = capabilities,
    settings = cfg.settings,
    init_options = cfg.init_options,
    on_attach = on_attach,
  }, {
    bufnr = bufnr,
    reuse_client = function(client, start_config)
      return client.name == start_config.name and client.root_dir == start_config.root_dir
    end,
  })

  if not ok then
    util.notify('failed to start lockpick-lsp: ' .. tostring(client_or_err), vim.log.levels.ERROR)
    return nil
  end
  return client_or_err
end

---Stop all lockpick clients.
---@param force boolean|nil
function M.stop(force)
  for _, client in ipairs(vim.lsp.get_clients({ name = M.name })) do
    client:stop(force == true)
  end
end

---Restart lockpick clients and re-attach all open SMOL buffers.
---@param bufnr integer|nil
function M.restart(bufnr)
  bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
  local targets = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'smol' then
      table.insert(targets, buf)
    end
  end
  if not vim.tbl_contains(targets, bufnr) and vim.api.nvim_buf_is_valid(bufnr) then
    table.insert(targets, bufnr)
  end

  M.stop(true)
  vim.defer_fn(function()
    for _, buf in ipairs(targets) do
      if vim.api.nvim_buf_is_valid(buf) then
        M.start(buf)
      end
    end
  end, 100)
end

---@return vim.lsp.Client[]
function M.clients()
  return vim.lsp.get_clients({ name = M.name })
end

---Print a short status report, used by :SmolInfo.
---@return string[]
function M.info()
  local lines = {}
  local buf = vim.api.nvim_get_current_buf()
  local root = config.root_dir(buf)
  local cmd = M.resolve_cmd(root)
  table.insert(lines, 'root: ' .. tostring(root))
  table.insert(
    lines,
    'lockpick-lsp: ' .. (cmd and table.concat(cmd, ' ') or 'not found')
  )
  local clients = M.clients()
  if #clients == 0 then
    table.insert(lines, 'clients: none attached')
  else
    for _, client in ipairs(clients) do
      table.insert(
        lines,
        string.format(
          'client %d: root=%s buffers=%d',
          client.id,
          tostring(client.root_dir),
          vim.tbl_count(client.attached_buffers or {})
        )
      )
    end
  end
  return lines
end

---Build `lockpick-lsp` from a local lockpick checkout.
---@param opts { source_dir?: string, release?: boolean, on_done?: fun(ok: boolean, output: string) }|nil
function M.build(opts)
  opts = opts or {}
  local cfg = config.get().lsp
  local source = vim.fn.expand(opts.source_dir or cfg.source_dir or vim.env.LOCKPICK_DIR or '')
  if source == '' or vim.fn.isdirectory(source) == 0 then
    util.notify(
      'no lockpick checkout configured; set `lsp.source_dir`, $LOCKPICK_DIR, or pass :SmolBuildLsp <dir>',
      vim.log.levels.ERROR
    )
    return
  end
  if vim.fn.executable('cargo') ~= 1 then
    util.notify('`cargo` not found on PATH', vim.log.levels.ERROR)
    return
  end

  local args = { 'cargo', 'build', '--bin', 'lockpick-lsp' }
  if opts.release ~= false then
    table.insert(args, '--release')
  end

  util.notify('building lockpick-lsp in ' .. source .. '…')
  vim.system(args, { cwd = source, text = true }, function(result)
    vim.schedule(function()
      local output = (result.stdout or '') .. (result.stderr or '')
      local ok = result.code == 0
      if ok then
        local binary = source .. (opts.release == false and '/target/debug/' or '/target/release/') .. 'lockpick-lsp'
        util.notify('built ' .. binary)
        M.restart(0)
      else
        util.notify('cargo build failed', vim.log.levels.ERROR)
      end
      if opts.on_done then
        opts.on_done(ok, output)
      elseif not ok then
        vim.notify(output, vim.log.levels.ERROR)
      end
    end)
  end)
end

return M
