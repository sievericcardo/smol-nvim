local M = {}

local function executable_info(path)
  local stat = vim.loop.fs_stat(path)
  if not stat then
    return nil
  end
  return string.format('%.1f KiB, modified %s', stat.size / 1024, os.date('%Y-%m-%d %H:%M', stat.mtime.sec))
end

local function have_command(name)
  return vim.fn.exists(':' .. name) == 2
end

function M.check()
  vim.health.start('smol')

  -- Neovim ──────────────────────────────────────────────────────────────────
  if vim.fn.has('nvim-0.10') == 1 then
    vim.health.ok('Neovim ' .. tostring(vim.version().major) .. '.' .. tostring(vim.version().minor))
  else
    vim.health.error('smol.nvim requires Neovim 0.10 or newer')
  end

  -- Filetype ────────────────────────────────────────────────────────────────
  local ft = vim.filetype.match({ filename = 'example.smol' })
  if ft == 'smol' then
    vim.health.ok('`.smol` files are detected as filetype `smol`')
  else
    vim.health.error('`.smol` filetype detection is not active (got ' .. tostring(ft) .. ')')
  end

  -- Commands ────────────────────────────────────────────────────────────────
  local commands = {
    'SmolCheck',
    'SmolCheckBuffer',
    'SmolInstallParser',
    'SmolRestart',
    'SmolInfo',
  }
  local missing = {}
  for _, name in ipairs(commands) do
    if not have_command(name) then
      table.insert(missing, ':' .. name)
    end
  end
  if #missing == 0 then
    vim.health.ok('user commands are registered')
  else
    vim.health.warn('missing commands: ' .. table.concat(missing, ', '))
  end

  -- lockpick-lsp ────────────────────────────────────────────────────────────
  vim.health.start('smol: lockpick-lsp')
  local lsp = require('smol.lsp')
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= 'smol' then
    for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(candidate) and vim.bo[candidate].filetype == 'smol' then
        buf = candidate
        break
      end
    end
  end
  local root = require('smol.config').root_dir(buf) or vim.fn.getcwd()
  local cmd = lsp.resolve_cmd(root)
  if cmd then
    vim.health.ok('lockpick-lsp: ' .. table.concat(cmd, ' '))
    local info = executable_info(cmd[1])
    if info then
      vim.health.info(info)
    end
  else
    local cfg = require('smol.config').get().lsp
    local install_dir = lsp.install_dir()
    vim.health.error('lockpick-lsp not found', {
      'Install it from GitHub (recommended):',
      '  :SmolInstallLsp',
      'Equivalent command line:',
      '  cargo install --git ' .. cfg.git.url .. ' --bin lockpick-lsp --bin lockpick --locked --root ' .. install_dir,
      'Or put `lockpick-lsp` on your PATH, set `lsp.cmd`, or use :SmolBuildLsp with a local checkout.',
    })
  end

  vim.health.info('install dir: ' .. lsp.install_dir())
  local installed_lsp = lsp.installed_bin('lockpick-lsp')
  local installed_cli = lsp.installed_bin('lockpick')
  if installed_lsp then
    vim.health.ok('installed by nvim-smol: ' .. installed_lsp)
  else
    vim.health.info('no plugin-managed lockpick-lsp (use :SmolInstallLsp)')
  end
  if installed_cli then
    vim.health.info('plugin-managed lockpick CLI: ' .. installed_cli)
  end

  local clients = lsp.clients()
  if #clients == 0 then
    vim.health.info('no lockpick client attached to the current buffer')
  else
    for _, client in ipairs(clients) do
      vim.health.ok(
        string.format('client %d attached (root: %s)', client.id, tostring(client.root_dir))
      )
    end
  end

  local manifest = root and (root .. '/smol.toml') or nil
  if manifest and vim.fn.filereadable(manifest) == 1 then
    vim.health.ok('manifest: ' .. manifest)
  else
    vim.health.info('no smol.toml manifest found; the server checks open buffers and workspace .smol files')
  end

  -- CLI ─────────────────────────────────────────────────────────────────────
  vim.health.start('smol: lockpick CLI')
  local check = require('smol.check')
  local cli = check.resolve_cmd(root)
  if cli then
    vim.health.ok('lockpick: ' .. cli)
    local result = vim.system({ cli, '--version' }, { text = true }):wait(3000)
    local version = (result.stdout or ''):gsub('%s+$', '')
    if result.code == 0 and version ~= '' then
      vim.health.info(version)
    end
  else
    vim.health.warn('lockpick CLI not found; `:SmolCheck` will not work (LSP diagnostics still do)', {
      'Run :SmolInstallLsp to install both `lockpick-lsp` and `lockpick`.',
    })
  end

  -- tree-sitter ─────────────────────────────────────────────────────────────
  vim.health.start('smol: tree-sitter')
  local ts = require('smol.treesitter')
  local status = ts.status()
  if status.grammar_dir then
    vim.health.ok('bundled grammar: ' .. status.grammar_dir)
  else
    vim.health.error('bundled grammar not found in runtimepath')
  end

  if status.path then
    vim.health.ok('parser: ' .. status.path)
    local info = executable_info(status.path)
    if info then
      vim.health.info(info)
    end
  else
    vim.health.warn('no compiled parser found; using Vim syntax highlighting', {
      'Run :SmolInstallParser (requires a C compiler), or',
      'install the grammar with nvim-treesitter.',
    })
  end

  if status.available then
    vim.health.ok('parser loads successfully')
    for _, query in ipairs({ 'highlights', 'folds', 'indents', 'locals', 'textobjects' }) do
      local ok, result = pcall(vim.treesitter.query.get, 'smol', query)
      if ok and result then
        vim.health.ok('query `' .. query .. '` loaded')
      else
        vim.health.warn('query `' .. query .. '` unavailable: ' .. tostring(result))
      end
    end
  else
    vim.health.warn('parser is not installed')
  end

  local compiler = vim.env.CC or 'cc'
  if vim.fn.executable(compiler) == 1 then
    vim.health.info('C compiler: ' .. compiler)
  else
    vim.health.info('C compiler `' .. compiler .. '` not found on PATH (needed by :SmolInstallParser)')
  end
end

return M
