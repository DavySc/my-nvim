-- Neovim 0.13's built-in multiple cursors (:help multicursor). The core keys
-- need no setup: Q toggles a cursor, zq{motion} places one per match, q=
-- toggles follow mode, CTRL-L clears, gQ restores, ]C / [C jump between.
-- This adds a VS Code style <C-n> and which-key labels. Nothing on 0.12.

local M = {}

function M.declare() end

function M.setup()
  if vim.fn.has("nvim-0.13") == 0 then return end
  local ns = vim.api.nvim_create_namespace("nvim.multicursor")

  -- <C-n>: put a cursor on the word under the cursor and move to its next
  -- match; press again to keep adding. Same as VS Code's Ctrl-D. The primary
  -- cursor is always on the newest match, so "c", "ciw" etc. edit them all.
  vim.keymap.set("n", "<C-n>", function()
    local word = vim.fn.expand("<cword>")
    if word == "" then return end
    local pattern = "\\<" .. vim.fn.escape(word, "\\/.*$^~[]") .. "\\>"
    if vim.fn.getreg("/") ~= pattern then
      vim.fn.setreg("/", pattern)
      vim.fn.histadd("search", pattern)
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_extmark(0, ns, row - 1, col, {})
    -- Follow mode off, so only the primary cursor moves.
    vim.cmd("silent! normal! 2q=n")
  end, { desc = "Multicursor: add at word, go to next match" })

  -- All at once: a cursor on every match of the word ("zq*", easier to find).
  vim.keymap.set("n", "<leader>M", "zq*", { desc = "Multicursor: every match of word" })
end

return M
