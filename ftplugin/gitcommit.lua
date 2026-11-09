-- Commit messages (git commit and neogit's commit editor): Vim's own
-- gitcommit ftplugin wraps at 72; mark the column and check spelling, as
-- kittymax's git-commit-mode did.
vim.opt_local.colorcolumn = "+1"
vim.opt_local.spell = true
