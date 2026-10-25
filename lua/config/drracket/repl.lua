-- The Interactions window: a prompt buffer. Program output and values are
-- inserted above the prompt line; images are drawn under their line with
-- Snacks image where the terminal can (Ghostty, kitty), otherwise the line
-- says [image] and <CR> on it opens the picture.

local M = {}

local NAME = "Racket Interactions"
local ns = vim.api.nvim_create_namespace("drracket.repl")

local buf ---@type integer?
local open_line = false -- the last output line didn't end in a newline
local images = {} ---@type table<integer, string> extmark id -> png path
local placements = {} ---@type table[] Snacks placements to close on clear
local history, hist_pos = {}, 0

---@type fun(code: string)
M.on_submit = function() end

local function valid() return buf and vim.api.nvim_buf_is_valid(buf) end

--- Lines above the prompt line: [0, last_output_row()).
local function prompt_row() return vim.api.nvim_buf_line_count(buf) - 1 end

local function set_history(delta)
  if #history == 0 then return end
  hist_pos = math.max(1, math.min(#history + 1, hist_pos + delta))
  local text = history[hist_pos] or ""
  local row = prompt_row()
  vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { vim.fn.prompt_getprompt(buf) .. text })
  vim.api.nvim_win_set_cursor(0, { row + 1, #vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] })
end

local function open_image_at_cursor()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, -1 }, {})) do
    local path = images[mark[1]]
    if path then return M.show_image(path) end
  end
  return false
end

function M.buf()
  if valid() then return buf end
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, NAME)
  vim.bo[buf].buftype = "prompt"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.fn.prompt_setprompt(buf, "> ")
  vim.fn.prompt_setcallback(buf, function(text)
    if text:match("^%s*$") then return end
    history[#history + 1] = text
    hist_pos = #history + 1
    M.on_submit(text)
  end)
  open_line = false
  -- Interactions read as Racket, so the prompt line gets highlighting.
  pcall(vim.treesitter.start, buf, "racket")
  vim.keymap.set("i", "<Up>", function() set_history(-1) end, { buffer = buf, desc = "Racket: previous input" })
  vim.keymap.set("i", "<Down>", function() set_history(1) end, { buffer = buf, desc = "Racket: next input" })
  vim.keymap.set("n", "<CR>", function()
    if not open_image_at_cursor() then vim.cmd("startinsert!") end
  end, { buffer = buf, desc = "Racket: open image / go to prompt" })
  return buf
end

--- The window showing the Interactions buffer, opening one below if needed.
---@param focus? boolean
function M.open(focus)
  local b = M.buf()
  local win = vim.fn.bufwinid(b)
  if win == -1 then
    local cur = vim.api.nvim_get_current_win()
    vim.cmd("botright split")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, b)
    vim.api.nvim_win_set_height(win, math.max(8, math.floor(vim.o.lines * 0.3)))
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].winfixheight = true
    if not focus then vim.api.nvim_set_current_win(cur) end
  elseif focus then
    vim.api.nvim_set_current_win(win)
  end
  return win
end

function M.toggle()
  local win = valid() and vim.fn.bufwinid(buf) or -1
  if win ~= -1 then vim.api.nvim_win_close(win, false) else M.open(true) end
end

local function follow()
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 and vim.api.nvim_get_current_win() ~= win then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
end

--- Append text above the prompt; `hl` colours what's added.
---@param text string
---@param hl? string
function M.append(text, hl)
  local b = M.buf()
  if text == "" then return end
  local lines = vim.split(text, "\n", { plain = true })
  local row = prompt_row()
  local first_row, first_col
  if open_line and row > 0 then
    local prev = vim.api.nvim_buf_get_lines(b, row - 1, row, false)[1]
    first_row, first_col = row - 1, #prev
    vim.api.nvim_buf_set_text(b, row - 1, #prev, row - 1, #prev, { lines[1] })
    table.remove(lines, 1)
  else
    first_row, first_col = row, 0
  end
  -- A trailing newline leaves an empty last chunk: the line is closed.
  open_line = lines[#lines] ~= ""
  if not open_line then table.remove(lines) end
  if #lines > 0 then
    local at = prompt_row()
    vim.api.nvim_buf_set_lines(b, at, at, false, lines)
  end
  if hl then
    local last = prompt_row() - 1
    local last_line = vim.api.nvim_buf_get_lines(b, last, last + 1, false)[1] or ""
    if last >= first_row then
      vim.api.nvim_buf_set_extmark(b, ns, first_row, first_col, {
        end_row = last, end_col = #last_line, hl_group = hl, hl_eol = false, priority = 120,
      })
    end
  end
  follow()
end

--- End the current output line, if one is open (before a value or a message).
function M.newline()
  if open_line then M.append("\n") end
end

---@param path string
function M.show_image(path)
  local ok, snacks = pcall(function() return Snacks end)
  if ok and snacks and snacks.image and snacks.image.supports_terminal() then
    local fbuf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(fbuf, true, {
      relative = "editor", style = "minimal", border = "rounded", title = " image ",
      width = math.floor(vim.o.columns * 0.5), height = math.floor(vim.o.lines * 0.5),
      row = math.floor(vim.o.lines * 0.2), col = math.floor(vim.o.columns * 0.25),
    })
    snacks.image.placement.new(fbuf, path, {})
    vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = fbuf })
  else
    vim.ui.open(path)
  end
  return true
end

local function inline_images()
  local ok, snacks = pcall(function() return Snacks end)
  if not (ok and snacks and snacks.image) then return nil end
  if not snacks.image.supports_terminal() then return nil end
  if not snacks.image.terminal.env().placeholders then return nil end
  return snacks
end

--- A value that is a picture: drawn under its line, or a clickable [image].
---@param path string
function M.image(path)
  M.newline()
  local snacks = inline_images()
  M.append(snacks and " \n" or "[image] " .. vim.fn.fnamemodify(path, ":t") .. "\n", "DrRacketValue")
  local row = prompt_row() - 1
  local id = vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {})
  images[id] = path
  if snacks then
    local okp, p = pcall(snacks.image.placement.new, buf, path, { pos = { row + 1, 0 }, inline = true, max_height = 12 })
    if okp then placements[#placements + 1] = p end
  end
end

--- Start over for a new Run: everything but the prompt goes.
---@param header string
function M.clear(header)
  local b = M.buf()
  for _, p in ipairs(placements) do pcall(p.close, p) end
  placements, images = {}, {}
  vim.api.nvim_buf_clear_namespace(b, ns, 0, -1)
  local row = prompt_row()
  vim.api.nvim_buf_set_lines(b, 0, row, false, {})
  open_line = false
  M.append(header .. "\n", "DrRacketInfo")
end

return M
