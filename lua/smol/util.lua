local M = {}

---Notify with a stable prefix so messages are easy to recognise.
---@param msg string
---@param level integer|nil
function M.notify(msg, level)
  vim.notify('smol.nvim: ' .. msg, level or vim.log.levels.INFO)
end

---Return `true` when `path` is an executable file.
---@param path string|nil
---@return boolean
function M.is_executable(path)
  return type(path) == 'string' and path ~= '' and vim.fn.executable(path) == 1
end

---Find the first executable among the candidates.
---@param candidates (string|nil)[]
---@return string|nil
function M.first_executable(candidates)
  for _, candidate in ipairs(candidates) do
    if M.is_executable(candidate) then
      return candidate
    end
  end
  return nil
end

---Absolute path of the plugin root, or nil.
---@return string|nil
function M.plugin_root()
  local init = vim.api.nvim_get_runtime_file('lua/smol/init.lua', false)[1]
  if not init then
    return nil
  end
  return vim.fn.fnamemodify(init, ':h:h:h')
end

---Read a file as a string. Returns nil when the file cannot be read.
---@param path string
---@return string|nil
function M.read_file(path)
  local fd = io.open(path, 'rb')
  if not fd then
    return nil
  end
  local text = fd:read('*a')
  fd:close()
  return text
end

---Lines of a file (or of a loaded buffer) without line-ending translation.
---Preferring the buffer keeps `:SmolCheck` positions correct for saved buffers
---that are still loaded.
---@param path string
---@return string[]
function M.file_lines(path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
  local ok, lines = pcall(vim.fn.readfile, path, 'b')
  if ok then
    return lines
  end
  return {}
end

---Convert a byte offset in `text` to a 0-based (line, byte-column) pair.
---SMOL spans produced by lockpick are byte offsets.
---@param text string
---@param offset integer|nil
---@return integer line, integer col
function M.offset_to_position(text, offset)
  offset = math.max(0, math.min(offset or 0, #text))
  local line, last_newline = 0, 0
  for i = 1, offset do
    if text:byte(i) == 10 then
      line = line + 1
      last_newline = i
    end
  end
  return line, offset - last_newline
end

---Join lines into the text a quickfix offset was computed against.
---@param lines string[]
---@return string
function M.join_lines(lines)
  return table.concat(lines, '\n')
end

---Human-readable description of a diagnostic severity.
---@param severity string|nil
---@return string type, integer level
function M.severity(severity)
  if severity == 'error' then
    return 'E', vim.log.levels.ERROR
  elseif severity == 'warning' then
    return 'W', vim.log.levels.WARN
  end
  return 'I', vim.log.levels.INFO
end

---Find a directory containing a marker by walking up from `start`.
---@param start string|nil
---@param markers string[]
---@return string|nil
function M.find_upwards(start, markers)
  if not start or start == '' then
    return nil
  end
  local dir = vim.fn.fnamemodify(start, ':p')
  if vim.fn.isdirectory(dir) == 0 then
    dir = vim.fs.dirname(dir)
  end
  while dir and dir ~= '' do
    for _, marker in ipairs(markers) do
      if vim.fn.filereadable(dir .. '/' .. marker) == 1 or vim.fn.isdirectory(dir .. '/' .. marker) == 1 then
        return dir
      end
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      return nil
    end
    dir = parent
  end
  return nil
end

return M
