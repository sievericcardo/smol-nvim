local config = require('smol.config')
local util = require('smol.util')

local M = {}

local LANG = 'smol'
local warned = false

---@return string
local function parser_ext()
  return vim.fn.has('win32') == 1 and '.dll' or '.so'
end

---@return string|nil
local function site_parser_path()
  return vim.fn.stdpath('data') .. '/site/parser/' .. LANG .. parser_ext()
end

---@return string|nil
function M.parser_path()
  local candidates = {
    site_parser_path(),
    util.plugin_root() and (util.plugin_root() .. '/parser/' .. LANG .. parser_ext()) or nil,
  }
  for _, candidate in ipairs(candidates) do
    if candidate and vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  local found = vim.api.nvim_get_runtime_file('parser/' .. LANG .. parser_ext(), false)
  return found[1]
end

---Make sure the language is registered with Neovim's tree-sitter runtime.
---@return boolean
function M.ensure_language()
  if M._loaded then
    return true
  end
  local ok, loaded = pcall(vim.treesitter.language.add, LANG)
  if ok and loaded then
    M._loaded = true
    return true
  end
  local path = M.parser_path()
  if not path then
    return false
  end
  ok, loaded = pcall(vim.treesitter.language.add, LANG, { path = path })
  if not ok or not loaded then
    ok, loaded = pcall(vim.treesitter.language.add, LANG, path)
  end
  M._loaded = ok and loaded == true
  return M._loaded
end

---@return boolean
function M.available()
  return M.ensure_language()
end

---Start tree-sitter highlighting for a buffer.
---@param bufnr integer|nil
---@return boolean
function M.start(bufnr)
  bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
  local cfg = config.get().treesitter
  if not cfg.enabled then
    return false
  end
  if not M.ensure_language() then
    if not warned then
      warned = true
      util.notify(
        'tree-sitter parser for SMOL is not installed; using Vim syntax. '
          .. 'Run :SmolInstallParser (requires a C compiler).',
        vim.log.levels.INFO
      )
    end
    return false
  end

  local ok, err = pcall(vim.treesitter.start, bufnr, LANG)
  if not ok then
    util.notify('could not start tree-sitter: ' .. tostring(err), vim.log.levels.WARN)
    return false
  end
  vim.b[bufnr].smol_treesitter = true

  if cfg.folds and not vim.b[bufnr].smol_previous_foldmethod then
    local wins = vim.fn.win_findbuf(bufnr)
    if #wins > 0 then
      local first = wins[1]
      vim.b[bufnr].smol_previous_foldmethod =
        vim.api.nvim_get_option_value('foldmethod', { win = first })
      vim.b[bufnr].smol_previous_foldexpr =
        vim.api.nvim_get_option_value('foldexpr', { win = first })
      for _, win in ipairs(wins) do
        vim.api.nvim_set_option_value('foldmethod', 'expr', { win = win })
        vim.api.nvim_set_option_value(
          'foldexpr',
          'v:lua.vim.treesitter.foldexpr()',
          { win = win }
        )
      end
    end
  end
  return true
end

---Stop tree-sitter highlighting for a buffer.
---@param bufnr integer|nil
function M.stop(bufnr)
  bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
  pcall(vim.treesitter.stop, bufnr)
  if vim.b[bufnr].smol_previous_foldmethod then
    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
      vim.api.nvim_set_option_value(
        'foldmethod',
        vim.b[bufnr].smol_previous_foldmethod,
        { win = win }
      )
      vim.api.nvim_set_option_value(
        'foldexpr',
        vim.b[bufnr].smol_previous_foldexpr or '0',
        { win = win }
      )
    end
    vim.b[bufnr].smol_previous_foldmethod = nil
    vim.b[bufnr].smol_previous_foldexpr = nil
  end
  vim.b[bufnr].smol_treesitter = false
end

---@param bufnr integer|nil
function M.toggle(bufnr)
  bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
  if vim.b[bufnr].smol_treesitter then
    M.stop(bufnr)
    util.notify('tree-sitter disabled for this buffer')
  elseif M.start(bufnr) then
    util.notify('tree-sitter enabled for this buffer')
  end
end

---@return string[]|nil
local function find_grammar_dir()
  local grammar = vim.api.nvim_get_runtime_file('tree-sitter-smol/grammar.js', false)[1]
  if grammar then
    return vim.fs.dirname(grammar)
  end
  return nil
end

---@return string|nil
local function find_compiler()
  local cfg = config.get().treesitter
  local candidates = {}
  if cfg.cc then
    table.insert(candidates, cfg.cc)
  end
  if vim.env.CC and vim.env.CC ~= '' then
    table.insert(candidates, vim.env.CC)
  end
  vim.list_extend(candidates, { 'cc', 'clang', 'gcc' })
  for _, candidate in ipairs(candidates) do
    if util.is_executable(candidate) then
      return candidate
    end
  end
  return nil
end

---Compile the bundled tree-sitter grammar into Neovim's site parser dir.
---@param opts { force?: boolean }|nil
---@return boolean ok
function M.install(opts)
  opts = opts or {}
  local out = site_parser_path()
  if not opts.force and M.available() then
    util.notify('SMOL tree-sitter parser already available at ' .. tostring(M.parser_path()))
    return true
  end

  local dir = find_grammar_dir()
  if not dir then
    util.notify('bundled tree-sitter grammar not found in runtimepath', vim.log.levels.ERROR)
    return false
  end

  local parser_c = dir .. '/src/parser.c'
  if vim.fn.filereadable(parser_c) ~= 1 then
    util.notify(
      'missing ' .. parser_c .. '; run `tree-sitter generate` in ' .. dir,
      vim.log.levels.ERROR
    )
    return false
  end

  local cc = find_compiler()
  if not cc then
    util.notify('no C compiler found (set g:smol or treesitter.cc, or $CC)', vim.log.levels.ERROR)
    return false
  end

  vim.fn.mkdir(vim.fs.dirname(out), 'p')
  local args = {
    cc,
    '-O2',
    '-fPIC',
    '-shared',
    '-I',
    dir .. '/src',
    parser_c,
  }
  local scanner = dir .. '/src/scanner.c'
  if vim.fn.filereadable(scanner) == 1 then
    table.insert(args, scanner)
  end
  table.insert(args, '-o')
  table.insert(args, out)

  util.notify('compiling SMOL tree-sitter parser with ' .. cc .. '…')
  local result = vim.system(args, { cwd = dir, text = true }):wait(120000)
  if result.code ~= 0 then
    util.notify('parser compilation failed', vim.log.levels.ERROR)
    vim.notify((result.stdout or '') .. (result.stderr or ''), vim.log.levels.ERROR)
    return false
  end

  M._loaded = false
  local ok, loaded = pcall(vim.treesitter.language.add, LANG, { path = out })
  if not ok or not loaded then
    ok, loaded = pcall(vim.treesitter.language.add, LANG, out)
  end
  if not ok or not loaded then
    util.notify('parser built but Neovim refused to load it', vim.log.levels.ERROR)
    return false
  end
  M._loaded = true
  util.notify('installed tree-sitter parser at ' .. out)
  if vim.bo.filetype == 'smol' then
    M.start(0)
  end
  return true
end

---@return { path: string|nil, available: boolean, grammar_dir: string|nil }
function M.status()
  return {
    path = M.parser_path(),
    available = M.available(),
    grammar_dir = find_grammar_dir(),
  }
end

return M
