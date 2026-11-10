-- SQL buffers, after Neovim's own ftplugin (whose ]] / [[ these replace).
--   iq / aq, ]] / [[   statements (config/sql_statements.lua)
--   gq{motion}         formats through conform: gqaq one statement, gqip a
--                      paragraph, gggqG the file (sqldiff or sqlfluff)
--   K                  dbbliss object info when the buffer has a connection,
--                      else LSP hover where a server runs, else nothing
local buf = vim.api.nvim_get_current_buf()
require("config.sql_statements").attach(buf)

vim.bo.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.keymap.set("n", "K", function()
  local ok, db = pcall(require, "dbbliss")
  local conn = ok and (db.connection_of and db.connection_of(0)) or nil
  if conn then return db.info() end
  if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/hover" }) > 0 then return vim.lsp.buf.hover() end
  vim.notify("K: no connection (:Dbbliss connect) and no language server here", vim.log.levels.INFO)
end, { buffer = buf, silent = true, desc = "Object info (dbbliss) / hover" })

local undo = "setlocal formatexpr< | silent! nunmap <buffer> K"
  .. " | silent! ounmap <buffer> iq | silent! xunmap <buffer> iq | silent! ounmap <buffer> aq | silent! xunmap <buffer> aq"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and vim.b.undo_ftplugin ~= "") and (vim.b.undo_ftplugin .. " | " .. undo) or undo
