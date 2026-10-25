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
lua/config/core/*.lua    completion, lsp, treesitter, format, dap, ui, git, ai
lua/config/cmake.lua     CMake driver (C/C++)
lua/config/org_babel.lua run org source blocks, write #+RESULTS:
lua/lang/<name>.lua      one per language, set up on its first buffer
ftplugin/, queries/      buffer-local settings, Souffle queries
tests/                   tests/run.sh: smoke test, org-babel test, startup budget
```

## Per-machine settings

`lua/local.lua` is git-ignored. Copy `lua/local.example.lua` and keep only
what the machine changes: which languages exist (`langs`), whether mason may
install tools, the default SQL dialect, dbbliss connections, org files, and
an `extra` function for anything else. Without the file every language is on.

## Languages

| Language | Server | Format | Debug |
| --- | --- | --- | --- |
| SQL (T-SQL, PostgreSQL) | dbbliss.nvim (run, complete, plans); `postgres_lsp` where configured | sqlfluff, per-buffer dialect | |
| C# | Roslyn (roslyn.nvim) | csharpier | netcoredbg |
| Rust | rust-analyzer (through `nix develop` in flakes) | rustfmt | codelldb |
| C / C++ | clangd + clangd_extensions | clang-format (with a `.clang-format`) | codelldb, gdb |
| Verilog / SystemVerilog | verible | verible | |
| Racket | racket-langserver (`raco pkg install racket-langserver fmt`) | raco fmt | |
| Haskell / Clash | HLS (through `nix develop` in flakes) | fourmolu | |
| Nix, Lua, Souffle | nil, lua_ls, (none) | nixfmt, stylua | |

SQL dialect, first match wins: the engine of the dbbliss connection the
buffer runs on, the extension (`.pgsql`/`.psql`, `.tsql`), `b:sql_dialect`,
then `sql.dialect` from the machine file.

## Org

nvim-orgmode for todos, agenda (`<leader>oa`), capture (`<leader>oc`) and
tangling; otter.nvim for LSP inside source blocks. `<leader>oe` runs the
block under the cursor and writes `#+RESULTS:` (`<leader>oE`: every block):
sh, bash, python, lua, racket, pwsh, c and rust, with `:var`, `:dir` and
`:results silent`. SQL blocks run through `:Dbbliss exec` and show in its
results window.

## Tests

```sh
tests/run.sh            # BUDGET_MS=60 by default; NVIM_TEST_DATA=dir reuses plugins
```
