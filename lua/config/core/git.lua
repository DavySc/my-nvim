-- gitsigns: signs in the gutter + hunk actions on <leader>h (loaded with the
-- first file). snacks pickers: browse status/log/diff. neogit: magit, set up
-- the way kittymax had magit (in the window you're in, saving the repo's
-- buffers first, word-level diff highlights, diffs and commits beside it),
-- loaded on <leader>gg or :Neogit. diffview: magit-style diffs inside neogit,
-- and a file's history on <leader>gh (kittymax's git-timemachine).

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
    src = "https://github.com/sindrets/diffview.nvim",
    cmd = { "Diffview*" },
    config = function() require("diffview").setup({ enhanced_diff_hl = true }) end,
  })
  lazy.add({
    src = "https://github.com/NeogitOrg/neogit",
    cmd = { "Neogit*" },
    config = function()
      require("neogit").setup({
        -- magit-display-buffer-same-window-except-diff: status, logs and the
        -- commit message take this window; diffs and commits open beside it.
        kind = "replace",
        commit_editor = { kind = "replace", show_staged_diff = true, staged_diff_split_kind = "vsplit", spell_check = true },
        commit_view = { kind = "vsplit" },
        log_view = { kind = "replace" },
        reflog_view = { kind = "replace" },
        commit_select_view = { kind = "replace" },
        graph_style = "unicode",
        word_diff_highlight = true, -- magit-diff-refine-hunk 'all
        integrations = { diffview = true, snacks = true },
      })
    end,
  })
end

--- magit-save-repository-buffers 'dontask: save the modified files of the
--- current repository, without asking, before showing its status.
local function save_repository_buffers()
  local root = vim.fs.root(0, ".git")
  if not root then return end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].modified and vim.bo[buf].buftype == "" and name ~= ""
      and vim.fs.relpath(root, name) ~= nil then
      vim.api.nvim_buf_call(buf, function() vim.cmd("silent! write") end)
    end
  end
end

function M.status()
  save_repository_buffers()
  require("neogit").open()
end

function M.setup()
  vim.keymap.set("n", "<leader>gg", M.status, { desc = "Neogit (magit)" })
  vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history (diffview)" })
  vim.keymap.set("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>", { desc = "Repository history (diffview)" })
  vim.keymap.set("n", "<leader>gs", function() Snacks.picker.git_status() end, { desc = "Git status" })
  vim.keymap.set("n", "<leader>gl", function() Snacks.picker.git_log() end, { desc = "Git log" })
  vim.keymap.set("n", "<leader>gL", function() Snacks.picker.git_log_file() end, { desc = "Git log (file)" })
  vim.keymap.set("n", "<leader>gd", function() Snacks.picker.git_diff() end, { desc = "Git diff (hunks)" })
  vim.keymap.set("n", "<leader>gb", function() Snacks.picker.git_branches() end, { desc = "Git branches" })
  vim.keymap.set("n", "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Open on GitHub" })
end

return M
