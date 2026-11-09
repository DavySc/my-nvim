-- The dashboard cat, ported from kittymax (nixfiles/kittymax/lisp/kitty-splash.el):
-- a cat head centred in the window and sized to it, in catppuccin colours that
-- shimmer down its outline; it blinks, twitches an ear and wiggles its whiskers.
--
-- The cat is generated, not drawn: a head from a squared ellipse, ears standing
-- on its corners, features at computed positions, so it is symmetric and
-- exactly as wide as it claims at every size.
--
-- It is a snacks dashboard section (config/core/ui.lua). The animation costs
-- nothing when the dashboard isn't visible: a timer runs only while it is on
-- screen, and stops after `M.seconds`.

local M = {}

M.interval = 350 -- ms between frames
M.seconds = 300 -- stop animating after this long; the cat then stays as it is
M.animate = true

-- ── The cat ─────────────────────────────────────────────────────────────

-- Emacs's `round` rounds halves to even; the cat's proportions depend on it.
local function round(x)
  local f = math.floor(x)
  local d = x - f
  if d > 0.5 then return f + 1 end
  if d < 0.5 then return f end
  return f % 2 == 0 and f or f + 1
end

local function rows_of(rx)
  local ry = rx * 0.39
  local eh = math.max(3, round(rx * 0.2))
  return eh + math.floor(2 * ry) + 5
end

local function cols_of(rx) return 2 * rx + 7 end

--- A cat head, `rx` columns either side of the centre.
--- Returns rows (lists of one-cell strings) and roles (one letter per cell:
--- o outline, e ear, y eye, n nose, m mouth, w whisker, " " for nothing).
---@param rx integer
---@param blink? boolean close the eyes
---@param twitch? boolean move the right ear
---@param whisker? string the character the whiskers are drawn with
---@return string[][] chars, string[][] roles
function M.cat(rx, blink, twitch, whisker)
  local ry = rx * 0.39
  local eh = math.max(3, round(rx * 0.2))
  local top = eh
  local cy = eh + ry + 0.7
  local denom = ry + 1.4
  local w = cols_of(rx)
  local cx = math.floor(w / 2)
  local h = rows_of(rx)
  whisker = whisker or "="
  local chars, roles = {}, {}
  for y = 0, h - 1 do
    chars[y], roles[y] = {}, {}
    for x = 0, w - 1 do
      chars[y][x], roles[y][x] = " ", " "
    end
  end
  local function put(x, y, c, role)
    if x >= 0 and x < w and y >= 0 and y < h then
      chars[y][x], roles[y][x] = c, role
    end
  end
  local function text(x, y, s, role)
    for i = 1, #s do put(x + i - 1, y, s:sub(i, i), role) end
  end
  local function hw(y)
    local t = (y - cy) / denom
    if math.abs(t) > 1 then return nil end
    return round(rx * (1.0 - math.abs(t) ^ 3) ^ (1.0 / 3))
  end

  -- head
  local last
  for y = top, h - 1 do
    if hw(y) then last = y end
  end
  for y = top, last do
    local half = hw(y)
    if half then
      local t = (y - cy) / denom
      local xl, xr = cx - half, cx + half
      if y == top or y == last then
        for x = xl + 1, xr - 1 do put(x, y, y < cy and "_" or "‾", "o") end
      end
      put(xl, y, math.abs(t) < 0.3 and "(" or (y < cy and "/" or "\\"), "o")
      put(xr, y, math.abs(t) < 0.3 and ")" or (y < cy and "\\" or "/"), "o")
    end
  end
  -- ears, standing on the top corners of the head
  local axl = cx - round(rx * 0.58)
  local axr = (2 * cx - axl) + (twitch and -1 or 0)
  for r = 0, eh - 1 do
    put(axl - r, r, "/", "e")
    put(axl + 1 + r, r, "\\", "e")
    put(axr + r, r, "\\", "e")
    put(axr - 1 - r, r, "/", "e")
  end
  -- eyes
  local ey, ex = round(cy) - 2, round(rx * 0.42)
  for _, s in ipairs({ -1, 1 }) do
    local x = cx + s * ex - 1
    if blink then
      text(x, ey + 1, "---", "y")
    else
      text(x, ey, ".-.", "y")
      text(x, ey + 1, "|o|", "y")
      text(x, ey + 2, "'-'", "y")
    end
  end
  -- nose, mouth, whiskers
  local ny = ey + 3
  local wl = math.max(3, round(rx * 0.22))
  text(cx - 1, ny, "\\v/", "n")
  put(cx, ny + 1, "|", "n")
  text(cx - 4, ny + 2, "\\__/ \\__/", "m")
  for _, d in ipairs({ 0, 1 }) do
    local len = wl - d
    text(cx - rx + 2 + d, ny + d, whisker:rep(len), "w")
    text(cx + rx - 2 - d - len + 1, ny + d, whisker:rep(len), "w")
  end
  return chars, roles
end

