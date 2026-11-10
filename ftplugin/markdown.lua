-- Markdown: soft-wrap prose at the window edge, on word boundaries, with
-- wrapped lines indented like their first line (so list items read as lists).
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true

-- Spelling: ]s / [s to the next mistake, z= for suggestions, zg to accept a
-- word. Languages per machine: spelllang in lua/local.lua.
vim.opt_local.spell = true
vim.opt_local.spelllang = require("config.machine").spelllang

-- Headings fold (g:markdown_folding, set in lang/markdown.lua): zM shows the
-- outline, zR everything, za one section. Open at first. gO lists the headings
-- and ]] / [[ jump between them (Neovim's own ftplugin).
vim.opt_local.foldlevel = 99

local buf = vim.api.nvim_get_current_buf()

-- j / k move by screen line in wrapped prose; with a count (5j, as relative
-- numbers show) they still move by real lines.
vim.keymap.set({ "n", "x" }, "j", "v:count ? 'j' : 'gj'", { buffer = buf, expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "k", "v:count ? 'k' : 'gk'", { buffer = buf, expr = true, silent = true })

require("config.markdown_lists").attach(buf)

vim.keymap.set("n", "<leader>ce", function() require("config.edit_block").open() end,
  { buffer = buf, desc = "Edit code block in its own buffer" })

vim.b.undo_ftplugin = (vim.b.undo_ftplugin and vim.b.undo_ftplugin ~= "" and (vim.b.undo_ftplugin .. " | ") or "")
  .. "setlocal wrap< linebreak< breakindent< spell< spelllang< foldlevel<"
  .. " | silent! nunmap <buffer> j | silent! nunmap <buffer> k | silent! xunmap <buffer> j | silent! xunmap <buffer> k"
  .. " | silent! iunmap <buffer> <CR> | silent! nunmap <buffer> o | silent! nunmap <buffer> <leader>ce"
