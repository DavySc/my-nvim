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
vim.opt.termguicolors = true
-- Spaces, four to a level: a Tab in a .sql or .sv file is a surprise in a diff.
-- Filetypes that need real Tabs (Makefiles, Soufflé fact files) set noexpandtab.
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.ignorecase = true -- /select finds SELECT; /Select only Select
vim.opt.smartcase = true
vim.opt.undofile = true -- undo survives a restart; :Undotree (<leader>uu) browses it
vim.opt.scrolloff = 6
vim.opt.inccommand = "split" -- :s shows its changes, and the lines they hit, as you type
vim.opt.virtualedit = "block" -- CTRL-V blocks may go past the ends of short lines
vim.opt.splitright = true
vim.opt.splitbelow = true
-- After startup: the clipboard provider check (and on Windows its tool) stays
-- out of the startup time.
vim.schedule(function() vim.opt.clipboard = "unnamedplus" end)

-- Keymaps
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>", { desc = "Source this file" })
-- Not <leader>x: that is the diagnostics prefix, and it would wait for a second key.
vim.keymap.set("n", "<leader>X", ":.lua<CR>", { desc = "Run line as Lua" })
vim.keymap.set("v", "<leader>X", ":lua<CR>", { desc = "Run selection as Lua" })
-- <leader>pv and :Ex open oil (lua/config/core/files.lua), which replaces netrw.

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

require("config")
