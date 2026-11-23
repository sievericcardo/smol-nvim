local failures = 0
local checks = 0

local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write('FAIL: ' .. message .. '\n')
  end
end

local function eq(actual, expected, message)
  check(
    actual == expected,
    string.format('%s (expected %s, got %s)', message, vim.inspect(expected), vim.inspect(actual))
  )
end

local here = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(here, ':h:h')
local fixtures = root .. '/tests/fixtures'

-- ── Filetype, syntax and ftplugin ───────────────────────────────────────────
vim.cmd('edit ' .. vim.fn.fnameescape(fixtures .. '/kitchen-sink.smol'))
eq(vim.bo.filetype, 'smol', 'filetype detected')
eq(vim.bo.commentstring, '// %s', 'commentstring')
eq(vim.bo.shiftwidth, 4, 'shiftwidth')
check(vim.fn.exists(':SmolCheck') == 2, ':SmolCheck exists')
check(vim.fn.exists(':SmolCheckBuffer') == 2, ':SmolCheckBuffer exists')
check(vim.fn.exists(':SmolInstallParser') == 2, ':SmolInstallParser exists')
check(vim.fn.exists(':SmolInfo') == 2, ':SmolInfo exists')
check(vim.b.current_syntax == 'smol', 'Vim syntax file loaded')

-- ── Root detection ──────────────────────────────────────────────────────────
local config = require('smol.config')
local root_dir = config.root_dir(0)
check(root_dir ~= nil, 'root_dir finds a project root')

-- ── Byte offsets → positions ────────────────────────────────────────────────
local util = require('smol.util')
local line, col = util.offset_to_position('a\nbb\nccc', 3)
eq(line, 1, 'offset_to_position line')
eq(col, 1, 'offset_to_position column')

-- ── Diagnostics → quickfix ──────────────────────────────────────────────────
local checkmod = require('smol.check')
local tmpdir = vim.fn.fnamemodify(vim.fn.tempname(), ':h')
vim.fn.mkdir(tmpdir, 'p')
vim.fn.writefile({ 'class A() end', 'class B() end' }, tmpdir .. '/B.smol')
local diag = {
  severity = 'error',
  code = 'E2004',
  code_number = 2004,
  message = 'type mismatch in assignment',
  file = 'B.smol',
  span = { start = 14, ['end'] = 19 },
}
local items = checkmod.to_quickfix({ diag }, tmpdir)
eq(#items, 1, 'one quickfix item')
eq(items[1].filename, tmpdir .. '/B.smol', 'quickfix filename resolved')
eq(items[1].lnum, 2, 'quickfix line')
eq(items[1].col, 1, 'quickfix column')
eq(items[1].type, 'E', 'quickfix type')
check(items[1].text:find('E2004', 1, true) ~= nil, 'quickfix text contains code')

local filtered = checkmod.to_quickfix({ diag }, tmpdir, tmpdir .. '/A.smol')
eq(#filtered, 0, 'buffer filter excludes other files')
_ = text

-- ── tree-sitter parser + queries ────────────────────────────────────────────
local ts = require('smol.treesitter')
check(ts.install({ force = true }), 'bundled parser compiles and loads')
check(ts.available(), 'parser available after install')

local source = table.concat(vim.fn.readfile(fixtures .. '/kitchen-sink.smol'), '\n')
local parser = vim.treesitter.get_string_parser(source, 'smol')
local tree = parser:parse()[1]
check(not tree:root():has_error(), 'fixture parses without ERROR nodes')

for _, query in ipairs({ 'highlights', 'folds', 'indents', 'locals', 'textobjects' }) do
  local q = vim.treesitter.query.get('smol', query)
  check(q ~= nil, 'query loaded: ' .. query)
  if q then
    local n = 0
    for _ in q:iter_captures(tree:root(), source) do
      n = n + 1
    end
    check(n > 0, 'query produced captures: ' .. query)
  end
end

-- Start/stop tree-sitter on a real buffer (with tree-sitter folds).
local previous_foldmethod = vim.wo.foldmethod
require('smol.config').get().treesitter.folds = true
check(ts.start(0), 'tree-sitter starts on the buffer')
eq(vim.wo.foldmethod, 'expr', 'tree-sitter folds enabled')
eq(vim.wo.foldexpr, 'v:lua.vim.treesitter.foldexpr()', 'tree-sitter foldexpr set')
ts.stop(0)
eq(vim.wo.foldmethod, previous_foldmethod, 'foldmethod restored')

-- ── Optional: real lockpick CLI integration ────────────────────────────────
if vim.env.SMOL_TEST_LOCKPICK and vim.env.SMOL_TEST_LOCKPICK ~= '' then
  vim.cmd('edit ' .. vim.fn.fnameescape(fixtures .. '/errors.smol'))
  vim.fn.setqflist({}, 'r', { title = 'test-reset', items = {} })
  checkmod.run({ bufnr = 0 })
  local populated = vim.wait(30000, function()
    local title = vim.fn.getqflist({ title = 1 }).title
    return title ~= nil and title:match('^lockpick:') ~= nil
  end, 100)
  check(populated, 'lockpick check populated the quickfix list')
  if populated then
    local qf = vim.fn.getqflist()
    check(#qf > 0, 'quickfix contains diagnostics for errors.smol')
  end
end

-- ── Optional: real lockpick-lsp integration ─────────────────────────────────
if vim.env.SMOL_TEST_LSP and vim.env.SMOL_TEST_LSP ~= '' then
  local project = vim.fn.fnamemodify(vim.fn.tempname(), ':h') .. '/smol-lsp-project'
  vim.fn.mkdir(project, 'p')
  vim.fn.writefile({
    '[project]',
    'name = "test"',
    '',
    '[sources]',
    'files = ["*.smol"]',
  }, project .. '/smol.toml')
  vim.fn.writefile({ 'class Thing() end' }, project .. '/Thing.smol')
  vim.fn.writefile({ 'class Bad (List<Thing> things) end' }, project .. '/Bad.smol')

  vim.cmd('edit ' .. vim.fn.fnameescape(project .. '/Bad.smol'))
  eq(vim.fn.resolve(require('smol.config').root_dir(0)), vim.fn.resolve(project), 'LSP workspace root resolved from smol.toml')

  local client = require('smol.lsp').start(0)
  check(client ~= nil, 'lockpick-lsp client starts')
  if client then
    local got = vim.wait(30000, function()
      return #vim.diagnostic.get(0) > 0
    end, 200)
    check(got, 'lockpick-lsp publishes diagnostics')
    local found = false
    for _, diagnostic in ipairs(vim.diagnostic.get(0)) do
      if diagnostic.code == 'E2013' and diagnostic.source == 'lockpick' then
        found = true
      end
    end
    check(found, 'E2013 diagnostic from lockpick-lsp')
    require('smol.lsp').stop(true)
  end

  vim.cmd('bwipeout!')
  vim.fn.delete(project, 'rf')
end

-- ── Result ──────────────────────────────────────────────────────────────────
if failures > 0 then
  io.stderr:write(string.format('\n%d/%d checks failed\n', failures, checks))
  vim.cmd('cquit 1')
else
  print(string.format('ok — %d checks passed', checks))
  vim.cmd('quitall!')
end
