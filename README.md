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
lua/config/core/*.lua    completion, lsp, treesitter, format, dap, ui, git, ai, reload,
                         splash (dashboard cat), kitten (on save), files (oil)
lua/config/org_pretty.lua  \alpha → α in org buffers
lua/config/cmake.lua     CMake driver (C/C++)
lua/lang/<name>.lua      one per language, set up on its first buffer
ftplugin/                buffer-local settings and build/run keys
tests/                   tests/run.sh: smoke, multicursor, reload, features, startup budget
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
| SQL (T-SQL, PostgreSQL) | dbbliss.nvim (run, live completion, plans, schema tree; `:Dbbliss`), postgres_lsp where a project configures it | sqlfluff | |
| Nix, Lua | nil, lua_ls | nixfmt, stylua | |
| Org | (nvim-orgmode) | | agenda `<leader>oa`, capture `<leader>oc` |

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

## Org and LaTeX

`.org` files get nvim-orgmode, set up like kittymax: notes in `~/org`, an
inbox (`<leader>oc` captures a task `t`, a note `n` or a journal entry `j`
into a datetree), TODO / NEXT / WAIT / DONE / CANCELLED, and the agenda on
`<leader>oa` from anywhere. Headings get bullets, emphasis markers and link
targets are hidden, and the line under the cursor always shows the text as
typed (org-appear's behaviour).

LaTeX shows two ways:

- **Symbols**, everywhere: `\alpha` → α, `\to` → →, `x^{2}` → x², `a_{ij}`
  → aᵢⱼ (org-pretty-entities; sub- and superscripts need braces). Src and
  example blocks, `: fixed-width` lines and `=verbatim=` stay as typed.
  `<leader>up` turns it off.
- **Rendered math**, in kitty, Ghostty and WezTerm: `$...$`, `\(...\)`,
  `\[...\]`, `\begin{...}` and equation blocks become typeset images
  (snacks.image). It needs `tectonic` or `pdflatex`, and ImageMagick; check
  with `:checkhealth snacks`. Markdown gets images and math the same way.

orgmode builds its treesitter grammar the first time you open an org file
(git and a C compiler).

## Files: oil

oil.nvim replaces netrw: a directory is a buffer you edit like any other.
Rename by changing a line, delete with `dd`, create with a new line (ending
in `/` for a directory), move with cut and paste between oil buffers, then
`:w` applies it all. `-` opens the parent of the current file (and goes up
again inside oil), `<CR>` opens, `<C-p>` previews, `g.` hides dotfiles,
`gd` shows sizes, dates and permissions, `ga` jumps to home, projects,
nixos-config or `~/.config`. `nvim .`, `:e dir`, `:Ex` and `<leader>pv` all
open it. The snacks explorer (`<leader>e`) is still there as a sidebar.

## Dashboard cat and the kitten

The dashboard is kittymax's cat: generated to fit the window, catppuccin
colours shimmering down its outline, blinking, twitching an ear and
wiggling its whiskers. The timer only runs while the dashboard is on screen
and stops after five minutes.

Saving a file has a kitten in the bottom right give you a paw (about a
second, then `=^.^= saved file` stays in the message area). Any key sends
it away; it only shows for the buffer you're in, never in a macro.
`<leader>uk` turns it off, `:KittenPaw` asks for one.

## Git and AI

gitsigns in the gutter with hunk actions on `<leader>h`; `<leader>g` for
status, log, diff, branches (snacks pickers), and `<leader>gg` for neogit,
set up like kittymax's magit: it takes the window you're in, saves the
repository's modified files first, highlights word-level changes, shows
diffs and commits in a split beside it and uses diffview for diffs.
`<leader>gh` walks the current file's history (diffview, kittymax's
git-timemachine), `<leader>gH` the repository's. Commit messages mark column
72 and are spell checked. `<leader>a` is Claude Code (claudecode.nvim):
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