--- The cat as plain strings, one per row (for tests and :lua print).
function M.lines(rx, blink, twitch, whisker)
  local chars = M.cat(rx, blink, twitch, whisker)
  local out = {}
  for y = 0, #chars do
    out[#out + 1] = table.concat(chars[y], "", 0, #chars[y])
  end
  return out
end

M.rows = rows_of
M.cols = cols_of

-- ── Colour: catppuccin mocha ────────────────────────────────────────────

local gradient = {
  "#f5c2e7", "#cba6f7", "#b4befe", "#89b4fa", "#74c7ec", "#94e2d5",
  "#a6e3a1", "#94e2d5", "#74c7ec", "#89b4fa", "#b4befe", "#cba6f7",
}
local fixed = { e = "#f5c2e7", y = "#a6e3a1", n = "#f38ba8", m = "#fab387", w = "#a6adc8" }

local function define_highlights()
  for i, color in ipairs(gradient) do
    vim.api.nvim_set_hl(0, "SplashCat" .. i, { fg = color, bold = true })
  end
  for role, color in pairs(fixed) do
    vim.api.nvim_set_hl(0, "SplashCat_" .. role, { fg = color, bold = true })
  end
  vim.api.nvim_set_hl(0, "SplashCatDim", { fg = "#7f849c", italic = true })
end

local function hl_for(role, row, frame)
  if fixed[role] then return "SplashCat_" .. role end
  return "SplashCat" .. ((row + math.floor(frame / 2)) % #gradient + 1)
end

-- ── Dashboard section ───────────────────────────────────────────────────

local frame = 0
local timer, started

--- The biggest cat that fits a `width` x `height` window with `below` lines
--- of dashboard under it, or nil.
function M.pick(width, height, below)
  for _, rx in ipairs({ 24, 17, 11, 7, 5 }) do
    if width >= cols_of(rx) + 6 and height >= rows_of(rx) + below then return rx end
  end
end

--- The dashboard text for animation frame `n` in a window of the given size:
--- a list of { text, hl = group } chunks, rows separated by "\n" chunks.
function M.texts(n, width, height, below)
  local rx = M.pick(width, height, below)
  local out = {}
  if rx then
    local chars, roles = M.cat(rx, n % 12 == 11, n % 31 == 7, n % 9 == 4 and "~" or "=")
    for y = 0, #chars do
      if y > 0 then out[#out + 1] = { "\n" } end
      local x, w = 0, #chars[y] + 1
      while x < w do
        local role, j = roles[y][x], x
        local run = {}
        while j < w and roles[y][j] == role do
          run[#run + 1] = chars[y][j]
          j = j + 1
        end
        out[#out + 1] = { table.concat(run), hl = role ~= " " and hl_for(role, y, n) or nil }
        x = j
      end
    end
    out[#out + 1] = { "\n" }
  end
  -- the name, in the gradient
  local name = "n e o v i m"
  local i = 0
  for c in name:gmatch(".") do
    out[#out + 1] = { c, hl = c ~= " " and ("SplashCat" .. ((i + math.floor(n / 2)) % #gradient + 1)) or nil }
    i = i + 1
  end
  return out
end

local function dashboard_buf()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "snacks_dashboard" then return buf, win end
  end
end

function M.stop()
  if timer then
    vim.fn.timer_stop(timer)
    timer = nil
  end
end

local function tick()
  if not dashboard_buf() or (vim.uv.hrtime() - started) / 1e6 > M.seconds * 1000 then return M.stop() end
  frame = frame + 1
  -- One failed redraw stops the cat, instead of an error every frame.
  if not pcall(Snacks.dashboard.update) then M.stop() end
end

--- Start animating (called when the dashboard opens); restarts the clock.
function M.start()
  if not M.animate or #vim.api.nvim_list_uis() == 0 then return end
  M.stop()
  started = vim.uv.hrtime()
  -- A Vim timer runs on the main loop, between keys and redraws.
  timer = vim.fn.timer_start(M.interval, function() tick() end, { ["repeat"] = -1 })
end

--- Whether the animation timer is running.
function M.running() return timer ~= nil end

--- The snacks dashboard section: the cat for the current frame, sized to
--- the window, leaving `below` lines for the rest of the dashboard.
---@param below integer
function M.section(below)
  return function()
    local _, win = dashboard_buf()
    local width = win and vim.api.nvim_win_get_width(win) or vim.o.columns
    local height = win and vim.api.nvim_win_get_height(win) or vim.o.lines
    return { align = "center", padding = 1, text = M.texts(frame, width, height, below) }
  end
end

function M.setup()
  define_highlights()
  local group = vim.api.nvim_create_augroup("config-splash", { clear = true })
  -- The theme may be loaded (or reloaded) after us: keep our colours.
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = define_highlights })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "SnacksDashboardOpened",
    callback = function()
      frame = 0
      M.start()
    end,
  })
  vim.api.nvim_create_autocmd("User", { group = group, pattern = "SnacksDashboardClosed", callback = M.stop })
end

return M
