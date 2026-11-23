local M = {}

local function notify_lines(lines)
  vim.notify(table.concat(lines, '\n'))
end

---Register all `:Smol*` commands. Idempotent.
function M.setup()
  if M._installed then
    return
  end
  M._installed = true

  local function cmd(name, fn, opts)
    opts = opts or {}
    opts.desc = opts.desc or ('SMOL: ' .. name)
    opts.force = true
    vim.api.nvim_create_user_command(name, fn, opts)
  end

  cmd('SmolCheck', function(args)
    require('smol.check').run({ open = args.bang })
  end, { bang = true, desc = 'SMOL: run lockpick check on the project' })

  cmd('SmolCheckBuffer', function(args)
    require('smol.check').run({ buffer_only = true, loclist = true, open = args.bang })
  end, { bang = true, desc = 'SMOL: run lockpick check and show this buffer in the loclist' })

  cmd('SmolCheckCancel', function()
    require('smol.check').cancel()
  end, { desc = 'SMOL: cancel a running lockpick check' })

  cmd('SmolRestart', function()
    require('smol.lsp').restart(0)
  end, { desc = 'SMOL: restart lockpick-lsp' })

  cmd('SmolStop', function()
    require('smol.lsp').stop(true)
  end, { desc = 'SMOL: stop lockpick-lsp' })

  cmd('SmolInstallParser', function(args)
    require('smol.treesitter').install({ force = args.bang })
  end, { bang = true, desc = 'SMOL: compile the bundled tree-sitter parser' })

  cmd('SmolTreesitter', function()
    require('smol.treesitter').toggle(0)
  end, { desc = 'SMOL: toggle tree-sitter highlighting for this buffer' })

  cmd('SmolBuildLsp', function(args)
    require('smol.lsp').build({ source_dir = args.args ~= '' and args.args or nil })
  end, { nargs = '?', complete = 'dir', desc = 'SMOL: cargo build lockpick-lsp from a checkout' })

  cmd('SmolInfo', function()
    local lines = {}
    vim.list_extend(lines, { 'lockpick-lsp', '─────────────' })
    vim.list_extend(lines, require('smol.lsp').info())
    local ts = require('smol.treesitter').status()
    vim.list_extend(lines, {
      '',
      'tree-sitter',
      '───────────',
      'parser: ' .. tostring(ts.path),
      'loaded: ' .. tostring(ts.available),
      'grammar: ' .. tostring(ts.grammar_dir),
    })
    notify_lines(lines)
  end, { desc = 'SMOL: show lockpick-lsp and tree-sitter status' })

  cmd('SmolHealth', function()
    vim.cmd('checkhealth smol')
  end, { desc = 'SMOL: open :checkhealth smol' })
end

return M
