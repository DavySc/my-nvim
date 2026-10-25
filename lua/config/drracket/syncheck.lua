-- Check Syntax, the parts racket-langserver doesn't show: binding arrows for
-- the name under the cursor, tail calls, what DrRacket says on hover, and
-- unused requires. A terminal can't draw the curves, so an arrow is the two
-- ends highlighted plus "← L12" / "→ 3 uses" at the line ends.
--
-- Per buffer and only while switched on (<leader>ma): each analysis expands
-- the whole module, which is what DrRacket does in the background.

local backend = require("config.drracket.backend")
local text = require("config.drracket.text")

local M = {}

local ns = vim.api.nvim_create_namespace("drracket.syncheck")
local diag_ns = vim.api.nvim_create_namespace("drracket.syncheck.diagnostics")

---@class DrRacketSyncheck
---@field arrows [integer, integer, integer, integer, boolean][] binder start/end, use start/end, binder is a require
---@field tails [integer, integer][] from, to (expression starts)
---@field unused [integer, integer][]
---@field status [integer, integer, string][]

---@type table<integer, { tick: integer, data?: DrRacketSyncheck, text?: DrRacketText, timer?: uv.uv_timer_t, running?: boolean, again?: boolean }>
local state = {}

function M.enabled(buf) return state[buf] ~= nil end

local function covers(s, e, offset) return offset >= s and (offset < e or (s == e and offset == s)) end

--- What to show for the cursor at `offset`; pure, so tests can call it.
---@param data DrRacketSyncheck
---@param offset integer
---@return { binder?: [integer, integer], uses: [integer, integer][], require: boolean, status: string[], tails: [integer, integer][] }
function M.at(data, offset)
  local binder, is_require
  for _, a in ipairs(data.arrows) do
    if covers(a[1], a[2], offset) or covers(a[3], a[4], offset) then
      binder, is_require = { a[1], a[2] }, a[5]
      -- A binder under the cursor wins over a use it also covers.
      if covers(a[1], a[2], offset) then break end
    end
  end
  local uses = {}
  if binder then
    for _, a in ipairs(data.arrows) do
      if a[1] == binder[1] and a[2] == binder[2] then uses[#uses + 1] = { a[3], a[4] } end
    end
    table.sort(uses, function(x, y) return x[1] < y[1] end)
  end
  local status = {}
  for _, s in ipairs(data.status) do
    if covers(s[1], s[2], offset) and not vim.tbl_contains(status, s[3]) then status[#status + 1] = s[3] end
  end
  local tails = {}
  for _, t in ipairs(data.tails) do
    if t[1] == offset or t[2] == offset then tails[#tails + 1] = t end
  end
  return { binder = binder, uses = uses, require = is_require or false, status = status, tails = tails }
end

local function render(buf)
  local st = state[buf]
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not (st and st.data) or st.tick ~= vim.api.nvim_buf_get_changedtick(buf) then return end
  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end
  local cur = vim.api.nvim_win_get_cursor(win)
  local t = st.text
  local here = M.at(st.data, text.offset(t, cur[1] - 1, cur[2]))
  local eol = {} ---@type table<integer, string[]>
  local function note(row, s)
    eol[row] = eol[row] or {}
    table.insert(eol[row], s)
  end
  local function mark(range, hl)
    local sr, sc = text.pos(t, range[1])
    local er, ec = text.pos(t, math.max(range[2], range[1] + 1))
    vim.api.nvim_buf_set_extmark(buf, ns, sr, sc, { end_row = er, end_col = ec, hl_group = hl, priority = 150 })
    return sr
  end
  if here.binder then
    local brow = mark(here.binder, "DrRacketBinder")
    for _, u in ipairs(here.uses) do
      local urow = mark(u, "DrRacketBound")
      if urow ~= brow and not here.require then note(urow, "← L" .. (brow + 1)) end
    end
    local n = #here.uses
    note(brow, ("→ %d %s"):format(n, n == 1 and "use" or "uses"))
  end
  for _, tl in ipairs(here.tails) do
    mark({ tl[1], tl[1] + 1 }, "DrRacketTail")
    local to_row = mark({ tl[2], tl[2] + 1 }, "DrRacketTail")
    note(to_row, "↻ tail call")
  end
  for _, s in ipairs(here.status) do note(cur[1] - 1, s) end
  for row, notes in pairs(eol) do
    vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
      virt_text = { { "  " .. table.concat(notes, " · "), "DrRacketArrow" } },
      virt_text_pos = "eol",
    })
  end
end

local function set_unused(buf)
  local st = state[buf]
  local diags = {}
  for _, u in ipairs(st.data.unused) do
    local sr, sc = text.pos(st.text, u[1])
    local er, ec = text.pos(st.text, u[2])
    diags[#diags + 1] = {
      lnum = sr, col = sc, end_lnum = er, end_col = ec, source = "check syntax",
      severity = vim.diagnostic.severity.HINT, message = "unused require",
      _tags = { unnecessary = true },
    }
  end
  vim.diagnostic.set(diag_ns, buf, diags)
end

--- Analyse the buffer as it is now (saved or not).
---@param buf integer
---@param cb? fun(err?: DrRacketError)
function M.refresh(buf, cb)
  local st = state[buf]
  if not st then return end
  if st.running then
    st.again = true
    return
  end
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local t = text.of(buf)
  st.running = true
  backend.request("syncheck", {
    file = vim.api.nvim_buf_get_name(buf),
    text = table.concat(t.lines, "\n") .. "\n",
  }, function(err, result)
    st.running = false
    if state[buf] ~= st or not vim.api.nvim_buf_is_valid(buf) then return end
    if not err then
      st.tick, st.data, st.text = tick, result, t
      set_unused(buf)
      render(buf)
    end
    if st.again then
      st.again = false
      M.refresh(buf)
    end
    if cb then cb(err) end
  end)
end

local group = vim.api.nvim_create_augroup("drracket.syncheck", { clear = true })

---@param buf integer
---@param on? boolean default: flip
---@param cb? fun(err?: DrRacketError) after the first analysis
function M.toggle(buf, on, cb)
  if on == nil then on = not M.enabled(buf) end
  vim.api.nvim_clear_autocmds({ group = group, buffer = buf })
  if not on then
    local st = state[buf]
    if st and st.timer then st.timer:close() end
    state[buf] = nil
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.diagnostic.reset(diag_ns, buf)
    return
  end
  state[buf] = { tick = -1, timer = vim.uv.new_timer() }
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group, buffer = buf, callback = function() render(buf) end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufWritePost" }, {
    group = group, buffer = buf,
    callback = function()
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      local st = state[buf]
      st.timer:stop()
      st.timer:start(600, 0, vim.schedule_wrap(function()
        if state[buf] == st and vim.fn.mode() ~= "i" then M.refresh(buf) end
      end))
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group, buffer = buf, callback = function() M.toggle(buf, false) end,
  })
  M.refresh(buf, cb)
end

M._render = render
return M
