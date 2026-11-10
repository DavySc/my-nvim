-- SQL statements as vim objects, from dbbliss's splitter (require("dbbliss").statements:
-- `;`, blank lines and T-SQL GO lines, never inside strings or comments):
--   iq / aq   inside / around the statement (yiq copies it, gqaq formats it)
--   ]] / [[   next / previous statement start (counts work; jumps go in the jumplist)
-- aq is linewise, takes the comment lines just above the statement and the
-- blank lines after it, like ap does for paragraphs. Installed per buffer by
-- ftplugin/sql.lua.

local M = {}

---@alias Pos integer[] { row (1-based), col (0-based byte) }
---@alias Stmt { start: Pos, ["end"]: Pos, terminator?: Pos }

local function before(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end

--- The statements of `buf`, or nil when dbbliss is too old (or missing).
---@return Stmt[]?
function M.list(buf)
  local ok, db = pcall(require, "dbbliss")
  if not ok or type(db.statements) ~= "function" then return nil end
  return db.statements(buf)
end

--- The statement at `pos`: the one containing it, else the next one, else the last.
---@param stmts Stmt[]
---@param pos Pos
---@return Stmt?
function M.at(stmts, pos)
  for _, s in ipairs(stmts) do
    local last = s.terminator or s["end"]
    if not before(last, pos) then return s end
  end
  return stmts[#stmts]
end

local function select(from, to, mode)
  if vim.fn.mode():find("^[vV\22]") then vim.cmd("normal! \27") end
  vim.api.nvim_win_set_cursor(0, { from[1], from[2] })
  vim.cmd("normal! " .. mode)
  vim.api.nvim_win_set_cursor(0, { to[1], to[2] })
end

local function unavailable()
  vim.notify("SQL statements need dbbliss.nvim with statements() (update it)", vim.log.levels.WARN)
end

--- Select the statement under the cursor: inside (charwise, without the `;`)
--- or around (linewise, with the comments above and the blank lines after).
---@param around boolean
function M.object(around)
  local buf = vim.api.nvim_get_current_buf()
  local stmts = M.list(buf)
  if not stmts then return unavailable() end
  local s = M.at(stmts, vim.api.nvim_win_get_cursor(0))
  if not s then return end
  if not around then return select(s.start, s["end"], "v") end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local first = s.start[1]
  while first > 1 and lines[first - 1]:match("^%s*%-%-") do first = first - 1 end
  local last = (s.terminator or s["end"])[1]
  local after = last
  while after < #lines and lines[after + 1]:match("^%s*$") do after = after + 1 end
  if after == last then -- nothing after: take the blank lines before, as ap does
    while first > 1 and lines[first - 1]:match("^%s*$") do first = first - 1 end
  end
  select({ first, 0 }, { after, 0 }, "V")
end

--- Move to the start of the [count]th next (or previous) statement.
---@param forward boolean
function M.jump(forward)
  local stmts = M.list(vim.api.nvim_get_current_buf())
  if not stmts then return unavailable() end
  local pos = vim.api.nvim_win_get_cursor(0)
  local target
  for _ = 1, math.max(vim.v.count1, 1) do
    local found
    if forward then
      for _, s in ipairs(stmts) do
        if before(pos, s.start) then found = s.start break end
      end
    else
      for i = #stmts, 1, -1 do
        if before(stmts[i].start, pos) then found = stmts[i].start break end
      end
    end
    if not found then break end
    target, pos = found, found
  end
  if target then
    vim.cmd("normal! m'")
    vim.api.nvim_win_set_cursor(0, { target[1], target[2] })
  end
end

--- Buffer-local keys for `buf`.
function M.attach(buf)
  local function map(modes, lhs, fn, desc)
    vim.keymap.set(modes, lhs, fn, { buffer = buf, silent = true, desc = desc })
  end
  map({ "o", "x" }, "iq", function() M.object(false) end, "Inside SQL statement")
  map({ "o", "x" }, "aq", function() M.object(true) end, "Around SQL statement")
  map({ "n", "x", "o" }, "]]", function() M.jump(true) end, "Next SQL statement")
  map({ "n", "x", "o" }, "[[", function() M.jump(false) end, "Previous SQL statement")
end

return M
