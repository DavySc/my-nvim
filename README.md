# my-nvim

One Neovim config for every machine (Neovim 0.12+, plugins through the
built-in `vim.pack`). Startup loads almost nothing: languages, completion,
git, debugging and AI load the first time they're needed.

## Layout

```
init.lua                 options, keymaps, then require("config")
lua/config/init.lua      declares plugins, sets up core, wires languages to filetypes
lua/config/lazy.lua      the loader: event / filetype / command / first require()
lua/config/machine.lua   defaults, merged with lua/local.lua
lua/config/core/*.lua    completion, lsp, treesitter, format, dap, ui, git, ai, reload
lua/config/cmake.lua     CMake driver (C/C++)
lua/lang/<name>.lua      one per language, set up on its first buffer
ftplugin/                buffer-local settings and build/run keys
tests/                   tests/run.sh: smoke, multicursor, reload, startup budget
```

## Per-machine settings

`lua/local.lua` is git-ignored. Copy `lua/local.example.lua` and keep only
what the machine changes: which languages exist (`langs`), whether mason may
install tools, and an `extra` function for anything else. Without the file
every language is on.

## Reloading

`<leader>R` (or `:ConfigReload`) saves any config file you have open and
runs `init.lua` again, without restarting. Options, keymaps, plugin settings,
`lua/local.lua` and language setups are redone, and open buffers pick up
ftplugin changes. Plugins stay loaded, so a removed keymap, command or
plugin lingers until you restart, as do changes to snacks' settings (it
won't be set up twice). A new plugin is installed and loaded on the spot.

## Languages

| Language | Server | Format | Build / run / debug |
| --- | --- | --- | --- |
| C / C++ | clangd + clangd_extensions | clang-format (with a `.clang-format`) | `:make` single file or `:CMake`; codelldb, gdb |
| Verilog / SystemVerilog | verible | verible | verilator lint, iverilog + vvp run |
| GLSL | glsl_analyzer | clang-format (with a `.clang-format`) | |
| Rust | rust-analyzer (through `nix develop` in flakes) | rustfmt | codelldb |
| Markdown | marksman | prettier (`:Format` only) | |
| Nix, Lua | nil, lua_ls | nixfmt, stylua | |

Mason installs the servers and formatters it has. `verilator` and `iverilog`
are not in mason: install them yourself (`apt install verilator iverilog`,
`brew install verilator icarus-verilog`, or the nix equivalents).

## Verilog (nand2tetris)

`<leader>m` in a `.v` / `.sv` buffer:

| Key | What |
| --- | --- |
| `<leader>mm` | `:make`: `verilator --lint-only -Wall` on the file; findings go to the quickfix list |
| `<leader>mr` | `:VerilogRun [plusargs]`: `iverilog -g2012` the file (modules it instantiates are found next to it), then `vvp` in a terminal |

Write a testbench per chip, open it, `<leader>mr`. Compile errors open the
quickfix list instead of the terminal.

## C / C++

`<leader>mm` builds, `<leader>mr` runs and `<leader>md` debugs: the
surrounding CMake project when there is one (`lua/config/cmake.lua`:
`:CMake configure|build|run|debug|target|type`), the single file otherwise
(`:make`, `:CppRun`). `<leader>ma` switches source/header.

## Shaders and markdown

GLSL files (`.glsl`, `.vert`, `.frag`, `.geom`, `.comp`, ...) get
glsl_analyzer for completion, go-to-definition and diagnostics, and
clang-format when the project has a `.clang-format`.

Markdown buffers soft-wrap, render headings, lists, tables and code blocks in
place (render-markdown.nvim) and get link and heading completion from
marksman. `:Format` runs prettier; saving never reformats.

## Git and AI

gitsigns in the gutter with hunk actions on `<leader>h`; `<leader>g` for
status, log, diff, branches (snacks pickers), `<leader>gg` for neogit and
`<leader>gG` for lazygit. `<leader>a` is Claude Code (claudecode.nvim):
toggle, add the buffer, send a selection, accept or reject a diff, and
`<leader>ae` / `<leader>ar` / `<leader>at` in visual mode to ask for an
explanation, a refactor or learning tips.

## Multiple cursors (Neovim 0.13+)

Built in (`:help multicursor`): `Q` toggles a cursor, `zq{motion}` places one
at every match (`zq*`, `zqgn`), `q=` toggles follow mode, `CTRL-L` clears,
`gQ` restores, `]C`/`[C` jump between them. On top of that, `<C-n>` adds a
cursor on the word and jumps to its next match (VS Code's Ctrl-D), and
`<leader>M` puts one on every match of the word. Nothing changes on 0.12.

## Tests

```sh
tests/run.sh            # BUDGET_MS=60 by default; NVIM_TEST_DATA=dir reuses plugins
```
