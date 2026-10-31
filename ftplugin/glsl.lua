-- GLSL. LSP and formatting are set up in lua/lang/glsl.lua.
vim.bo.commentstring = "// %s"
vim.bo.comments = "sO:* -,mO:*  ,exO:*/,s1:/*,mb:*,ex:*/,://"

-- Treesitter folds; start with everything open.
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldlevel = 99

vim.b.undo_ftplugin = "setlocal commentstring< comments< foldmethod< foldexpr< foldlevel<"
