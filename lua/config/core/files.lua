-- oil.nvim: the file manager, in place of netrw. What kittymax had with
-- dired + dirvish: a directory is a buffer of file names, edited with normal
-- vim motions; :w applies renames (edit a line), deletions (dd), new files and
-- directories (a line ending in /) and moves (cut and paste between oil
-- buffers). Icons from mini.icons, hidden files shown, sizes and dates on `gd`,
-- quick access to the usual places on `ga`, a preview on <C-p>.
--
-- It loads on `-`, :Oil, <leader>pv or :Ex, or when a directory is opened
-- (`nvim .`, :e some/dir), so startup doesn't pay for it.

local lazy = require("config.lazy")

local M = {}

--- Directories `ga` offers (kittymax's dirvish quick access).
M.quick_access = {
  { "~/", "Home" },
  { "~/Projects/", "Projects" },
  { "~/nixos-config/", "nixos-config" },
  { "~/.config/", "Config" },
}

local detail = false

local function toggle_detail()
  detail = not detail
  require("oil").set_columns(detail and { "icon", "permissions", "size", "mtime" } or { "icon" })
end

local function quick_access()
  local places = vim.tbl_filter(function(p) return vim.fn.isdirectory(vim.fn.expand(p[1])) == 1 end, M.quick_access)
  vim.ui.select(places, {
    prompt = "Go to",
    format_item = function(p) return ("%-14s %s"):format(p[2], p[1]) end,
  }, function(p)
    if p then require("oil").open(vim.fn.expand(p[1])) end
  end)
end

function M.declare()
  -- oil replaces netrw; stop netrw from claiming directories before oil loads.
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1
  lazy.add({
    src = "https://github.com/stevearc/oil.nvim",
    cmd = { "Oil" },
    config = function()
      if not _G.MiniIcons then require("mini.icons").setup() end
      require("oil").setup({
        default_file_explorer = true,
        columns = { "icon" },
        view_options = { show_hidden = true },
        watch_for_changes = true,
        keymaps = {
          ["gd"] = { callback = toggle_detail, desc = "Toggle sizes, dates and permissions" },
          ["ga"] = { callback = quick_access, desc = "Quick access: home, projects, config" },
          ["q"] = { "actions.close", mode = "n" },
        },
      })
    end,
  })
end

function M.setup()
  vim.keymap.set("n", "-", function() require("oil").open() end, { desc = "Open parent directory (oil)" })
  vim.keymap.set("n", "<leader>pv", function() require("oil").open() end, { desc = "File manager (oil)" })
  -- :Ex and :Explore were netrw's; keep the muscle memory.
  for _, name in ipairs({ "Ex", "Explore" }) do
    vim.api.nvim_create_user_command(name, function(o) require("oil").open(o.args ~= "" and o.args or nil) end, {
      nargs = "?",
      complete = "dir",
      desc = "File manager (oil)",
    })
  end
  -- A directory opened before oil is loaded (nvim ., :e dir): load it, and
  -- oil takes the buffer over as it starts.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("config-files", { clear = true }),
    callback = function(ev)
      if lazy.is_loaded("oil.nvim") then return true end -- oil handles it from here
      if ev.file ~= "" and vim.fn.isdirectory(ev.file) == 1 then
        lazy.load("oil.nvim")
        -- During startup oil renames the buffer and waits for Vim to read it,
        -- but this buffer has been read already: list it ourselves. (After
        -- startup oil does this itself.)
        if vim.v.vim_did_enter == 0 and vim.api.nvim_buf_get_name(ev.buf):find("^oil://") then
          require("oil").load_oil_buffer(ev.buf)
        end
        return true
      end
    end,
  })
end

return M
