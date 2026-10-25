-- Tests for lua/config/drracket and racket/drracket.rkt, against a real
-- Racket (skipped when `racket` isn't on PATH); needs no plugins.
--   nvim --headless --clean --cmd 'set rtp^=.' -l tests/drracket_test.lua

local failures, passed = {}, 0

local function eq(name, got, want)
  if vim.deep_equal(got, want) then
    passed = passed + 1
  else
    failures[#failures + 1] = ("%s\n    got:  %s\n    want: %s"):format(name, vim.inspect(got), vim.inspect(want))
  end
end
local function ok(name, cond, detail) eq(name .. (detail and (" (" .. detail .. ")") or ""), not not cond, true) end

local function finish()
  io.stdout:write(("drracket: %d passed, %d failed\n"):format(passed, #failures))
  for _, f in ipairs(failures) do io.stdout:write("  FAIL " .. f .. "\n") end
  vim.cmd(#failures == 0 and "qa!" or "cquit!")
end

-- ── Pure parts ───────────────────────────────────────────────────────────
local text = require("config.drracket.text")
local syncheck = require("config.drracket.syncheck")

do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "(λ (x) x)", "ab" })
  local t = text.of(buf)
  -- Characters: ( λ space ( x ... ; λ is two bytes.
  eq("pos after λ", { text.pos(t, 2) }, { 0, 3 })
  eq("pos on line 2", { text.pos(t, 11) }, { 1, 1 })
  eq("offset round trip", text.offset(t, 0, 3), 2)
  eq("byte_col", text.byte_col("λλx", 2), 4)
end

do
  local data = {
    arrows = { { 10, 12, 20, 22, false }, { 10, 12, 30, 32, false }, { 0, 6, 40, 41, true } },
    tails = { { 5, 25 } },
    unused = {},
    status = { { 10, 12, "2 bound occurrences" }, { 40, 41, "imported from racket" } },
  }
  local on_use = syncheck.at(data, 21)
  eq("use: binder", on_use.binder, { 10, 12 })
  eq("use: all uses of that binder", on_use.uses, { { 20, 22 }, { 30, 32 } })
  local on_binder = syncheck.at(data, 11)
  eq("binder: status", on_binder.status, { "2 bound occurrences" })
  eq("require arrow", syncheck.at(data, 40).require, true)
  eq("tail arrow at its start", syncheck.at(data, 25).tails, { { 5, 25 } })
  eq("nothing here", syncheck.at(data, 100).binder, nil)
end

if vim.fn.executable("racket") == 0 then
  io.stdout:write("drracket: racket not on PATH, skipping the back-end tests\n")
  return finish()
end

-- ── Through the back end ─────────────────────────────────────────────────
local drracket = require("config.drracket")
local repl = require("config.drracket.repl")
drracket.setup({ memory_mb = 256 })

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local function write(name, lines)
  local path = dir .. "/" .. name
  vim.fn.writefile(lines, path)
  return path
end

write("pics.rkt", {
  "#lang racket",
  "(require pict)",
  "(define (sq n) (* n n))",
  "(provide sq)",
  "(disk 10)",
  "(sq 4)",
  '(displayln "hello")',
})
write("bad.rkt", {
  "#lang racket",
  "(define (g y) (car y))",
  "(define (h z) (+ 1 (g z)))",
  "(h 5)",
})
write("bsl.rkt", {
  "#lang htdp/bsl",
  "(define (f x) (* x 2))",
  "(check-expect (f 2) 4)",
  "(check-expect (f 2) 5)",
})
write("mylang.rkt", {
  "#lang racket/base",
  "(require (for-syntax racket/base syntax/parse))",
  "(provide (except-out (all-from-out racket/base) #%module-begin)",
  "         (rename-out [mb #%module-begin]) bind)",
  "(define-syntax (bind stx)",
  "  (syntax-parse stx [(_ x:id e body) #'(let ([x e]) body)]))",
  "(define-syntax (mb stx)",
  '  (syntax-parse stx [(_ form ...) #\'(#%module-begin (displayln "mylang!") form ...)]))',
})
write("use.rkt", {
  '#lang s-exp "mylang.rkt"',
  "(bind y 5 (cond [(> y 1) y] [else 0]))",
})
write("arrows.rkt", {
  "#lang racket",
  "(require racket/string)",
  "(define (λloop n) (if (zero? n) 0 (λloop (sub1 n))))",
  "(λloop 3)",
})

local function interactions()
  return table.concat(vim.api.nvim_buf_get_lines(repl.buf(), 0, -1, false), "\n")
end

local function edit(name)
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/" .. name))
  return vim.api.nvim_get_current_buf()
end

--- Run `start(done)` and wait for done(...) (60 s: the first run compiles).
local function await(name, start)
  local result, finished = nil, false
  start(function(...)
    result = { ... }
    finished = true
  end)
  if not vim.wait(60000, function() return finished end, 20) then
    failures[#failures + 1] = name .. ": timed out"
    return {}
  end
  return result
end

-- Run: values, a pict, output, and the REPL inside the module afterwards.
local pics = edit("pics.rkt")
local r = await("run pics", function(done) drracket.run(pics, done) end)
eq("run pics: no error", r[1], nil)
eq("run pics: language", r[2] and r[2].language, "racket")
local out = interactions()
ok("pict became an image", out:find("[image] img-", 1, true), out)
ok("value printed", out:find("\n16\n", 1, true), out)
ok("output printed", out:find("hello", 1, true), out)
r = await("eval in module", function(done) drracket.eval("(sq 7) (values 1 2)", done) end)
eq("eval: no error", r[1], nil)
ok("eval sees the module's definitions", interactions():find("49\n1\n2", 1, true), interactions())

-- A second Run starts over: the REPL's own definitions are gone.
await("define in repl", function(done) drracket.eval("(define only-here 1)", done) end)
await("run again", function(done) drracket.run(pics, done) end)
r = await("eval after rerun", function(done) drracket.eval("only-here", done) end)
ok("rerun resets the namespace", r[1] and r[1].message:find("only%-here"), r[1] and r[1].message)

-- Runtime error: errortrace points at (car y); pink box, diagnostic, quickfix.
local bad = edit("bad.rkt")
r = await("run bad", function(done) drracket.run(bad, done) end)
ok("run bad: error", r[1] and r[1].message:find("car: contract violation", 1, true))
local loc = r[1] and drracket.primary(r[1])
eq("error location", loc and { loc.line, loc.col }, { 2, 14 })
local diags = vim.diagnostic.get(bad)
eq("diagnostic on (car y)", diags[1] and { diags[1].lnum, diags[1].col, diags[1].end_col }, { 1, 14, 21 })
local marks = vim.api.nvim_buf_get_extmarks(bad, vim.api.nvim_get_namespaces()["drracket.errors"], 0, -1, { details = true })
eq("pink box", marks[1] and marks[1][4].hl_group, "DrRacketErrorRange")
ok("stack in quickfix", #vim.fn.getqflist() >= 2, tostring(#vim.fn.getqflist()))
-- Editing clears it, as in DrRacket.
vim.api.nvim_buf_set_lines(bad, 4, 4, false, { "" })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = bad })
eq("edit clears the diagnostic", #vim.diagnostic.get(bad), 0)
vim.cmd("silent! undo | silent write")

-- Teaching language: the check-expect report, and BSL's own REPL rules.
local bsl = edit("bsl.rkt")
r = await("run bsl", function(done) drracket.run(bsl, done) end)
eq("run bsl: no error", r[1], nil)
ok("check-expect report", interactions():find("1 of the 2 tests failed", 1, true), interactions())
r = await("bsl repl", function(done) drracket.eval("(define (g x) x)", done) end)
ok("BSL's interaction rules apply", r[1] and r[1].message:find("definitions window", 1, true), r[1] and r[1].message)

-- Your own #lang: its module-begin runs, its macros work in the REPL.
local use = edit("use.rkt")
r = await("run own lang", function(done) drracket.run(use, done) end)
eq("run own lang: no error", r[1], nil)
ok("module-begin ran", interactions():find("mylang!", 1, true), interactions())
await("own lang repl", function(done) drracket.eval("(bind q 3 (* q q))", done) end)
ok("its macro in the REPL", interactions():find("\n9\n", 1, true), interactions())

-- Macro stepper: your macros' steps, Racket's own (cond) hidden by default.
r = await("expand", function(done) drracket.expand({ buf = use }, done) end)
local steps = table.concat(r[2] or {}, "\n")
ok("bind step shown", steps:find("(let", 1, true), steps)
ok("cond hidden", not steps:find("if:", 1, true), steps)
r = await("expand all", function(done) drracket.expand({ buf = use, all = true }, done) end)
ok("expand! shows cond too", table.concat(r[2] or {}, "\n"):find("if", 1, true))
r = await("expand form", function(done) drracket.expand({ buf = use, form = "(bind a 1 a)" }, done) end)
ok("selection expands in the language", table.concat(r[2] or {}, "\n"):find("let", 1, true))

-- Stop a runaway evaluation.
local looping = false
vim.defer_fn(function() looping = true drracket.stop() end, 800)
r = await("stop", function(done) drracket.eval("(let loop () (loop))", done) end)
eq("stopped with a break", r[1] and r[1].kind, "break")
ok("said so", looping and interactions():find("user break", 1, true))

-- The memory limit ends a run instead of the machine.
await("run pics again", function(done) drracket.run(pics, done) end)
r = await("memory", function(done)
  drracket.eval("(define big (for/list ([i (in-naturals)]) (make-vector 1000 i)))", done)
end)
eq("memory limit", r[1] and r[1].kind, "killed")

-- Check Syntax: arrows over text with λ in names, unused require.
local arrows = edit("arrows.rkt")
r = await("syncheck", function(done) syncheck.toggle(arrows, true, done) end)
eq("syncheck: no error", r[1], nil)
local unused = vim.diagnostic.get(arrows, { namespace = vim.api.nvim_get_namespaces()["drracket.syncheck.diagnostics"] })
eq("unused require", unused[1] and { unused[1].lnum, unused[1].col, unused[1].message }, { 1, 9, "unused require" })
-- Cursor on the binder λloop: its two uses light up.
vim.api.nvim_win_set_cursor(0, { 3, 10 })
syncheck._render(arrows)
local sns = vim.api.nvim_get_namespaces()["drracket.syncheck"]
local bound, notes = {}, {}
for _, m in ipairs(vim.api.nvim_buf_get_extmarks(arrows, sns, 0, -1, { details = true })) do
  if m[4].hl_group == "DrRacketBound" then bound[#bound + 1] = { m[2], m[3], m[4].end_col } end
  if m[4].virt_text then notes[#notes + 1] = m[4].virt_text[1][1] end
end
table.sort(bound, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
eq("uses of λloop (byte columns)", bound, { { 2, 36, 42 }, { 3, 1, 7 } })
ok("use count note", vim.iter(notes):any(function(n) return n:find("→ 2 uses", 1, true) end), vim.inspect(notes))
syncheck.toggle(arrows, false)
eq("arrows off clears", #vim.api.nvim_buf_get_extmarks(arrows, sns, 0, -1, {}), 0)

-- :ConfigReload loads these modules again: the old process is ended and the
-- buffers' names don't collide.
r = await("before reload", function(done) drracket.run(pics, done) end)
local old_backend = require("config.drracket.backend")
for name in pairs(package.loaded) do
  if name:find("^config%.drracket") then package.loaded[name] = nil end
end
drracket = require("config.drracket")
repl = require("config.drracket.repl")
drracket.setup()
ok("reload: a fresh backend module", require("config.drracket.backend") ~= old_backend)
eq("reload: old process ended", vim.wait(5000, function() return not old_backend.running() end, 20), true)
r = await("run after reload", function(done) drracket.run(pics, done) end)
eq("run after reload: no error", r[1], nil)
ok("run after reload: output", interactions():find("hello", 1, true), interactions())
r = await("expand after reload", function(done) drracket.expand({ buf = use }, done) end)
eq("expand after reload: no error", r[1], nil)

require("config.drracket.backend").stop()
finish()
