-- Racket counts positions in characters; Neovim in bytes. These convert
-- between Racket's 0-based character offsets into a buffer's text and
-- (0-based row, byte column).

local M = {}

---@class DrRacketText
---@field lines string[]
---@field starts integer[] character offset where each line starts (0-based)

---@param buf integer
---@return DrRacketText
function M.of(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local starts, offset = {}, 0
  for i, line in ipairs(lines) do
    starts[i] = offset
    offset = offset + vim.str_utfindex(line, "utf-32") + 1 -- + the newline
  end
  return { lines = lines, starts = starts }
end

---@param t DrRacketText
---@param offset integer 0-based character offset
---@return integer row, integer col 0-based row, byte column
function M.pos(t, offset)
  -- Binary search for the last line starting at or before offset.
  local lo, hi = 1, #t.starts
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if t.starts[mid] <= offset then lo = mid else hi = mid - 1 end
  end
  local line = t.lines[lo] or ""
  local chars = vim.str_utfindex(line, "utf-32")
  local col = math.max(0, math.min(offset - (t.starts[lo] or 0), chars))
  return lo - 1, vim.str_byteindex(line, "utf-32", col, false)
end

---@param t DrRacketText
---@param row integer 0-based
---@param col integer byte column
---@return integer offset 0-based character offset
function M.offset(t, row, col)
  local line = t.lines[row + 1] or ""
  return (t.starts[row + 1] or 0) + vim.str_utfindex(line, "utf-32", math.min(col, #line), false)
end

--- Byte column of a 0-based character column on one line.
---@param line string
---@param col integer
function M.byte_col(line, col)
  return vim.str_byteindex(line, "utf-32", math.min(col, vim.str_utfindex(line, "utf-32")), false)
end

return M
