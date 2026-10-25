-- DrRacket's loop in Neovim, on top of racket-langserver (which already does
-- Check Syntax's jump/rename/hover):
--   Run         fresh namespace per run, the file's main and test submodules,
--               then a REPL inside the module, in the file's own #lang
--               (configure-runtime, #%top-interaction, its reader)
--   Interactions  values, picts and 2htdp images (Snacks image), output
--   errors      errortrace on: the innermost expression gets DrRacket's pink
--               box and a diagnostic; the rest of the stack goes to quickfix
--   stepper     the macro stepper as text (racket's macro-debugger)
--   arrows      binding arrows, tail calls, unused requires (syncheck.lua)
-- The work happens in racket/drracket.rkt, one Racket process per Neovim.

local backend = require("config.drracket.backend")
local repl = require("config.drracket.repl")
local syncheck = require("config.drracket.syncheck")
local text = require("config.drracket.text")

local M = {}

---@class DrRacketOpts
---@field errortrace boolean DrRacket's "debugging": precise error locations, slower code
---@field memory_mb? integer kill a run that uses more (DrRacket's memory limit)
---@field submodules string[] run after the module, when they exist
M.opts = { errortrace = true, memory_mb = 1024, submodules = { "main", "test" } }

local err_ns = vim.api.nvim_create_namespace("drracket.errors")
local running = false

local function set_highlights()
  local dark = vim.o.background == "dark"
  local hl = function(name, val) vim.api.nvim_set_hl(0, name, vim.tbl_extend("keep", val, { default = true })) end
  -- DrRacket's error box is pink.
  hl("DrRacketErrorRange", { bg = dark and "#4a2027" or "#fbe1e3" })
  hl("DrRacketError", { link = "ErrorMsg" })
  hl("DrRacketStderr", { link = "DiagnosticError" })
  hl("DrRacketValue", { link = "Identifier" })
  hl("DrRacketInfo", { link = "Comment" })
  hl("DrRacketEcho", { link = "Comment" })
  hl("DrRacketBinder", { link = "LspReferenceWrite" })
  hl("DrRacketBound", { link = "LspReferenceRead" })
  hl("DrRacketTail", { link = "DiagnosticUnderlineWarn" })
  hl("DrRacketArrow", { link = "DiagnosticHint" })
  hl("DrRacketStepTitle", { link = "Title" })
end

-- ── Errors ───────────────────────────────────────────────────────────────

local function clear_errors()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      vim.api.nvim_buf_clear_namespace(b, err_ns, 0, -1)
      vim.diagnostic.reset(err_ns, b)
    end
  end
end

---@param loc DrRacketSrcloc
---@return integer? buf, integer row, integer col, integer end_row, integer end_col
local function locate(loc)
  local buf = vim.fn.bufnr(loc.file)
  if buf == -1 or not vim.api.nvim_buf_is_loaded(buf) then return nil, 0, 0, 0, 0 end
  local t = text.of(buf)
  if loc.pos then
    local sr, sc = text.pos(t, loc.pos - 1)
    local er, ec = text.pos(t, loc.pos - 1 + math.max(loc.span, 1))
    return buf, sr, sc, er, ec
  end
  local row = loc.line - 1
  local col = text.byte_col(t.lines[loc.line] or "", loc.col)
  return buf, row, col, row, col + 1
end

--- Where an error points: its own srcloc (syntax, read), else the innermost
--- errortrace frame.
---@param err DrRacketError
function M.primary(err)
  return (err.srclocs or {})[1] or (err.stack or {})[1]
end

---@param err DrRacketError
function M.show_error(err)
  if err.kind == "break" then
    repl.newline()
    repl.append("user break\n", "DrRacketError")
    return
  end
  local loc = M.primary(err)
  repl.newline()
  repl.append(err.message .. "\n", "DrRacketError")
  if loc then
    repl.append(("  at %s:%d:%d\n"):format(vim.fn.fnamemodify(loc.file, ":~:."), loc.line, loc.col), "DrRacketInfo")
    local buf, sr, sc, er, ec = locate(loc)
    if buf then
      vim.api.nvim_buf_set_extmark(buf, err_ns, sr, sc, {
        end_row = er, end_col = ec, hl_group = "DrRacketErrorRange", priority = 200,
      })
      vim.diagnostic.set(err_ns, buf, {
        { lnum = sr, col = sc, end_lnum = er, end_col = ec, severity = vim.diagnostic.severity.ERROR,
          message = err.message, source = "racket" },
      })
      -- Like DrRacket, an edit makes the highlight stale: drop it.
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = buf, once = true,
        callback = function()
          vim.api.nvim_buf_clear_namespace(buf, err_ns, 0, -1)
          vim.diagnostic.reset(err_ns, buf)
        end,
      })
    end
  end
  local items = {}
  for _, l in ipairs(vim.list_extend(vim.deepcopy(err.srclocs or {}), err.stack or {})) do
    items[#items + 1] = { filename = l.file, lnum = l.line, col = l.col + 1, text = err.message:match("^[^\n]*") }
  end
  if #items > 0 then vim.fn.setqflist({}, " ", { title = "Racket: " .. err.message:match("^[^\n]*"), items = items }) end
end

-- ── Run and evaluate ─────────────────────────────────────────────────────

local function on_done(cb)
  return function(err, result)
    running = false
    if err then M.show_error(err) end
    if cb then cb(err, result) end
  end
end

--- DrRacket's Run: save, start the program over, open Interactions.
---@param buf? integer
---@param cb? fun(err?: DrRacketError, result?: table)
function M.run(buf, cb)
  buf = buf or vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    vim.notify("Racket: save the buffer first", vim.log.levels.WARN)
    return
  end
  if vim.bo[buf].modified then vim.api.nvim_buf_call(buf, function() vim.cmd("silent update") end) end
  clear_errors()
  repl.open(false)
  local o = M.opts
  repl.clear(("Running %s%s%s"):format(
    vim.fn.fnamemodify(file, ":t"),
    o.errortrace and ", with debugging" or "",
    o.memory_mb and ("; memory limit: %d MB"):format(o.memory_mb) or ""))
  running = true
  backend.request("run", {
    file = file, errortrace = o.errortrace, memory_mb = o.memory_mb, submodules = o.submodules,
  }, on_done(cb))
end

--- Evaluate code in the Interactions (what the prompt does).
---@param code string
---@param cb? fun(err?: DrRacketError)
function M.eval(code, cb)
  running = true
  backend.request("eval", { code = code }, on_done(cb))
end

--- Send code from a source buffer: echoed in Interactions, then evaluated.
---@param code string
function M.send(code)
  repl.open(false)
  repl.newline()
  repl.append(code:gsub("\n$", "") .. "\n", "DrRacketEcho")
  M.eval(code)
end

--- The top-level form around the cursor (treesitter), or nil.
function M.form_at_cursor()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then return nil end
  while node:parent() and node:parent():parent() do node = node:parent() end
  return vim.treesitter.get_node_text(node, 0)
end

function M.stop()
  backend.request("stop", vim.empty_dict(), function(_, result)
    if result and not result.stopped then vim.notify("Racket: nothing is running", vim.log.levels.INFO) end
  end)
end

--- Kill the Racket process; the next command starts a new one.
function M.restart()
  backend.stop()
  repl.clear("Racket restarted")
end

function M.is_running() return running end

-- ── Macro stepper ────────────────────────────────────────────────────────

local step_buf ---@type integer?

local function step_titles(buf)
  local rows = {}
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:match("^%u") then rows[#rows + 1] = i end
  end
  return rows
end

local function jump_step(delta)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local rows = step_titles(0)
  if delta > 0 then
    for _, r in ipairs(rows) do if r > cur then return vim.api.nvim_win_set_cursor(0, { r, 0 }) end end
  else
    for i = #rows, 1, -1 do if rows[i] < cur then return vim.api.nvim_win_set_cursor(0, { rows[i], 0 }) end end
  end
end

---@param lines string[]
local function show_steps(lines)
  if not (step_buf and vim.api.nvim_buf_is_valid(step_buf)) then
    local old = vim.fn.bufnr("^Racket Macro Stepper$") -- left by a config reload
    if old ~= -1 then vim.api.nvim_buf_delete(old, { force = true }) end
    step_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(step_buf, "Racket Macro Stepper")
    vim.bo[step_buf].bufhidden = "hide"
    vim.bo[step_buf].filetype = "racket"
    vim.keymap.set("n", "]s", function() jump_step(1) end, { buffer = step_buf, desc = "Next macro step" })
    vim.keymap.set("n", "[s", function() jump_step(-1) end, { buffer = step_buf, desc = "Previous macro step" })
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = step_buf })
  end
  vim.bo[step_buf].modifiable = true
  vim.api.nvim_buf_set_lines(step_buf, 0, -1, false, lines)
  vim.bo[step_buf].modifiable = false
  local sns = vim.api.nvim_create_namespace("drracket.stepper")
  vim.api.nvim_buf_clear_namespace(step_buf, sns, 0, -1)
  for _, r in ipairs(step_titles(step_buf)) do
    vim.api.nvim_buf_set_extmark(step_buf, sns, r - 1, 0, { line_hl_group = "DrRacketStepTitle" })
  end
  if vim.fn.bufwinid(step_buf) == -1 then
    vim.cmd("vertical botright split")
    vim.api.nvim_win_set_buf(0, step_buf)
  else
    vim.api.nvim_set_current_win(vim.fn.bufwinid(step_buf))
  end
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

--- The macro stepper on the buffer (as it is, saved or not), or on `form`
--- (expanded where the last Run left the REPL). Macros from Racket's own
--- installation are hidden unless `all`.
---@param opts { buf?: integer, form?: string, all?: boolean }
---@param cb? fun(err?: DrRacketError, lines?: string[])
function M.expand(opts, cb)
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  backend.request("expand", {
    file = vim.api.nvim_buf_get_name(buf),
    text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n",
    form = opts.form,
    all = opts.all or false,
  }, function(err, result)
    if err then
      vim.notify("Racket: " .. err.message, vim.log.levels.ERROR)
      if cb then cb(err) end
      return
    end
    local lines = vim.split(result.text, "\n", { plain = true })
    if lines[#lines] == "" then table.remove(lines) end
    if #lines == 0 then
      lines = { opts.all and "No macro steps." or "No steps from your macros (use :Racket expand! for all)." }
    end
    if cb then cb(nil, lines) else show_steps(lines) end
  end)
end

-- ── Wiring ───────────────────────────────────────────────────────────────

local function selection(line1, line2)
  return table.concat(vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false), "\n")
end

local subcommands = {
  run = function() M.run() end,
  stop = M.stop,
  restart = M.restart,
  interactions = repl.toggle,
  arrows = function() syncheck.toggle(vim.api.nvim_get_current_buf()) end,
  send = function(a)
    M.send(a.range > 0 and selection(a.line1, a.line2) or (M.form_at_cursor() or vim.api.nvim_get_current_line()))
  end,
  expand = function(a)
    M.expand({ form = a.range > 0 and selection(a.line1, a.line2) or nil, all = a.bang })
  end,
}

local did_setup = false

---@param opts? DrRacketOpts
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  if did_setup then return end
  did_setup = true
  set_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("drracket.hl", { clear = true }), callback = set_highlights,
  })
  backend.on("output", function(p)
    local hl = (p.stream == "value" and "DrRacketValue") or (p.stream == "stderr" and "DrRacketStderr") or nil
    repl.append(p.text, hl)
  end)
  backend.on("value", function(p) repl.image(p.image) end)
  backend.on("stderr", function(p) repl.append(p.text, "DrRacketStderr") end)
  backend.on("exit", function() running = false end)
  repl.on_submit = function(code) M.eval(code) end

  vim.api.nvim_create_user_command("Racket", function(a)
    local name = a.fargs[1] or "run"
    local fn = subcommands[name]
    if not fn then return vim.notify("Racket: unknown subcommand " .. name, vim.log.levels.ERROR) end
    fn(a)
  end, {
    nargs = "?", range = true, bang = true,
    complete = function() return vim.tbl_keys(subcommands) end,
    desc = "DrRacket: run | stop | restart | interactions | send | expand[!] | arrows",
  })
end

return M
