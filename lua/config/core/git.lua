-- gitsigns: signs in the gutter + hunk actions on <leader>h (loaded with the
-- first file). snacks pickers: browse status/log/diff. neogit: the full
-- commit/push UI, loaded on <leader>gg or :Neogit.

local lazy = require("config.lazy")

local M = {}

function M.declare()
  lazy.add("https://github.com/nvim-lua/plenary.nvim")
  lazy.add({
    src = "https://github.com/lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        on_attach = function(buf)
          local gs = require("gitsigns")
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
          end
          map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
          map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")
          map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
          map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
          map("v", "<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage selection")
          map("v", "<leader>hr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset selection")
          map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
          map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
          map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
          map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
          map("n", "<leader>hd", gs.diffthis, "Diff against index")
          map("n", "<leader>ht", gs.toggle_current_line_blame, "Toggle inline blame")
          map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
        end,
      })
    end,
  })
  lazy.add({
    src = "https://github.com/NeogitOrg/neogit",
    cmd = { "Neogit*" },
    config = function() require("neogit").setup({ integrations = { diffview = false, snacks = true } }) end,
  })
end

function M.setup()
  vim.keymap.set("n", "<leader>gg", function() require("neogit").open() end, { desc = "Neogit (commit/push/…)" })
  vim.keymap.set("n", "<leader>gG", function() Snacks.lazygit() end, { desc = "Lazygit" })
  vim.keymap.set("n", "<leader>gs", function() Snacks.picker.git_status() end, { desc = "Git status" })
  vim.keymap.set("n", "<leader>gl", function() Snacks.picker.git_log() end, { desc = "Git log" })
  vim.keymap.set("n", "<leader>gL", function() Snacks.picker.git_log_file() end, { desc = "Git log (file)" })
  vim.keymap.set("n", "<leader>gd", function() Snacks.picker.git_diff() end, { desc = "Git diff (hunks)" })
  vim.keymap.set("n", "<leader>gb", function() Snacks.picker.git_branches() end, { desc = "Git branches" })
  vim.keymap.set("n", "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Open on GitHub" })
end

return M
