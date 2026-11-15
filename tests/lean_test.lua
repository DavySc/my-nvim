-- Lean 4 through the real config, lean.nvim and a real Lean server. Needs
-- `lean` and `lake` on PATH (elan, or a release unpacked by hand); skips
-- itself without them. Run by tests/run.sh, or on its own the same way:
--   nvim --headless -c 'luafile tests/lean_test.lua'
-- Set LEAN_TEST_NET=1 to also ask Loogle (network).

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
    failures[#failures + 1] = name .. (detail and (": " .. vim.inspect(detail)) or "")
  end
end

local function finish()
  for _, msg in ipairs(errors) do failures[#failures + 1] = "error notified: " .. msg end
  io.stdout:write(("lean: %d passed, %d failed\n"):format(passed, #failures))
  for _, f in ipairs(failures) do io.stdout:write("  FAIL " .. f .. "\n") end
  vim.cmd(#failures == 0 and "qa!" or "cquit!")
end

if vim.fn.executable("lean") == 0 or vim.fn.executable("lake") == 0 then
  io.stdout:write("lean: skipped (no lean / lake on PATH; install elan)\n")
  return vim.cmd("qa!")
end
if not require("config.machine").langs.lean then
  io.stdout:write("lean: skipped (off in lua/local.lua)\n")
  return vim.cmd("qa!")
end

local function run()
  local lazy = require("config.lazy")
  local lean = require("config.lean")

  -- The Lake parser, on output copied from `lake build` (Lean 4.35).
  local items = lean.parse({
    "✔ [2/10] Built Demo.Basic (177ms)",
    "✖ [3/10] Building Demo.Bad (185ms)",
    "trace: .> LEAN_PATH=... lean Demo/Bad.lean -o ...",
    "error: Demo/Bad.lean:1:15: Type mismatch",
    '  "s"',
    "has type",
    "  String",
    "warning: Demo/Bad.lean:6:8: declaration uses `sorry`",
    "error: Demo/Bad.lean:3:41: unsolved goals",
    "a b : Nat",
    "⊢ a + b = b + a",
    "⚠ [4/10] Built Demo.Other (20ms)",
    "Some required targets logged failures:",
    "- Demo.Bad",
    "error: build failed",
  }, "/p")
  check("parse: three messages", #items == 3, items)
  check("parse: absolute path, 1-based column", items[1] and items[1].filename == "/p/Demo/Bad.lean" and items[1].lnum == 1 and items[1].col == 16, items[1])
  check("parse: multi-line message kept whole", items[1] and items[1].text == 'Type mismatch\n  "s"\nhas type\n  String', items[1] and items[1].text)
  check("parse: warning", items[2] and items[2].type == "W" and items[2].lnum == 6)
  check("parse: goal text, stops at Lake's own lines", items[3] and items[3].text == "unsolved goals\na b : Nat\n⊢ a + b = b + a", items[3] and items[3].text)

  check(":LeanNew defined before any Lean file", vim.fn.exists(":LeanNew") == 2)
  check("lean.nvim not loaded at startup", not lazy.is_loaded("lean.nvim"))

  -- A small Lake project: a library with an error and an unfinished proof,
  -- and an executable.
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/Demo", "p")
  local function write(path, lines) vim.fn.writefile(lines, root .. "/" .. path) end
  write("lakefile.toml", {
    'name = "demo"', 'defaultTargets = ["demo"]', "", "[[lean_lib]]", 'name = "Demo"', "",
    "[[lean_exe]]", 'name = "demo"', 'root = "Main"',
  })
  write("Demo.lean", { "import Demo.Bad" })
  write("Demo/Bad.lean", {
    'def x : Nat := "s"',
    "",
    "theorem t (a b : Nat) : a + b = b + a := by",
    "  skip",
  })
  write("Main.lean", { 'def main : IO Unit := IO.println "hello from lean"' })

  vim.cmd.edit(root .. "/Demo/Bad.lean")
  local buf = vim.api.nvim_get_current_buf()
  check("filetype lean", vim.bo.filetype == "lean", vim.bo.filetype)
  check("lean.nvim loaded with the first Lean file", lazy.is_loaded("lean.nvim"))
  check("leanls enabled", vim.lsp.is_enabled("leanls"))
  check("lean.nvim's syntax file", vim.b.current_syntax == "lean", vim.b.current_syntax)
  check("lean.nvim's ftplugin ran (2-space indent)", vim.bo.shiftwidth == 2, vim.bo.shiftwidth)
  check("lean.nvim's keys are on (\\i infoview)", vim.fn.maparg("<LocalLeader>i", "n") ~= "")
  check("<leader>mm builds", vim.fn.maparg("<leader>mm", "n", false, true).buffer == 1)
  check("<localleader>u picks symbols", vim.fn.maparg("<localleader>u", "n", false, true).buffer == 1)
  check(":Lake in Lean buffers", vim.fn.exists(":Lake") == 2)

  local attached = vim.wait(60000, function()
    return #vim.lsp.get_clients({ bufnr = buf, name = "leanls" }) > 0
  end, 100)
  check("leanls attaches", attached)
  check("leanls runs lake serve in the project", attached and vim.lsp.get_clients({ bufnr = buf, name = "leanls" })[1].root_dir == vim.fs.normalize(vim.uv.fs_realpath(root) or root))

  local diags = {}
  vim.wait(120000, function()
    diags = vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })
    return #diags >= 2
  end, 200)
  check("server reports the type error and the unsolved goal", #diags >= 2, vim.tbl_map(function(d) return d.message end, diags))

  -- K must still be lean.nvim's after the server attached (core/lsp.lua maps
  -- K to plain hover in other buffers).
  check("K is lean.nvim's interactive hover", vim.fn.maparg("K", "n", false, true).rhs == "<Plug>(LeanHover)", vim.fn.maparg("K", "n", false, true).rhs)

  -- Infoview: the goal at the cursor.
  vim.api.nvim_win_set_cursor(0, { 4, 2 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
  local iv = require("lean.infoview").get_current_infoview()
  check("infoview opened on its own", iv ~= nil)
  local text = ""
  vim.wait(30000, function()
    if not iv then return true end
    text = table.concat(iv:get_lines(), "\n")
    return text:find("⊢ a + b = b + a", 1, true) ~= nil
  end, 200)
  check("infoview shows the goal", text:find("⊢ a + b = b + a", 1, true) ~= nil, text)

  -- Unicode input: \a then a space → α; \N then <Tab> (cmp has <Tab> too) → ℕ.
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  -- One feedkeys per abbreviation: a space converts on the next tick, which
  -- typed keys get between them but one feedkeys() string does not.
  local function typed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "tx", false)
    vim.wait(200, function() return false end)
  end
  typed("o-- \\a x<Esc>")
  typed("A \\N\t y<Esc>")
  local line = vim.api.nvim_buf_get_lines(buf, 4, 5, false)[1]
  check("abbreviations expand (space and <Tab>)", vim.trim(line) == "-- α x ℕ y", line)
  vim.cmd("silent! undo")

  check("lean snippets in LuaSnip", #require("luasnip").get_snippets("lean") > 0)

  local dirs = lean.library_dirs()
  check("library dirs include core Lean's sources", vim.iter(dirs):any(function(d) return d:find("src/lean$") ~= nil end), dirs)

  check("unicode picker opens", pcall(lean.pick_unicode))
  local pickers = Snacks.picker.get()
  check("a picker is open", #pickers > 0)
  for _, p in ipairs(pickers) do p:close() end

  -- lake build → quickfix.
  vim.fn.setqflist({}, " ", { title = "none" })
  lean.build({ "Demo" })
  vim.wait(120000, function() return vim.fn.getqflist({ title = 1 }).title:find("^lake build") ~= nil end, 200)
  local qf = vim.fn.getqflist()
  check("lake build: two errors in the quickfix list", #qf == 2, vim.tbl_map(function(i) return i.text end, qf))
  check("lake build: entries point into the file",
    qf[1] and vim.api.nvim_buf_get_name(qf[1].bufnr) == vim.api.nvim_buf_get_name(buf) and qf[1].lnum == 1, qf[1])
  vim.cmd("cclose")

  -- Run Main.lean's main in a terminal.
  vim.cmd.edit(root .. "/Main.lean")
  lean.run_file()
  local term = vim.api.nvim_get_current_buf()
  local out = ""
  vim.wait(60000, function()
    out = table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), "\n")
    return out:find("hello from lean", 1, true) ~= nil
  end, 200)
  check("run_file runs main", out:find("hello from lean", 1, true) ~= nil, out)

  -- Loogle: the answer canned in the API's format (LEAN_TEST_NET=1 asks the
  -- real site instead).
  local system = vim.system
  if vim.env.LEAN_TEST_NET ~= "1" then
    vim.system = function(cmd, opts, on_exit)
      assert(cmd[1] == "curl" and cmd[#cmd]:find("^https://loogle%.lean%-lang%.org/json%?q=Nat%.add_comm$"), cmd[#cmd])
      on_exit({ code = 0, stderr = "", stdout = vim.json.encode({
        header = "Found 1 declaration",
        hits = { { name = "Nat.add_comm", type = "∀ (n m : ℕ), n + m = m + n", module = "Init.Data.Nat.Basic", doc = "Addition commutes." } },
      }) })
    end
  end
  vim.cmd("close") -- the run's terminal
  vim.cmd.enew()
  local picked
  local pick = Snacks.picker.pick
  Snacks.picker.pick = function(opts) picked = opts end
  lean.loogle("Nat.add_comm")
  vim.wait(30000, function() return picked ~= nil end, 100)
  Snacks.picker.pick, vim.system = pick, system
  local hit = picked and picked.items[1]
  check("loogle: hits become picker items", hit and hit.name == "Nat.add_comm", hit)
  check("loogle: preview shows import and type", hit and hit.preview.text:find("import Init", 1, true) and hit.preview.text:find("Nat.add_comm : ", 1, true), hit and hit.preview)
  if picked then
    local win = vim.api.nvim_get_current_win()
    picked.confirm({ close = function() end }, hit)
    check("loogle: <CR> puts the name", vim.api.nvim_get_current_line() == "Nat.add_comm" and vim.api.nvim_get_current_win() == win, vim.api.nvim_get_current_line())
  end
end

local ok, err = xpcall(run, debug.traceback)
if not ok then failures[#failures + 1] = "crashed: " .. err end
finish()
