-- Markdown: soft-wrap prose at the window edge, on word boundaries, with
-- wrapped lines indented like their first line (so list items read as lists).
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true

vim.b.undo_ftplugin = "setlocal wrap< linebreak< breakindent<"
