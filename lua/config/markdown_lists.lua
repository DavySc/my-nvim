-- Lists that continue themselves in markdown (org's M-RET, in vim's keys):
-- <CR> at the end of a list item and `o` on one start the next item with the
-- same bullet, the next number, or an unticked "- [ ] ". <CR> on an empty item
-- ends the list (the marker goes away). Elsewhere <CR> and o are plain vim.
-- Installed per buffer by ftplugin/markdown.lua.

local M = {}

--- The marker that follows `line`'s item, or nil when it isn't a list item.
--- Also returns whether the item is empty (only its marker).
---@param line string
---@return string? next, boolean empty
function M.next_marker(line)
  local indent, bullet, box, rest = line:match("^(%s*)([-*+])%s+(%[[ xX]%]%s+)(.*)$")
  if not indent then
    indent, bullet, rest = line:match("^(%s*)([-*+])%s+(.*)$")
    box = nil
  end
  if indent then
    return indent .. bullet .. " " .. (box and "[ ] " or ""), rest == ""
  end
  local num, sep
  indent, num, sep, rest = line:match("^(%s*)(%d+)([.)])%s+(.*)$")
  if indent then
    return indent .. (tonumber(num) + 1) .. sep .. " ", rest == ""
  end
  return nil, false
end

--- <CR> in insert mode.
function M.enter()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local marker, empty = M.next_marker(line)
  -- Only at the end of an item: in the middle, Enter splits the line as usual.
  if not marker or col < #line:gsub("%s+$", "") then
    return vim.api.nvim_feedkeys(vim.keycode("<CR>"), "in", false)
  end
  if empty then
    vim.api.nvim_set_current_line("")
    return vim.api.nvim_win_set_cursor(0, { row, 0 })
  end
  vim.api.nvim_buf_set_lines(0, row, row, false, { marker })
  vim.api.nvim_win_set_cursor(0, { row + 1, #marker })
end

--- `o` in normal mode: a new item below, or a plain `o`.
function M.open_below()
  local marker = M.next_marker(vim.api.nvim_get_current_line())
  if not marker or vim.v.count > 1 then
    return vim.api.nvim_feedkeys((vim.v.count > 1 and vim.v.count or "") .. "o", "in", false)
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, { marker })
  vim.api.nvim_win_set_cursor(0, { row + 1, #marker })
  vim.cmd("startinsert!")
end

function M.attach(buf)
  vim.keymap.set("i", "<CR>", M.enter, { buffer = buf, desc = "New line, continuing a list" })
  vim.keymap.set("n", "o", M.open_below, { buffer = buf, desc = "Open line, continuing a list" })
end

return M
