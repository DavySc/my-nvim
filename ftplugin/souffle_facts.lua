-- Soufflé fact files (.facts): one fact per line, columns separated by Tabs.
-- Keep a typed Tab a Tab (the config default is spaces) and show them.
vim.opt_local.expandtab = false
vim.opt_local.softtabstop = 0
vim.opt_local.tabstop = 16
vim.opt_local.list = true
vim.opt_local.listchars = "tab:→ ,trail:·"
vim.b.undo_ftplugin = "setlocal expandtab< softtabstop< tabstop< list< listchars<"
