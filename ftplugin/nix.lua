-- Nix. nixfmt (RFC style) uses two-space indents and never tabs.
vim.bo.shiftwidth = 2
vim.bo.softtabstop = 2
vim.bo.tabstop = 2
vim.bo.expandtab = true
vim.bo.commentstring = "# %s"

-- Treesitter folds; start with everything open.
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldlevel = 99

-- `gf` on relative imports like `./foo.nix` or `./dir` (-> dir/default.nix).
vim.opt_local.suffixesadd:append({ ".nix", "/default.nix" })

vim.b.undo_ftplugin = table.concat({
  "setlocal shiftwidth< softtabstop< tabstop< expandtab< commentstring<",
  "setlocal foldmethod< foldexpr< foldlevel< suffixesadd<",
}, " ")
