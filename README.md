# nvim-smol

Neovim support for **SMOL** — the Sensor Modelling and Ontology Language used by
[lockpick](https://github.com/sievericcardo/lockpick).

- **lockpick-lsp integration** — live verification diagnostics in Neovim.
- **Bundled tree-sitter grammar** — precise highlighting; queries for folds,
  indentation, locals, and text objects. No `nvim-treesitter` required for
  highlighting.
- **Vim syntax fallback** — everything still highlights without a C compiler.
- **`:SmolCheck`** — run the `lockpick` CLI and fill the quickfix list.
- **Filetype, comments, indentation** — sensible defaults for `.smol`.

```
┌──────────────────────────────────────────────────────────────┐
│ class RoomModel extends BaseModel()                          │
│     override Unit adaptAddition()                            │
│         List<TreatingRoom> newRooms = construct("…");        │
│         if newRooms != null then                             │
│             print("Adding new Room(s)…");                    │
│         end                                                  │
│     end                                                      │
│ end                                                          │
└──────────────────────────────────────────────────────────────┘
```

## Requirements

- Neovim **0.10+** (tested on 0.12).
- [lockpick](https://github.com/sievericcardo/lockpick) for verification:
  - `lockpick-lsp` for live diagnostics,
  - `lockpick` for `:SmolCheck`.
- A C compiler (`cc`/`clang`/`gcc`) **only** if you want the bundled
  tree-sitter parser. Vim syntax works without one.

Build lockpick's binaries (requires Rust, CMake and libclang):

```bash
git clone https://github.com/sievericcardo/lockpick
cd lockpick
cargo build --release
# optional: make them available everywhere
cp target/release/lockpick target/release/lockpick-lsp ~/.local/bin/
```

## Installation

### lazy.nvim

```lua
{
  'sievericcardo/nvim-smol', -- or a local path
  ft = 'smol',
  opts = {
    lsp = {
      -- omit `cmd` to auto-detect lockpick-lsp on PATH or in
      -- <root>/target/release/lockpick-lsp
      cmd = { 'lockpick-lsp' },
      source_dir = vim.fn.expand('~/Documents/GitHub/lockpick'), -- for :SmolBuildLsp
    },
    keymaps = {
      check = '<leader>sc',
      check_buffer = '<leader>sB',
    },
  },
}
```

### packer.nvim

```lua
use({
  'sievericcardo/nvim-smol',
  ft = 'smol',
  config = function()
    require('smol').setup({})
  end,
})
```

### Native packages

```bash
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/sievericcardo/nvim-smol \
  ~/.local/share/nvim/site/pack/plugins/start/nvim-smol
```

Then add this to `init.lua` (optional — defaults work):

```lua
require('smol').setup({})
```

## Setup

`setup()` is optional. With no options the plugin:

1. detects `.smol` files,
2. enables Vim syntax highlighting,
3. starts `lockpick-lsp` on `FileType smol` when it can find it,
4. starts the bundled tree-sitter parser **if it is already installed**.

```lua
require('smol').setup({
  lsp = {
    enabled = true,
    auto_start = true,
    cmd = nil,                  -- nil = auto-detect; or { '/path/to/lockpick-lsp' }
    source_dir = nil,           -- lockpick checkout for :SmolBuildLsp
    root_markers = { 'smol.toml', '.git' },
    settings = {},
    init_options = {},
    on_attach = nil,            -- fun(client, bufnr)
    notify_missing = true,
  },
  treesitter = {
    enabled = true,
    auto_start = true,          -- start if a parser is available
    cc = nil,                   -- override compiler, e.g. 'clang'
    folds = false,              -- use the tree-sitter folds query
  },
  syntax = {
    enabled = true,             -- Vim syntax fallback
  },
  check = {
    cmd = nil,                  -- nil = auto-detect lockpick
    manifest = nil,             -- override smol.toml discovery
    extra_args = {},            -- e.g. { '--prefix', 'ast=http://example.org/ast/' }
    open_quickfix = false,
    timeout = 120000,
  },
  keymaps = {
    check = false,              -- e.g. '<leader>sc'
    check_buffer = false,       -- e.g. '<leader>sB'
  },
})
```

`lsp.cmd`, `check.cmd`, and `lsp.source_dir` may also be set with the
`LOCKPICK_LSP`, `LOCKPICK`, and `LOCKPICK_DIR` environment variables.

## Language server

Start automatically via `FileType smol`, or manually:

```vim
:lua require('smol').start_lsp()
```

`lockpick-lsp` currently provides **diagnostics** (LSP 3.17 over stdio, full
text sync). SMOL errors and warnings appear with their `E####`/`W####` codes and
lockpick's source ranges.

Useful commands:

| Command | Description |
| --- | --- |
| `:SmolCheck` | Run `lockpick check` and fill the quickfix list |
| `:SmolCheck!` | Same, then open the quickfix window |
| `:SmolCheckBuffer` | Project check filtered to the current buffer (loclist) |
| `:SmolCheckBuffer!` | Same, then open the location list |
| `:SmolCheckCancel` | Cancel a running check |
| `:SmolRestart` | Restart `lockpick-lsp` and re-attach open buffers |
| `:SmolStop` | Stop `lockpick-lsp` |
| `:SmolInfo` | Show LSP/tree-sitter status |
| `:SmolHealth` | Open `:checkhealth smol` |
| `:SmolInstallParser` | Compile the bundled tree-sitter parser |
| `:SmolTreesitter` | Toggle tree-sitter for the current buffer |
| `:SmolBuildLsp [dir]` | `cargo build --release --bin lockpick-lsp` |

### How `:SmolCheck` chooses files

1. `check.manifest`, if set.
2. `smol.toml` in the buffer's project root (the closest parent containing
   `smol.toml` or `.git`).
3. Otherwise the current file, via `lockpick check --no-manifest --files <file>`.

The JSON output is converted to quickfix entries with lockpick's byte spans
mapped to 1-based line/column positions.

### Diagnostics vs. quickfix

Prefer the LSP for live feedback: it validates the in-memory buffer and updates
after every change. `:SmolCheck` is useful for CI-like runs, prefix/ontology
flags, and jumping through the full project report.

## Tree-sitter

The repository contains a complete grammar in
[`tree-sitter-smol/`](tree-sitter-smol/), including the generated `parser.c`.
The Neovim plugin compiles it on demand:

```vim
:SmolInstallParser
```

This writes `smol.so` to `stdpath('data')/site/parser/` (on this machine:
`~/.local/share/nvim/site/parser/smol.so`). Restart Neovim if a parser with the
same name was already loaded.

If you prefer `nvim-treesitter`, install the parser from this repository instead
of using `:SmolInstallParser`.

Highlight groups provided by the grammar/queries:

- keywords, conditionals, repeats, statements, built-in types and functions
- classes, method definitions/calls, fields, parameters, locals
- strings (including multi-line SPARQL/InfluxQL/Turtle), numbers, booleans
- SPARQL/Turtle/IRI annotation strings (`string.special`)
- JML contracts (`/*@ requires … @*/` as documentation comments)

The bundled queries in [`queries/smol/`](queries/smol/) cover highlights,
folds, indents, locals, and text objects. Neovim uses the highlights query
automatically; set `treesitter.folds = true` to wire the folds query to
`foldmethod=expr`. The indentation, locals and text-object queries are consumed
by [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) and
[nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
when those plugins are installed; without them you still get highlighting,
folds (opt-in), 4-space indentation, and Vim's syntax fallback.

## Vim syntax fallback

When no tree-sitter parser is installed, `syntax/smol.vim` highlights SMOL with
regular expressions (including multi-line strings). It is intentionally simple
and dependency-free. `:SmolInstallParser` upgrades you to tree-sitter at any
time.

## Filetype and editor defaults

- `.smol` → `filetype=smol`
- `commentstring=// %s`
- line comments `//`, block comments `/* … */`
- 4-space indentation, `expandtab` (disable with `let g:smol_indent = 0`)

## Health checks

```vim
:checkhealth smol
```

Reports the resolved `lockpick-lsp` and `lockpick` binaries, the workspace
manifest, parser location, query availability, and a compiler for
`:SmolInstallParser`.

## Troubleshooting

**`lockpick-lsp not found`**

Put it on your `PATH`, set `lsp.cmd`, or point `lsp.source_dir` /
`$LOCKPICK_DIR` at a lockpick checkout and run `:SmolBuildLsp`.

**No parser / tree-sitter does nothing**

Run `:SmolInstallParser`, then `:SmolInfo`. If it reports "no C compiler", set
`treesitter.cc = 'clang'`. On Windows use a clang/MSVC toolchain that supports
`-shared`.

**The server verifies the wrong project**

The workspace root is the closest ancestor containing `smol.toml` or `.git`.
Add a `smol.toml` at the project root, or customise `lsp.root_markers`.

**Manifest checks fail when running from a different directory**

The plugin always passes an absolute manifest path to the CLI. If you invoke
`lockpick` manually, prefer `--manifest /abs/path/smol.toml`.

**Diagnostics are slow on a big project**

`lockpick-lsp` re-verifies the whole workspace on every change. This is a
property of the server, not the client. Use `:SmolStop` temporarily if needed.

## Syntax notes

The grammar follows lockpick's PEG grammar (`smol.pest`):

- `class`, `abstract class`, `hidden class`, `extends`, generics, `FMO[...]`
- fields with `hidden` / `domain` / `context`, initialized fields, `links` /
  `classifies` / `retrieves` annotations
- methods with `abstract`, `rule`, `domain`, `override`, `adapts`
- statements: `if`/`then`/`else`, `while`/`do` (+ optional `decreases`),
  `print`, `destroy`, `skip`, `breakpoint`, `return`, declarations,
  assignments, calls
- expressions: `access`, `construct`, `classify`, `adapt`, `member`,
  `validate`, `simulate`, `super`, `port`, `INFLUXDB`/`SPARQL` modes
- comments and JML-style contracts (`/*@ … @*/`)

A known limitation, inherited from editor grammars that need a deterministic
LR(1) parse: class/type names are expected to start with an uppercase letter
(variables, fields and methods start lowercase). This matches every SMOL
program shipped with lockpick and the `smol-vs-code` grammar.

## Development

```bash
# Run the headless Neovim suite. It compiles the parser in a temp XDG data dir
# and, when available, exercises the real lockpick CLI and language server.
make test

# Regenerate parser.c after editing tree-sitter-smol/grammar.js
make generate

# Run the tree-sitter corpus tests
make ts-test

# Parse the complete lockpick example corpus (must produce zero ERROR nodes)
make corpus LOCKPICK_DIR=~/Documents/GitHub/lockpick
```

The test suite is `tests/smoke.lua`; it asserts filetype detection, syntax
loading, offset mapping, quickfix conversion, parser compilation, all queries,
and optional CLI/LSP integration.

## Credits

- [lockpick](https://github.com/sievericcardo/lockpick) — verifier and language
  server by Riccardo Sieve.
- [smol-vs-code](https://github.com/smolang/smol-vs-code) — the VS Code
  extension whose TextMate grammar informed the keyword/type sets.

## License

MIT — see [LICENSE](LICENSE).
