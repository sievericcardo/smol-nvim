local config = require('smol.config')
local util = require('smol.util')

local M = {}

local last_job ---@type vim.SystemObj|nil

---@param root string|nil
---@return string[]
local function command_candidates(root)
  local cfg = config.get().check
  if type(cfg.cmd) == 'function' then
    local ok, result = pcall(cfg.cmd, root)
    if ok and result then
      return type(result) == 'string' and { result } or result
    end
    return {}
  end
  if type(cfg.cmd) == 'table' and #cfg.cmd > 0 then
    return cfg.cmd
  end

  local candidates = {}
  if vim.env.LOCKPICK and vim.env.LOCKPICK ~= '' then
    table.insert(candidates, vim.env.LOCKPICK)
  end
  local on_path = vim.fn.exepath('lockpick')
  if on_path ~= '' then
    table.insert(candidates, on_path)
  end
  local dir = config.lockpick_dir()
  for _, base in ipairs({ root, dir }) do
    if base and base ~= '' then
      table.insert(candidates, base .. '/target/release/lockpick')
      table.insert(candidates, base .. '/target/debug/lockpick')
    end
  end
  return candidates
end

---@param root string|nil
---@return string|nil
function M.resolve_cmd(root)
  local cfg = config.get().check
  if type(cfg.cmd) == 'table' and #cfg.cmd > 0 then
    if util.is_executable(cfg.cmd[1]) then
      return cfg.cmd[1]
    end
  end
  return util.first_executable(command_candidates(root))
end

---@param path string
---@param base string|nil
---@return string
local function absolute(path, base)
  if path:match('^[/\\]') or path:match('^%a:[/\\]') then
    return vim.fs.normalize(path)
  end
  return vim.fs.normalize((base or vim.fn.getcwd()) .. '/' .. path)
end

---Turn lockpick's JSON diagnostics into quickfix items.
---@param diagnostics table[]
---@param base string
---@param filter_file string|nil
---@return table[] items, integer errors, integer warnings
function M.to_quickfix(diagnostics, base, filter_file)
  local items = {}
  local errors, warnings = 0, 0
  local cache = {}

  for _, diag in ipairs(diagnostics) do
    local file = diag.file
    if file then
      file = absolute(file, base)
      if not filter_file or vim.fs.normalize(file) == vim.fs.normalize(filter_file) then
        local lines = cache[file]
        if not lines then
          lines = util.file_lines(file)
          cache[file] = lines
        end
        local text = util.join_lines(lines)

        local span = diag.span or {}
        local line, col = util.offset_to_position(text, span.start or 0)
        local end_line, end_col = util.offset_to_position(text, span['end'] or span.start or 0)
        local qf_type = util.severity(diag.severity)

        if diag.severity == 'error' then
          errors = errors + 1
        elseif diag.severity == 'warning' then
          warnings = warnings + 1
        end

        table.insert(items, {
          filename = file,
          lnum = line + 1,
          col = col + 1,
          end_lnum = end_line + 1,
          end_col = end_col + 1,
          text = string.format(
            '[%s] %s',
            tostring(diag.code or 'SMOL'),
            (tostring(diag.message or ''):gsub('%s+', ' '))
          ),
          type = qf_type,
          valid = 1,
          user_data = {
            code = diag.code,
            severity = diag.severity,
            code_number = diag.code_number,
            labels = diag.labels,
          },
        })
      end
    end
  end

  return items, errors, warnings
end

---@param bufnr integer
---@return string|nil manifest
local function find_manifest(root, bufnr)
  local cfg = config.get().check
  if cfg.manifest and cfg.manifest ~= '' then
    return vim.fn.filereadable(cfg.manifest) == 1 and cfg.manifest or nil
  end
  if root then
    local candidate = root .. '/smol.toml'
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= '' then
    local dir = util.find_upwards(name, { 'smol.toml' })
    if dir then
      return dir .. '/smol.toml'
    end
  end
  return nil
end

