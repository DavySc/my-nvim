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
lua/config/org_babel.lua run org source blocks, write #+RESULTS:
lua/config/drracket/     DrRacket's Run, Interactions, stepper, arrows (back end: racket/)
lua/lang/<name>.lua      one per language, set up on its first buffer
ftplugin/, queries/      buffer-local settings, Souffle queries
tests/                   tests/run.sh: smoke, org-babel, DrRacket, multicursor, reload, startup budget
```

## Per-machine settings

`lua/local.lua` is git-ignored. Copy `lua/local.example.lua` and keep only
what the machine changes: which languages exist (`langs`), whether mason may
install tools, the default SQL dialect, dbbliss connections, org files, and
an `extra` function for anything else. Without the file every language is on.

## Reloading

`<leader>R` (or `:ConfigReload`) saves any config file you have open and
runs `init.lua` again, without restarting. Options, keymaps, plugin settings,
`lua/local.lua` and language setups are redone, and open buffers pick up
ftplugin changes. Plugins stay loaded, so a removed keymap, command or
plugin lingers until you restart, as do changes to snacks' settings (it
won't be set up twice). A new plugin is installed and loaded on the spot.

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

## Racket (DrRacket in Neovim)

racket-langserver does Check Syntax's jump, rename and hover. The rest of
DrRacket comes from `lua/config/drracket`, which talks to one Racket process
(`racket/drracket.rkt`, needs only a standard Racket install):

| Key | What |
| --- | --- |
| `<leader>mr` | Run: save, start over in a fresh namespace, run `main` and `test` submodules, then a REPL inside the module |
| `<leader>mi` | Interactions window (a prompt; `<Up>`/`<Down>` history) |
| `<leader>me` | send the form under the cursor, or the selection, to Interactions |
| `<leader>ms` | stop (break) the running program |
| `<leader>mx` / `<leader>mX` | macro stepper on the file or selection; `X` shows Racket's own macros too (`]s`/`[s` step) |
| `<leader>ma` | binding arrows for the name under the cursor, tail calls, unused requires |
| `<leader>md` | `raco docs` for the word under the cursor |
| `<leader>mc` | plain `racket -i` in a terminal |
| `<C-\>` | types λ (insert mode) |

The REPL uses the file's own `#lang` (its `configure-runtime`, reader and
`#%top-interaction`), so BSL rejects definitions at the prompt and your own
languages behave as they would in DrRacket. Runs have errortrace on and a
1 GB memory limit (`require("config.drracket").setup({ errortrace = false,
memory_mb = 512 })` in `extra` changes them). A runtime error puts DrRacket's
pink box and a diagnostic on the innermost expression; the stack goes to the
quickfix list. Picts and 2htdp images show inline in Ghostty and kitty
(Snacks image); elsewhere the line says `[image]` and `<CR>` opens it.

## Org

nvim-orgmode for todos, agenda (`<leader>oa`), capture (`<leader>oc`) and
tangling; otter.nvim for LSP inside source blocks. `<leader>obe` runs the
block under the cursor and writes `#+RESULTS:` (`<leader>obb`: every block):
sh, bash, python, lua, racket, pwsh, c and rust, with `:var`, `:dir` and
`:results silent`. SQL blocks run through `:Dbbliss exec` and show in its
results window.

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
