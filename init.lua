print("G'day sir!")

require("config.lazy")

vim.opt.shiftwidth = 4
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
-- execution keymaps
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>")
vim.keymap.set("n", "<space>x", ":.lua<CR>")
vim.keymap.set("v", "<space>x", ":.lua<CR>")

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wrap = false

vim.opt.termguicolors = true
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
      end,})
