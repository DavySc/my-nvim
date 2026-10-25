-- Haskell, including Clash (github.com/clash-lang/clash-compiler): Clash
-- designs are ordinary .hs files compiled through GHC, so everything below
-- also applies to them; <leader>mv/<leader>mV/<leader>mS add HDL codegen and
-- <leader>mc a clashi REPL on top of the normal Haskell workflow.
--
-- commentstring/comments/suffixesadd/include(expr) already come from Vim's
-- stock ftplugin/haskell.vim. This file adds indent folds, build/run/
-- test/REPL (stack or cabal, detected from what's above the buffer; a plain
-- file falls back to runghc/ghci), and Clash codegen.

-- `gf` on imports living under a different root than the current file
-- (includeexpr only searches upward from the buffer, not into siblings).
vim.opt_local.path:append({ "src", "app", "lib", "test" })

-- Indent folds, everything open. Not treesitter: tree-sitter-haskell corrupts
-- the heap and crashes nvim (see lua/lang/haskell.lua).
vim.opt_local.foldmethod = "indent"
vim.opt_local.foldlevel = 99

--- Nearest ancestor of `dir` (inclusive) containing something matching `name`.
---@param dir string
---@param name string|fun(name: string, path: string): boolean
---@return string?
local function find_up(dir, name)
  local found = vim.fs.find(name, { path = dir, upward = true, limit = 1 })[1]
  return found and vim.fs.dirname(found)
end

local buf_name = vim.api.nvim_buf_get_name(0)
local start_dir = buf_name ~= "" and vim.fs.dirname(buf_name) or (vim.uv.cwd() or ".")

local stack_root = find_up(start_dir, "stack.yaml")
local cabal_root = not stack_root
  and (find_up(start_dir, "cabal.project") or find_up(start_dir, function(name) return name:match("%.cabal$") ~= nil end))

local build_tool = stack_root and "stack" or (cabal_root and "cabal" or nil)
local project_root = stack_root or cabal_root

local BUILD = { stack = { "stack", "build" }, cabal = { "cabal", "build" } }
local RUN = { stack = { "stack", "run" }, cabal = { "cabal", "run" } }
local TEST = { stack = { "stack", "test" }, cabal = { "cabal", "test" } }
local REPL = { stack = { "stack", "ghci" }, cabal = { "cabal", "repl" } }

-- In a flake project, run every tool through `nix develop` so it uses the
-- flake's ghc/cabal/clash (nvim usually isn't started from the dev shell).
-- Skipped when already inside one.
local flake_root = not vim.env.IN_NIX_SHELL and find_up(start_dir, "flake.nix") or nil

---@param cmd string[]
---@return string[]
local function wrap(cmd)
  if not flake_root then
    return cmd
  end
  return vim.list_extend({ "nix", "develop", flake_root, "--command" }, cmd)
end

-- `:make` builds the project so <leader>mm has something to attach to; a
-- plain file has no project target, build() below just explains why not.
if build_tool then
  vim.bo.makeprg = table.concat(vim.tbl_map(vim.fn.shellescape, wrap(BUILD[build_tool])), " ")
end

--- Open `cmd` in a terminal split (Snacks owns terminal windows in this config).
---@param cmd string[]
---@param cwd string
local function term(cmd, cwd)
  Snacks.terminal.open(wrap(cmd), { cwd = cwd, win = { position = "bottom", height = 0.35 } })
end

local function build()
  if build_tool then
    vim.cmd.make()
  else
    vim.notify(
      "haskell: no stack.yaml/*.cabal above this buffer; nothing to build (<leader>mr runs it with runghc)",
      vim.log.levels.WARN
    )
  end
end

local function run()
  if build_tool then
    return term(RUN[build_tool], project_root)
  end
  if buf_name == "" then
    return vim.notify("haskell: buffer is not backed by a file", vim.log.levels.ERROR)
  end
  if vim.bo.modified then
    vim.cmd.write()
  end
  term({ "runghc", buf_name }, vim.fs.dirname(buf_name))
end

local function test()
  if not build_tool then
    return vim.notify("haskell: no stack.yaml/*.cabal above this buffer", vim.log.levels.WARN)
  end
  term(TEST[build_tool], project_root)
