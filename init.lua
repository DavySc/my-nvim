-- For the dashboard's "loaded in" line (config/core/ui.lua).
local reloading = vim.g.config_start_ns ~= nil -- lua/config/core/reload.lua
vim.g.config_start_ns = vim.g.config_start_ns or vim.uv.hrtime()

-- Byte-compile cache for Lua modules: a free few milliseconds per start.
vim.loader.enable()

if not reloading then print("G'day sir!") end

-- Leader must be set before plugins and keymaps
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wrap = false
vim.opt.clipboard = "unnamedplus"
vim.opt.shiftwidth = 4
vim.opt.termguicolors = true

-- netrw
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3

-- Keymaps
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>")
vim.keymap.set("n", "<space>x", ":.lua<CR>")
vim.keymap.set("v", "<space>x", ":.lua<CR>")
vim.keymap.set("n", "<leader>pv", ":Ex<CR>")

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

require("config")
