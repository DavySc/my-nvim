-- The things ported from kittymax: the dashboard cat, the kitten on save,
-- oil as the file manager, and org with pretty LaTeX.
--   nvim --headless -c 'luafile tests/features_test.lua'
-- Run through tests/run.sh (a throwaway XDG tree). Opening an org file builds
-- orgmode's grammar the first time (git and a C compiler).

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
    failures[#failures + 1] = name .. (detail and (": " .. tostring(detail)) or "")
  end
end

local function run()
local lazy = require("config.lazy")
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")

-- Startup leaves the new plugins alone.
for _, name in ipairs({ "oil.nvim", "orgmode", "org-bullets.nvim" }) do
  check("not loaded at startup: " .. name, not lazy.is_loaded(name))
end

-- ── The dashboard cat ───────────────────────────────────────────────────
local splash = require("config.core.splash")

-- The smallest cat, exactly as kittymax's kitty-splash.el draws it.
local golden = {
  "     /\\   /\\     ",
  "    /  \\ /  \\    ",
  "   /    /    \\   ",
  "    /_______\\    ",
  "   / .-. .-. \\   ",
  "   ( |o| |o| )   ",
  "   ( '-' '-' )   ",
  "   \\ ===v=== /   ",
  "    \\ ==|== /    ",
  "    \\__/ \\__/    ",
  "                 ",
}
check("cat rx=5 matches kittymax", vim.deep_equal(splash.lines(5), golden), table.concat(splash.lines(5), "|"))

local mirror = { ["/"] = "\\", ["\\"] = "/", ["("] = ")", [")"] = "(" }
for _, rx in ipairs({ 5, 7, 11, 17, 24 }) do
  local lines = splash.lines(rx)
  check(("cat rx=%d has %d rows"):format(rx, splash.rows(rx)), #lines == splash.rows(rx), #lines)
  local width_ok, symmetric = true, true
  for _, l in ipairs(lines) do
    if vim.api.nvim_strwidth(l) ~= splash.cols(rx) then width_ok = false end
    -- Left half mirrored is the right half (the mouth and nose aside).
    local cells = vim.fn.split(l, "\\zs")
    for x = 1, math.floor(#cells / 2) do
      local a, b = cells[x], cells[#cells - x + 1]
      if a ~= (mirror[b] or b) and not (a .. b):find("[_v|]") then symmetric = false end
    end
  end
  check(("cat rx=%d rows are %d wide"):format(rx, splash.cols(rx)), width_ok)
  check(("cat rx=%d is symmetric"):format(rx), symmetric)
end
check("blinking closes the eyes", table.concat(splash.lines(11, true), "\n"):find("|o|") == nil)
check("a twitch moves an ear", not vim.deep_equal(splash.lines(11), splash.lines(11, false, true)))
check("whiskers can wiggle", table.concat(splash.lines(11, false, false, "~"), "\n"):find("~~~") ~= nil)
check("the biggest cat that fits", splash.pick(200, 80, 18) == 24, splash.pick(200, 80, 18))
check("no cat in a tiny window", splash.pick(20, 10, 18) == nil)

local function text(chunks)
  local s = ""
  for _, c in ipairs(chunks) do s = s .. c[1] end
  return s
end
check("frames differ as the cat animates", text(splash.texts(0, 120, 60, 18)) ~= text(splash.texts(11, 120, 60, 18)))
local function hls(chunks)
  return table.concat(vim.tbl_map(function(c) return c.hl or "-" end, chunks), ",")
end
check("colours shimmer frame to frame", hls(splash.texts(0, 120, 60, 18)) ~= hls(splash.texts(2, 120, 60, 18)))

vim.o.columns, vim.o.lines = 120, 60
local ok = pcall(function() Snacks.dashboard.open() end)
check("dashboard opens", ok)
local dash = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
check("dashboard shows the cat", dash:find("|o|", 1, true) ~= nil and dash:find("n e o v i m", 1, true) ~= nil)
check("no animation without a UI", not splash.running())
vim.cmd("enew")

-- ── The kitten on save ──────────────────────────────────────────────────
local kitten = require("config.core.kitten")
local frames = kitten.frames("notes.org")
check("kitten has six frames", #frames == 6, #frames)
local last = table.concat(vim.tbl_map(function(l) return text(l) end, frames[#frames][1]), "\n")
check("the paw, the heart, the name", last:find("__o", 1, true) and last:find("<3", 1, true) and last:find("saved notes.org", 1, true))
check("summary line", text(kitten.summary("notes.org")) == "=^.^= saved notes.org")

-- Pretend a UI is attached: should_play() wants one.
local list_uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function() return { {} } end
local file = dir .. "/k.txt"
vim.cmd.edit(file)
local buf = vim.api.nvim_get_current_buf()
check("plays for the buffer in front of you", kitten.should_play(buf))
check("not for another buffer", not kitten.should_play(vim.api.nvim_create_buf(true, false)))
vim.g.kitten_on_save = false
check("not when turned off", not kitten.should_play(buf))
vim.g.kitten_on_save = nil
local scratch = vim.api.nvim_create_buf(false, true)
check("not in special buffers", not kitten.should_play(scratch))

kitten.frame_ms, kitten.hold_ms = 10, 30
local echoed
local echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks, ...)
  echoed = text(chunks)
  return echo(chunks, ...)
end
local function floats()
  return #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= "" end, vim.api.nvim_list_wins())
end
local before = floats()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "meow" })
vim.cmd.write()
check("saving shows the kitten", kitten.playing())
check("not twice for one save", not kitten.should_play(buf))
check("in a float", floats() == before + 1, floats() - before)
vim.wait(2000, function() return not kitten.playing() end, 10)
check("it ends by itself", not kitten.playing())
check("and leaves a summary", echoed == "=^.^= saved k.txt", echoed)
check("the float is gone", floats() == before, floats() - before)

kitten.frame_ms, kitten.hold_ms = 1000, 1000
kitten.paw()
vim.api.nvim_feedkeys("l", "x", false)
vim.wait(200, function() return not kitten.playing() end, 10)
check("any key sends it away", not kitten.playing())
vim.api.nvim_echo = echo
vim.api.nvim_list_uis = list_uis
check(":KittenPaw exists", vim.fn.exists(":KittenPaw") == 2)

-- ── oil ─────────────────────────────────────────────────────────────────
check("netrw stays off", vim.g.loaded_netrwPlugin == 1)
check("- opens the parent directory", vim.fn.maparg("-", "n") ~= "")
check(":Ex opens oil", vim.fn.exists(":Ex") == 2)
local tree = dir .. "/tree"
vim.fn.mkdir(tree .. "/sub", "p")
vim.fn.writefile({}, tree .. "/a.lua")
vim.fn.writefile({}, tree .. "/.hidden")
vim.cmd.edit(tree)
check("a directory loads oil", lazy.is_loaded("oil.nvim"))
vim.wait(3000, function() return vim.bo.filetype == "oil" and vim.api.nvim_buf_line_count(0) > 1 end, 20)
check("and oil lists it", vim.bo.filetype == "oil", vim.bo.filetype)
local listing = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
check("with directories and hidden files", listing:find("sub/", 1, true) and listing:find(".hidden", 1, true), listing)

-- ── git: neogit as magit ────────────────────────────────────────────────
check("lazygit is gone", vim.fn.maparg("<leader>gG", "n") == "")
check("<leader>gh: file history", vim.fn.maparg("<leader>gh", "n"):find("DiffviewFileHistory", 1, true) ~= nil)
local repo = dir .. "/repo"
vim.fn.mkdir(repo, "p")
vim.fn.system({ "git", "-C", repo, "init", "-q" })
vim.fn.writefile({ "one" }, repo .. "/in.txt")
vim.fn.writefile({ "one" }, dir .. "/out.txt")
vim.cmd.edit(dir .. "/out.txt")
local outside = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(outside, 0, -1, false, { "changed" })
vim.cmd.edit(repo .. "/in.txt")
local inside = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(inside, 0, -1, false, { "changed" })
local okstatus, errstatus = pcall(require("config.core.git").status)
check("<leader>gg opens neogit", okstatus and lazy.is_loaded("neogit"), errstatus)
check("it saves the repository's files first", not vim.bo[inside].modified)
check("and leaves other files alone", vim.bo[outside].modified)
local nconf = require("neogit.config").values
check("neogit takes the current window", nconf.kind == "replace", nconf.kind)
check("neogit uses diffview", nconf.integrations.diffview == true)
pcall(vim.cmd, "DiffviewFileHistory")
check("diffview loads on its commands", lazy.is_loaded("diffview.nvim"))
pcall(vim.cmd, "tabonly")
vim.api.nvim_buf_set_lines(outside, 0, -1, false, { "one" })
vim.bo[outside].modified = false
vim.cmd("silent! %bwipeout!")

-- ── org ─────────────────────────────────────────────────────────────────
local pretty = require("config.org_pretty")
local function render(line)
  local ms = pretty.matches(line)
  table.sort(ms, function(a, b) return a[1] < b[1] end)
  local out, pos = {}, 0
  for _, m in ipairs(ms) do
    out[#out + 1] = line:sub(pos + 1, m[1]) .. m[3]
    pos = m[2]
  end
  return table.concat(out) .. line:sub(pos + 1)
end
for line, want in pairs({
  ["\\alpha \\to \\beta"] = "α → β",
  ["\\Gamma{}x"] = "Γx",
  ["E = mc^{2}, a_{ij}, f^{-1}"] = "E = mc², aᵢⱼ, f⁻¹",
  ["y^{q} z_{b}"] = "y^{q} z_{b}", -- no Unicode form: left as typed
  ["\\alphabet \\unknown x^2 ^{2}"] = "\\alphabet \\unknown x^2 ^{2}",
  ["=\\alpha= ~a_{1}~ \\alpha"] = "=\\alpha= ~a_{1}~ α",
  ["\\sum_{i=0}^{n} \\leq \\in"] = "∑ᵢ₌₀ⁿ ≤ ∈",
}) do
  check("pretty: " .. line, render(line) == want, render(line))
end
local skip = pretty.skipped_rows({ "a", "#+BEGIN_SRC lua", "x", "#+end_src", ": fixed", "b" })
check("src blocks and fixed-width lines are left alone",
  vim.deep_equal(skip, { [1] = true, [2] = true, [3] = true, [4] = true }), vim.inspect(skip))

check("<leader>oa before orgmode loads", vim.fn.maparg("<leader>oa", "n") ~= "")
local org = dir .. "/notes.org"
vim.fn.writefile({
  "* Notes",
  "Energy: E = mc^{2}, \\alpha \\to \\beta.",
  "Inline math: \\(\\int_0^1 f(x)\\,dx\\) and $a^2 + b^2 = c^2$",
}, org)
vim.cmd.edit(org)
check("org filetype", vim.bo.filetype == "org", vim.bo.filetype)
check("orgmode loaded with org", lazy.is_loaded("orgmode"))
check("org-bullets loaded with org", lazy.is_loaded("org-bullets.nvim"))
check("pretty symbols attached", pretty.attached(vim.api.nvim_get_current_buf()))
check("conceal on, revealed under the cursor", vim.wo.conceallevel == 2 and vim.wo.concealcursor == "")
-- orgmode builds its grammar on first use.
vim.wait(120000, function() return pcall(vim.treesitter.language.inspect, "org") end, 200)
local found = {}
local okq, err = pcall(function()
  local q = vim.treesitter.query.get("org", "images")
  local tree = vim.treesitter.get_parser(0, "org"):parse()[1]
  for id, node in q:iter_captures(tree:root(), 0) do
    if q.captures[id] == "image.content" then found[#found + 1] = vim.treesitter.get_node_text(node, 0) end
  end
end)
check("snacks.image finds the math to render", okq and #found == 2, okq and vim.inspect(found) or err)
check("snacks.image is enabled", Snacks.image.config.enabled == true)

end

local ok, err = xpcall(run, debug.traceback)
if not ok then failures[#failures + 1] = "crashed: " .. err end
for _, msg in ipairs(errors) do failures[#failures + 1] = "error notified: " .. msg end

local out = io.stdout
out:write(("features: %d passed, %d failed\n"):format(passed, #failures))
for _, f in ipairs(failures) do out:write("  FAIL " .. f .. "\n") end
vim.cmd(#failures == 0 and "qa!" or "cquit!")