end

local function repl()
  if build_tool then
    return term(REPL[build_tool], project_root)
  end
  term(buf_name ~= "" and { "ghci", buf_name } or { "ghci" }, buf_name ~= "" and vim.fs.dirname(buf_name) or start_dir)
end

-- ── Clash HDL codegen ────────────────────────────────────────────────────
-- `clash`/`clashi` come from `cabal install clash-ghc` (or `stack install
-- clash-ghc`) and end up on PATH like any other compiler. Override the
-- command if a project wires clash up differently (e.g. a cabal/stack shim).
local clash_cmd = vim.g.clash_cmd or { "clash" }
local clashi_cmd = vim.g.clashi_cmd or { "clashi" }

--- Compile the current buffer to `hdl`, writing under Clash's own default
--- output directory (./<hdl>/) relative to the project root.
---@param hdl "vhdl"|"verilog"|"systemverilog"
local function clash_compile(hdl)
  if not flake_root and vim.fn.executable(clash_cmd[1]) == 0 then
    return vim.notify(
      "clash: '" .. clash_cmd[1] .. "' not found (cabal install clash-ghc, or set vim.g.clash_cmd)",
      vim.log.levels.ERROR
    )
  end
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("clash: buffer is not backed by a file", vim.log.levels.ERROR)
  end
  if vim.bo.modified then
    vim.cmd.write()
  end

  local cwd = project_root or vim.fs.dirname(file)
  local cmd = wrap(vim.list_extend(vim.deepcopy(clash_cmd), { "--" .. hdl, file }))
  vim.notify("clash: compiling to " .. hdl .. "...")
  vim.system(cmd, { text = true, cwd = cwd }, vim.schedule_wrap(function(res)
    local out = vim.split((res.stdout or "") .. (res.stderr or ""), "\n", { trimempty = true })
    local items = vim.tbl_filter(
      function(item) return item.valid == 1 end,
      vim.fn.getqflist({ lines = out, efm = vim.o.errorformat }).items
    )
    vim.fn.setqflist({}, " ", { title = table.concat(cmd, " "), items = items })
    if res.code ~= 0 then
      if #items > 0 then
        vim.cmd("botright copen")
      end
      return vim.notify("clash: " .. hdl .. " codegen failed", vim.log.levels.ERROR)
    end
    vim.cmd("cclose")
    vim.notify("clash: wrote ./" .. hdl .. "/ under " .. cwd)
  end))
end

local function clashi()
  if not flake_root and vim.fn.executable(clashi_cmd[1]) == 0 then
    return vim.notify(
      "clash: '" .. clashi_cmd[1] .. "' not found (cabal install clash-ghc, or set vim.g.clashi_cmd)",
      vim.log.levels.ERROR
    )
  end
  term(clashi_cmd, project_root or (buf_name ~= "" and vim.fs.dirname(buf_name) or start_dir))
end

-- ── Keymaps ──────────────────────────────────────────────────────────────
local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = 0, silent = true, desc = desc })
end

map("<leader>mm", build, "Haskell: build")
map("<leader>mr", run, "Haskell: run")
map("<leader>mt", test, "Haskell: test")
map("<leader>mi", repl, "Haskell: REPL")
map("<leader>mv", function() clash_compile("vhdl") end, "Clash: -> VHDL")
map("<leader>mV", function() clash_compile("verilog") end, "Clash: -> Verilog")
map("<leader>mS", function() clash_compile("systemverilog") end, "Clash: -> SystemVerilog")
map("<leader>mc", clashi, "Clash: clashi REPL")

vim.b.undo_ftplugin = table.concat({
  "setlocal path< foldmethod< foldlevel< makeprg<",
  "silent! nunmap <buffer> <leader>mm",
  "silent! nunmap <buffer> <leader>mr",
  "silent! nunmap <buffer> <leader>mt",
  "silent! nunmap <buffer> <leader>mi",
  "silent! nunmap <buffer> <leader>mv",
  "silent! nunmap <buffer> <leader>mV",
  "silent! nunmap <buffer> <leader>mS",
  "silent! nunmap <buffer> <leader>mc",
}, " | ")