---Run `lockpick check` and populate the quickfix (or location) list.
---
---@param opts { bufnr?: integer, buffer_only?: boolean, open?: boolean, loclist?: boolean }|nil
function M.run(opts)
  opts = opts or {}
  local bufnr = (opts.bufnr == nil or opts.bufnr == 0)
      and vim.api.nvim_get_current_buf()
    or opts.bufnr
  local cfg = config.get().check
  local name = vim.api.nvim_buf_get_name(bufnr)
  local root = config.root_dir(bufnr) or (name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd())

  local exe = M.resolve_cmd(root)
  if not exe then
    util.notify(
      'lockpick not found. Install lockpick, put it on PATH, or set `check.cmd`/`lsp.source_dir`.',
      vim.log.levels.ERROR
    )
    return
  end

  local manifest = find_manifest(root, bufnr)
  local args = { exe, 'check' }
  local filter_file = nil

  if manifest then
    table.insert(args, '--manifest')
    table.insert(args, manifest)
    if opts.buffer_only and name ~= '' then
      filter_file = name
    end
  else
    if name == '' then
      util.notify('cannot check an unnamed buffer; save it as a .smol file first', vim.log.levels.ERROR)
      return
    end
    if vim.bo[bufnr].modified then
      util.notify('buffer has unsaved changes; `lockpick check` reads the file from disk', vim.log.levels.WARN)
    end
    table.insert(args, '--no-manifest')
    table.insert(args, '--files')
    table.insert(args, name)
  end

  for _, extra in ipairs(cfg.extra_args or {}) do
    table.insert(args, extra)
  end
  table.insert(args, '--format')
  table.insert(args, 'json')

  if last_job then
    pcall(last_job.kill, last_job, 15)
    last_job = nil
  end

  last_job = vim.system(args, {
    cwd = root,
    text = true,
    timeout = cfg.timeout,
  }, function(result)
    vim.schedule(function()
      last_job = nil
      local stdout = result.stdout or ''
      local stderr = result.stderr or ''

      if result.code ~= 0 and result.code ~= 1 and stdout == '' then
        util.notify('lockpick failed (exit ' .. tostring(result.code) .. ')', vim.log.levels.ERROR)
        if stderr ~= '' then
          vim.notify(stderr, vim.log.levels.ERROR)
        end
        return
      end

      local ok, decoded = pcall(vim.json.decode, stdout)
      if not ok or type(decoded) ~= 'table' then
        util.notify('could not parse lockpick JSON output', vim.log.levels.ERROR)
        if stderr ~= '' then
          vim.notify(stderr, vim.log.levels.ERROR)
        end
        return
      end

      local items, errors, warnings =
        M.to_quickfix(decoded.diagnostics or {}, root, filter_file)

      local title = 'lockpick: ' .. tostring(root)
      if opts.loclist then
        vim.fn.setloclist(0, {}, 'r', { title = title, items = items })
      else
        vim.fn.setqflist({}, 'r', { title = title, items = items })
      end

      local msg = string.format(
        'lockpick: %d error(s), %d warning(s), %d note(s)',
        decoded.error_count or errors,
        decoded.warning_count or warnings,
        decoded.note_count or 0
      )
      local level = (decoded.error_count or errors) > 0 and vim.log.levels.ERROR
        or ((decoded.warning_count or warnings) > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
      util.notify(msg, level)

      if stderr ~= '' and (decoded.error_count or 0) == 0 then
        -- Manifest/IO problems are reported as diagnostics, but keep the
        -- stderr summary available for unusual failures.
        vim.notify(stderr, vim.log.levels.WARN)
      end

      if opts.open or (cfg.open_quickfix and not opts.loclist) then
        if #items > 0 then
          if opts.loclist then
            vim.cmd('lopen')
          else
            vim.cmd('copen')
          end
        end
      end
    end)
  end)
end

---Cancel a running check, if any.
function M.cancel()
  if last_job then
    pcall(last_job.kill, last_job, 15)
    last_job = nil
  end
end

return M
