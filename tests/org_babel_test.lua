-- Tests for lua/config/org_babel.lua; needs no plugins.
--   nvim --headless --clean --cmd 'set rtp^=.' -l tests/org_babel_test.lua
-- Languages whose toolchain isn't on PATH are skipped, and say so.

local babel = require("config.org_babel")
local failures, passed, skipped = {}, 0, {}

local function eq(name, got, want)
  if vim.deep_equal(got, want) then
    passed = passed + 1
  else
    failures[#failures + 1] = ("%s\n    got:  %s\n    want: %s"):format(name, vim.inspect(got), vim.inspect(want))
  end
end

local function buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(buf)
  return buf
end

local function lines(buf) return vim.api.nvim_buf_get_lines(buf, 0, -1, false) end

eq("parse_args", babel.parse_args(' :var a=1 :var b="x y" :dir C:\\work dir :results silent'), {
  var = { "a=1", "b=\"x y\"" },
  dir = "C:\\work dir",
  results = "silent",
})

-- block_at: inside, on the markers, and outside.
local doc = {
  "* Heading",
  "#+BEGIN_SRC python :var n=2",
  "print(n)",
  "#+END_SRC",
  "after",
}
local buf = buffer(doc)
local b = babel.block_at(buf, 2)
eq("block lang", b and b.lang, "python")
eq("block body", b and b.body, { "print(n)" })
eq("block rows", b and { b.begin_row, b.end_row }, { 1, 3 })
eq("on #+begin_src", babel.block_at(buf, 1) ~= nil, true)
eq("on #+end_src", babel.block_at(buf, 3) ~= nil, true)
eq("after the block", babel.block_at(buf, 4), nil)
eq("before the block", babel.block_at(buf, 0), nil)

-- write_results: insert, then replace (old results go, the rest stays).
babel.write_results(buf, 3, { "1", "", "2" })
eq("results inserted", lines(buf), { "* Heading", "#+BEGIN_SRC python :var n=2", "print(n)", "#+END_SRC", "", "#+RESULTS:", ": 1", ":", ": 2", "after" })
babel.write_results(buf, 3, { "3" })
eq("results replaced", lines(buf), { "* Heading", "#+BEGIN_SRC python :var n=2", "print(n)", "#+END_SRC", "", "#+RESULTS:", ": 3", "after" })

-- Running blocks, one per language.
local cases = {
  { "sh", { "echo $n" }, { "21" }, "sh" },
  { "python", { "print(n * 2)" }, { "42" }, "python3" },
  { "lua", { "print(n + 1)" }, { "22" } },
  { "c", { 'printf("%d\\n", n * 2);' }, { "42" }, "cc" },
  { "rust", { 'println!("{}", N * 2);' }, { "42" }, "rustc" },
  { "racket", { "(displayln (* n 2))" }, { "42" }, "racket" },
}
for _, case in ipairs(cases) do
  local lang, body, want, exe = unpack(case)
  if exe and vim.fn.executable(exe) == 0 then
    skipped[#skipped + 1] = lang
  else
    local text = { "#+begin_src " .. lang .. " :var n=21" }
    vim.list_extend(text, body)
    text[#text + 1] = "#+end_src"
    local bb = buffer(text)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    babel.execute()
    vim.wait(30000, function() return #lines(bb) > #text end, 20)
    eq("run " .. lang, vim.list_slice(lines(bb), #text + 3), vim.tbl_map(function(l) return ": " .. l end, want))
  end
end

-- A failing block reports its exit code and stays in the results.
if vim.fn.executable("sh") == 1 then
  local fb = buffer({ "#+begin_src sh", "echo oops >&2; exit 3", "#+end_src" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  babel.execute()
  vim.wait(10000, function() return #lines(fb) > 3 end, 20)
  eq("failure", vim.list_slice(lines(fb), 6), { ": oops", ": [exit 3]" })
end

-- execute_all runs blocks in order, each against the rows as they are then.
if vim.fn.executable("sh") == 1 then
  local ab = buffer({ "#+begin_src sh", "echo one", "#+end_src", "#+begin_src lua", "print('two')", "#+end_src" })
  babel.execute_all()
  vim.wait(10000, function() return #lines(ab) >= 12 end, 20)
  eq("execute_all", lines(ab), {
    "#+begin_src sh", "echo one", "#+end_src", "", "#+RESULTS:", ": one",
    "#+begin_src lua", "print('two')", "#+end_src", "", "#+RESULTS:", ": two",
  })
end

io.stdout:write(("org_babel: %d passed, %d failed%s\n"):format(
  passed, #failures, #skipped > 0 and (", skipped " .. table.concat(skipped, ", ")) or ""))
for _, f in ipairs(failures) do io.stdout:write("  FAIL " .. f .. "\n") end
os.exit(#failures == 0 and 0 or 1)
