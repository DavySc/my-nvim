-- Editing ergonomics (the 2026-11 review): options, keys that stay vim's own,
-- SQL statements as objects, offline SQL keywords, markdown lists and code
-- blocks, the Verilog and Soufflé loops, surround and align.
--   nvim --headless -c 'luafile tests/editing_test.lua'
-- Run through tests/run.sh (a throwaway XDG tree). The SQL statement checks
-- need a dbbliss.nvim with statements() (decision 80).

local failures, passed = {}, 0
local errors = {}
local notify = vim.notify
vim.notify = function(msg, level, ...)
  if level == vim.log.levels.ERROR then errors[#errors + 1] = msg end
  return notify(msg, level, ...)
end
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failures[#failures + 1] = name .. (detail ~= nil and (": " .. tostring(detail)) or "")
  end
end

local function run()
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local function open(file, lines)
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/" .. file))
  if lines then vim.api.nvim_buf_set_lines(0, 0, -1, false, lines) end
  return vim.api.nvim_get_current_buf()
end
local function keys(k) vim.api.nvim_feedkeys(vim.keycode(k), "tx", false) end
local function lines() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
local function global_map(lhs, mode)
  local m = vim.fn.maparg(lhs, mode, false, true)
  return m.lhs ~= nil and m.buffer ~= 1
end

-- ── Options and keys ────────────────────────────────────────────────────
check("expandtab", vim.o.expandtab and vim.o.shiftwidth == 4 and vim.o.softtabstop == 4)
check("smartcase search", vim.o.ignorecase and vim.o.smartcase)
check("persistent undo", vim.o.undofile)
check("live :s preview", vim.o.inccommand == "split")
check("block selections past line ends", vim.o.virtualedit == "block")
check("no global gd: vim's own outside LSP buffers", not global_map("gd", "n"))
check("no global gD", not global_map("gD", "n"))
check("no gr shadowing grr", not global_map("gr", "n"))
check("<C-k> stays digraphs", vim.fn.maparg("<C-k>", "i") == "")
check("Lua run key is <leader>X", global_map("<Space>X", "n") and not global_map("<Space>x", "n"))
check("no leader spider motions", not global_map("<Space>w", "n") and not global_map("<Space>b", "n"))
check("flash keeps s", vim.fn.maparg("s", "n", false, true).desc == "Flash")
for _, lhs in ipairs({ "<Space>fr", "<Space>uz", "<Space>uu" }) do
  check("mapped: " .. lhs, global_map(lhs, "n"))
end
local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/nvim-pack-lock.json"), "\n"))
for _, stale in ipairs({ "lean.nvim", "otter.nvim", "roslyn.nvim", "nvim-spider" }) do
  check("not in the lock file: " .. stale, lock.plugins[stale] == nil)
end

-- surround (vim-surround keys) and align
open("s.txt", { "name", "a = 1", "bbb = 22" })
keys("ggysiw]")
check("ysiw] wraps a T-SQL name", lines()[1] == "[name]", lines()[1])
keys("ggds]")
check("ds] unwraps it", lines()[1] == "name", lines()[1])
keys("ggysiw*")
check("ysiw* makes markdown bold", lines()[1] == "**name**", lines()[1])
keys("2Ggaj=")
check("gaj= aligns on =", lines()[2] == "a   = 1" and lines()[3] == "bbb = 22", vim.inspect(lines()))
check("visual y yanks at once (no ys map in visual)", vim.fn.maparg("ys", "x") == "")

-- ── SQL ─────────────────────────────────────────────────────────────────
local sqlbuf = open("q.sql", {
  "-- customers first",
  "select id, name",
  "from customers;",
  "",
  "select ';' as x",
  "from t;",
  "update t set a = 1;",
})
check("no <C-c> insert maps in SQL", #vim.tbl_filter(function(m) return m.lhs:find("^<C%-C>") end,
  vim.api.nvim_buf_get_keymap(0, "i")) == 0)
keys("gg0>>")
check(">> indents with spaces", lines()[1]:sub(1, 4) == "    ", vim.inspect(lines()[1]))
keys("<<")
check("formatexpr goes through conform", vim.bo.formatexpr:find("conform") ~= nil, vim.bo.formatexpr)
check("K is SQL's own", vim.fn.maparg("K", "n", false, true).buffer == 1)

local db_ok, db = pcall(require, "dbbliss")
local has_statements = db_ok and type(db.statements) == "function"
check("dbbliss with statements()", has_statements)
if has_statements then
  vim.api.nvim_win_set_cursor(0, { 2, 3 })
  keys('"ayiq')
  check("yiq: the statement without its ;", vim.fn.getreg("a") == "select id, name\nfrom customers", vim.fn.getreg("a"))
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  keys('"byaq')
  check("yaq: linewise, the comment above and the blank line after",
    vim.fn.getreg("b") == "-- customers first\nselect id, name\nfrom customers;\n\n", vim.inspect(vim.fn.getreg("b")))
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  keys("]]")
  check("]] to the next statement", vim.api.nvim_win_get_cursor(0)[1] == 5, vim.api.nvim_win_get_cursor(0)[1])
  keys("]]")
  check("a ; in a string is not a statement end", vim.api.nvim_win_get_cursor(0)[1] == 7, vim.api.nvim_win_get_cursor(0)[1])
  keys("2[[")
  check("2[[ back two", vim.api.nvim_win_get_cursor(0)[1] == 2, vim.api.nvim_win_get_cursor(0)[1])
  keys("d]]")
  check("d]] deletes up to the next statement", lines()[2] == "select ';' as x", vim.inspect(lines()))
  keys("u")

  -- Keywords with no connection, in the buffer's dialect.
  local got
  vim.api.nvim_buf_set_lines(sqlbuf, 0, -1, false, { "sel" })
  require("dbbliss.completion").for_buffer(sqlbuf, 1, 3, function(r) got = r end)
  local labels = got and vim.tbl_map(function(i) return i.label end, got.items) or {}
  check("offline keywords in SQL", vim.tbl_contains(labels, "select"), vim.inspect(labels))
  local tsql = open("q.tsql", { "select * from t cross ap" })
  require("dbbliss.completion").for_buffer(tsql, 1, #"select * from t cross ap", function(r) got = r end)
  labels = vim.tbl_map(function(i) return i.label end, got.items)
  check("T-SQL keywords in a .tsql buffer", vim.tbl_contains(labels, "apply"), vim.inspect(labels))
end

-- Snippets
require("config.core.completion").load()
require("luasnip.loaders.from_lua").load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
local trigs = {}
for _, sn in ipairs(require("luasnip").get_snippets("sql") or {}) do trigs[sn.trigger] = true end
for _, t in ipairs({ "cte", "txtest", "upsert", "proc", "fn", "dropif" }) do
  check("sql snippet " .. t, trigs[t])
end
trigs = {}
for _, sn in ipairs(require("luasnip").get_snippets("systemverilog") or {}) do trigs[sn.trigger] = true end
check("systemverilog snippets", trigs.aff and trigs.fsm and trigs.tb)

-- ── Markdown ────────────────────────────────────────────────────────────
local lists = require("config.markdown_lists")
check("next bullet", lists.next_marker("  - item") == "  - ")
check("next number", lists.next_marker("9. item") == "10. ")
check("new task unticked", lists.next_marker("- [x] done") == "- [ ] ")
check("not a list", lists.next_marker("text") == nil)
open("n.md", { "- one" })
check("spell on in markdown", vim.wo.spell)
check("heading folds", vim.g.markdown_folding == 1)
check("j is gj without a count", vim.fn.maparg("j", "n", false, true).buffer == 1)
keys("GA<CR>two<Esc>")
check("<CR> continues a list", vim.deep_equal(lines(), { "- one", "- two" }), vim.inspect(lines()))
keys("A<CR><CR>after<Esc>")
check("<CR> on an empty item ends the list", vim.deep_equal(lines(), { "- one", "- two", "after" }), vim.inspect(lines()))
keys("ggothree<Esc>")
check("o continues a list", lines()[2] == "- three", vim.inspect(lines()))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain" })
keys("A<CR>x<Esc>")
check("<CR> elsewhere is a new line", vim.deep_equal(lines(), { "plain", "x" }), vim.inspect(lines()))

-- Edit a code block in its own buffer and write it back.
local note = open("note.md", { "# Q", "", "```tsql", "select 1", "```", "after" })
vim.api.nvim_win_set_cursor(0, { 4, 0 })
require("config.edit_block").open()
local edit = vim.api.nvim_get_current_buf()
check("block opens as sql", vim.bo.filetype == "sql" and edit ~= note, vim.bo.filetype)
check("with the fence's dialect", vim.b.sql_dialect == "tsql" and require("lang.sql").dialect(edit) == "tsql")
vim.api.nvim_buf_set_lines(note, 0, 0, false, { "new first line" }) -- the note moves meanwhile
vim.api.nvim_buf_set_lines(edit, 0, -1, false, { "select 1", "union all", "select 2" })
vim.cmd("silent write")
check("written back between the fences", vim.deep_equal(vim.api.nvim_buf_get_lines(note, 0, -1, false),
  { "new first line", "# Q", "", "```tsql", "select 1", "union all", "select 2", "```", "after" }),
  vim.inspect(vim.api.nvim_buf_get_lines(note, 0, -1, false)))
vim.cmd("bwipeout!")

-- ── SystemVerilog and Soufflé ───────────────────────────────────────────
open("m.sv", { "module m;", "endmodule" })
check(":VerilogWave", vim.fn.exists(":VerilogWave") == 2)
check("<leader>mw", vim.fn.maparg("<Space>mw", "n", false, true).buffer == 1)
open("r.dl", { ".decl e(x:number)" })
check("souffle makeprg", vim.bo.makeprg:find("^souffle ") ~= nil, vim.bo.makeprg)
check(":SouffleRun", vim.fn.exists(":SouffleRun") == 2)
open("e.facts", { "1\t2" })
check(".facts keep their Tabs", vim.bo.filetype == "souffle_facts" and not vim.bo.expandtab, vim.bo.filetype)
end

local ok, err = xpcall(run, debug.traceback)
if not ok then failures[#failures + 1] = "crashed: " .. err end
for _, msg in ipairs(errors) do failures[#failures + 1] = "error notified: " .. msg end

local out = io.stdout
out:write(("editing: %d passed, %d failed\n"):format(passed, #failures))
for _, f in ipairs(failures) do out:write("  FAIL " .. f .. "\n") end
vim.cmd(#failures == 0 and "qa!" or "cquit!")
