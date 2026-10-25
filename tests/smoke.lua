-- Smoke test for this config: loads it the normal way, opens one file per
-- language and pokes each lazy trigger, then exits non-zero on any failure.
--
--   nvim --headless -c 'luafile tests/smoke.lua'
--
-- Point XDG_CONFIG_HOME at a directory holding a `nvim` symlink to this repo
-- (and XDG_DATA_HOME somewhere disposable) to run it without touching your
-- own setup. It checks wiring only: servers aren't required to be installed.

local failures, passed = {}, 0
local errors = {}

-- Errors reported through vim.notify count as failures too.
local notify = vim.notify
vim.notify = function(msg, level, ...)
  if level == vim.log.levels.ERROR then errors[#errors + 1] = msg end
  return notify(msg, level, ...)
end

local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failures[#failures + 1] = name .. (detail and (": " .. detail) or "")
  end
end

local function run()
local lazy = require("config.lazy")
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")

local function open(file)
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/" .. file))
  return vim.api.nvim_get_current_buf()
end

-- The dashboard renders (it opens on UIEnter, which headless never fires).
-- Its default "startup" section needs lazy.nvim, which isn't here (PR-1).
check("dashboard opens", pcall(function() Snacks.dashboard.open() end))
vim.cmd("enew")

check("<C-n> multicursor key only on 0.13+",
  (vim.fn.maparg("<C-n>", "n") ~= "") == (vim.fn.has("nvim-0.13") == 1))

-- Startup leaves the heavy plugins alone.
for _, name in ipairs({ "nvim-cmp", "neogit", "nvim-dap", "claudecode.nvim", "conform.nvim", "trouble.nvim" }) do
  check("not loaded at startup: " .. name, not lazy.is_loaded(name))
end

---@param file string
---@param ft string
---@param servers string[]
local function lang(file, ft, servers)
  open(file)
  check(file .. " filetype", vim.bo.filetype == ft, vim.bo.filetype)
  for _, server in ipairs(servers) do
    check(file .. " enables " .. server, vim.lsp.is_enabled(server))
  end
end

local machine = require("config.machine")
local cases = {
  lua = { "a.lua", "lua", { "lua_ls" } },
  c = { "a.c", "c", { "clangd" } },
  rust = { "a.rs", "rust", { "rust_analyzer" } },
  haskell = { "a.hs", "haskell", { "hls" } },
  nix = { "a.nix", "nix", { "nil_ls" } },
  souffle = { "a.dl", "souffle", {} },
  sql = { "a.sql", "sql", { "postgres_lsp" } },
  csharp = { "a.cs", "cs", { "roslyn" } },
  verilog = { "a.sv", "systemverilog", { "verible" } },
  racket = { "a.rkt", "racket", { "racket_langserver" } },
  org = { "a.org", "org", {} },
}
for name, case in pairs(cases) do
  if machine.langs[name] then lang(unpack(case)) end
end

if machine.langs.c then
  check("clangd_extensions loaded with C", lazy.is_loaded("clangd_extensions.nvim"))
  check(":CMake defined with C", vim.fn.exists(":CMake") == 2)
end
if machine.langs.racket then
  open("b.rkt")
  check(":Racket defined with Racket", vim.fn.exists(":Racket") == 2)
  check("<leader>mr runs Racket files", vim.fn.maparg("<leader>mr", "n", false, true).buffer == 1)
end
if machine.langs.sql then
  check("dbbliss loaded with SQL", lazy.is_loaded("dbbliss.nvim"))
  check(":Dbbliss defined", vim.fn.exists(":Dbbliss") == 2)
  local sql = require("lang.sql")
  open("b.tsql")
  check(".tsql is sql", vim.bo.filetype == "sql", vim.bo.filetype)
  check(".tsql dialect", sql.dialect(0) == "tsql")
  open("c.pgsql")
  check(".pgsql dialect", sql.dialect(0) == "postgres")
  open("d.sql")
  vim.b.sql_dialect = "tsql"
  check("b:sql_dialect wins over the default", sql.dialect(0) == "tsql")
end
if machine.langs.verilog then
  open("b.v")
  check(".v is verilog", vim.bo.filetype == "verilog", vim.bo.filetype)
  check("verilog uses the systemverilog grammar", vim.treesitter.language.get_lang("verilog") == "systemverilog")
end
if machine.langs.org then
  open("b.org")
  check("orgmode loaded with org", lazy.is_loaded("orgmode"))
  check("<leader>obe runs blocks in org buffers", vim.fn.maparg("<leader>obe", "n", false, true).buffer == 1)
  -- orgmode's own <leader>oe (export) must not be shadowed.
  check("<leader>oe is still orgmode's export", (vim.fn.maparg("<leader>oe", "n", false, true).desc or ""):find("export") ~= nil,
    vim.fn.maparg("<leader>oe", "n", false, true).desc)
end
if machine.langs.csharp then
  check("roslyn.nvim loaded with C#", lazy.is_loaded("roslyn.nvim"))
end
check("completion loaded with the first server", lazy.is_loaded("nvim-cmp"))
check("cmp sources registered", pcall(function()
  local names = vim.tbl_map(function(s) return s.name end, require("cmp").core:get_sources())
  assert(vim.tbl_contains(names, "buffer"), table.concat(names, ","))
end))

-- First save loads conform.
open("b.txt")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello" })
vim.cmd.write()
check("conform loaded on save", lazy.is_loaded("conform.nvim"))

-- require() of a lazy plugin's module loads it, once.
local dap = require("dap")
check("dap loads via require", lazy.is_loaded("nvim-dap"))
check("dap module is a single instance", require("dap") == dap)
if machine.langs.c then
  check("dap C++ configurations applied", dap.configurations.cpp ~= nil and #dap.configurations.cpp == 3)
end
check("dap-ui requireable", pcall(require, "dapui"))

-- Commands load their plugins through CmdUndefined.
for cmd, plugin in pairs({
  ["Trouble diagnostics toggle"] = "trouble.nvim",
  ["ClaudeCodeStatus"] = "claudecode.nvim",
  ["NeogitResetState"] = "neogit",
}) do
  pcall(vim.cmd, cmd)
  check(":" .. cmd .. " loads " .. plugin, lazy.is_loaded(plugin))
end

end

local ok, err = xpcall(run, debug.traceback)
if not ok then failures[#failures + 1] = "crashed: " .. err end

for _, msg in ipairs(errors) do failures[#failures + 1] = "error notified: " .. msg end

local out = io.stdout
out:write(("smoke: %d passed, %d failed\n"):format(passed, #failures))
for _, f in ipairs(failures) do out:write("  FAIL " .. f .. "\n") end
vim.cmd(#failures == 0 and "qa!" or "cquit!")
