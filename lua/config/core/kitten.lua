-- A kitten that gives you a paw when you save, ported from kittymax
-- (nixfiles/kittymax/lisp/kitty-cat.el). In a small float at the bottom
-- right, it blinks, puts out its paw and gets a heart:
--
--    /\_/\  <3
--   ( ^.^ )__o
--    > ^ <   saved notes.org
--
-- then "=^.^= saved notes.org" stays in the message area. It takes about a
-- second and blocks nothing: frames run on a timer and any key sends the
-- kitten away. It only plays for the buffer in front of you (not for :wa's
-- other buffers), never in a macro or without a UI, and once per save.
-- <leader>uk turns it off; :KittenPaw plays it whenever you need one.

local M = {}

M.frame_ms = 140
M.hold_ms = 1400

-- ── Frames ──────────────────────────────────────────────────────────────

local colors = {
  KittenCat = "#cba6f7", -- mauve
  KittenFace = "#a6e3a1", -- green
  KittenPaw = "#fab387", -- peach
  KittenHeart = "#f38ba8", -- red
  KittenText = "#f5c2e7", -- pink
}

local function define_highlights()
  for name, fg in pairs(colors) do
    vim.api.nvim_set_hl(0, name, { fg = fg, bold = true })
  end
  vim.api.nvim_set_hl(0, "KittenDim", { fg = "#6c7086" })
end

---@alias Kitten.Line { [1]: string, [2]?: string }[] text and highlight chunks

--- One frame: the kitten with `eyes`, its `paw`, a `heart` over the paw and
--- `text` under it. Three lines of chunks.
---@return Kitten.Line[]
local function frame(eyes, paw, heart, text)
  return {
    { { " /\\_/\\ ", "KittenCat" }, { "  " }, { heart, "KittenHeart" } },
    { { "( ", "KittenCat" }, { eyes, "KittenFace" }, { " )", "KittenCat" }, { paw, "KittenPaw" } },
    { { " > ^ < ", "KittenCat" }, { "   " }, { text, "KittenText" } },
  }
end

--- The frames for a file called `name`: { lines, ms } pairs; the kitten
--- stays on the last one for `M.hold_ms`.
---@param name string
---@return { [1]: Kitten.Line[], [2]: integer }[]
function M.frames(name)
  local d = M.frame_ms
  return {
    { frame("o.o", "", "", ""), d },
    { frame("-.-", "", "", ""), math.floor(d * 0.7) }, -- blink
    { frame("o.o", "_", "", ""), d },
    { frame("^.^", "__", "", ""), d },
    { frame("^.^", "__o", "", ""), d }, -- the paw
    { frame("^.^", "__o", "<3", "saved " .. name), M.hold_ms },
  }
end

--- What stays in the message area afterwards.
function M.summary(name)
  return { { "=^.^=", "KittenCat" }, { " saved ", "KittenDim" }, { name, "KittenText" } }
end

local function line_text(line)
  local s = ""
  for _, chunk in ipairs(line) do s = s .. chunk[1] end
  return s
end

-- ── Playing ─────────────────────────────────────────────────────────────

local ns = vim.api.nvim_create_namespace("config-kitten")
local state = nil ---@type { buf: integer, win: integer, timer: integer, for_buf: integer }?

local function close_float()
  if not state then return end
  if vim.api.nvim_win_is_valid(state.win) then vim.api.nvim_win_close(state.win, true) end
  if vim.api.nvim_buf_is_valid(state.buf) then vim.api.nvim_buf_delete(state.buf, { force = true }) end
end

--- Stop the kitten (any key does).
function M.stop()
  if not state then return end
  vim.fn.timer_stop(state.timer)
  vim.on_key(nil, ns)
  close_float()
  state = nil
end

--- Whether the kitten is on screen.
function M.playing() return state ~= nil end

local function draw(lines)
  local width = 0
  for _, line in ipairs(lines) do width = math.max(width, vim.api.nvim_strwidth(line_text(line))) end
  local text = vim.tbl_map(line_text, lines)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, text)
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for row, line in ipairs(lines) do
    local col = 0
    for _, chunk in ipairs(line) do
      if chunk[2] and #chunk[1] > 0 then
        vim.api.nvim_buf_set_extmark(state.buf, ns, row - 1, col, { end_col = col + #chunk[1], hl_group = chunk[2] })
      end
      col = col + #chunk[1]
    end
  end
  -- Bottom right, above the statusline and the command line.
  local bottom = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
  local config = {
    relative = "editor",
    row = math.max(0, bottom - #lines),
    col = math.max(0, vim.o.columns - width - 2),
    width = math.max(1, width),
    height = #lines,
  }
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, config)
  else
    state.win = vim.api.nvim_open_win(state.buf, false, vim.tbl_extend("force", config, {
      style = "minimal",
      focusable = false,
      noautocmd = true,
      zindex = 250,
    }))
    vim.wo[state.win].winhighlight = "Normal:Normal,NormalFloat:Normal"
  end
end

--- Have the kitten give you a paw, for a file called `name` (default: the
--- current buffer's).
---@param name? string
function M.paw(name)
  M.stop()
  local file = vim.api.nvim_buf_get_name(0)
  name = name or (file ~= "" and vim.fn.fnamemodify(file, ":t") or "[No Name]")
  state = { buf = vim.api.nvim_create_buf(false, true), win = -1, timer = -1, for_buf = vim.api.nvim_get_current_buf() }
  vim.bo[state.buf].bufhidden = "wipe"
  vim.on_key(function()
    -- Any key: let it through, and the kitten goes away.
    vim.schedule(M.stop)
  end, ns)
  local frames = M.frames(name)
  local i = 0
  local function step()
    if not state then return end
    i = i + 1
    if i > #frames then
      M.stop()
      vim.api.nvim_echo(M.summary(name), false, {})
      return
    end
    draw(frames[i][1])
    state.timer = vim.fn.timer_start(frames[i][2], step)
  end
  step()
end

-- ── On save ─────────────────────────────────────────────────────────────

--- Whether a save of buffer `buf` should show the kitten.
function M.should_play(buf)
  return vim.g.kitten_on_save ~= false
    and #vim.api.nvim_list_uis() > 0
    and vim.fn.reg_executing() == ""
    and vim.v.exiting == vim.NIL
    and vim.bo[buf].buftype == ""
    and buf == vim.api.nvim_get_current_buf()
    -- a formatter or plugin that saves again right after: one paw is enough
    and not (state and state.for_buf == buf)
end

function M.declare() end

function M.setup()
  define_highlights()
  local group = vim.api.nvim_create_augroup("config-kitten", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = define_highlights })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    desc = "A kitten gives you a paw",
    callback = function(ev)
      if M.should_play(ev.buf) then M.paw() end
    end,
  })
  vim.api.nvim_create_user_command("KittenPaw", function() M.paw() end, { desc = "A kitten gives you a paw" })
  -- A plain toggle: Snacks.toggle would load its module at startup (~1 ms).
  vim.keymap.set("n", "<leader>uk", function()
    vim.g.kitten_on_save = vim.g.kitten_on_save == false
    vim.notify("Kitten on save: " .. (vim.g.kitten_on_save and "on" or "off"))
  end, { desc = "Toggle kitten on save" })
end

return M
