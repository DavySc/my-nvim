print("G'day sir!")

require("config.lazy")

vim.opt.shiftwidth = 4
-- execution keymaps
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>")
vim.keymap.set("n", "<space>x", ":.lua<CR>")
vim.keymap.set("v", "<space>x", ":.lua<CR>")
vim.keymap.set("n", "<leader>pv", ":Ex<CR>")

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wrap = false
vim.opt.clipboard = "unnamedplus"

-- 1. Remove the banner (cleaner view)
vim.g.netrw_banner = 0

-- 2. Tree View Style (3 = tree)
vim.g.netrw_liststyle = 3


vim.opt.termguicolors = true
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
      end,})
