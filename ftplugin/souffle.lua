-- Soufflé (Datalog): the same make / run loop as Verilog.
--   :make        -- souffle checks and runs the program; errors go to the quickfix list
--   :SouffleRun  -- run it in a terminal: facts from the file's directory
--                   (-F), output relations printed (-D -), extra args passed on
-- <leader>mm makes, <leader>mr runs. souffle itself is not from mason.
-- The errorformat follows souffle's "Error: <msg> in file <f> at line <l>"
-- (written from its documentation, not yet checked against real output).

vim.bo.makeprg = "souffle -F %:p:h -D - %:p"
vim.bo.errorformat = table.concat({
  "%EError: %m in file %f at line %l",
  "%WWarning: %m in file %f at line %l",
  "%-G%.%#",
}, ",")

vim.api.nvim_buf_create_user_command(0, "SouffleRun", function(opts)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then return vim.notify("souffle: buffer is not backed by a file", vim.log.levels.ERROR) end
  if vim.bo.modified then vim.cmd.write() end
  local dir = vim.fs.dirname(file)
  local cmd = vim.list_extend({ "souffle", "-F", dir, "-D", "-", file }, opts.fargs)
  Snacks.terminal.open(cmd, { cwd = dir, win = { position = "bottom", height = 0.35 } })
end, { nargs = "*", desc = "Run this Soufflé program in a terminal" })

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = 0, silent = true, desc = desc })
end
map("<leader>mm", "<cmd>make<cr>", "Soufflé: check and run (quickfix)")
map("<leader>mr", "<cmd>SouffleRun<cr>", "Soufflé: run in a terminal")

vim.b.undo_ftplugin = "setlocal makeprg< errorformat< | silent! delcommand -buffer SouffleRun"
  .. " | silent! nunmap <buffer> <leader>mm | silent! nunmap <buffer> <leader>mr"
