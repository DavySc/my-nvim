-- Soufflé Datalog (*.dl)
-- Filetype is registered in lua/lang/souffle.lua; syntax/indent come from the
-- treesitter parser + queries/souffle/.

vim.bo.commentstring = "// %s"
vim.bo.comments = "s1:/*,mb:*,ex:*/,://"

-- `:make` type-checks the program without evaluating it. Souffle reports
--   Error: <msg> in file <file> at line <n>
-- and then echoes the offending source line plus a caret ruler, which the
-- final %-G discards.
vim.bo.makeprg = "souffle --parse-errors %:p"
vim.bo.errorformat = table.concat({
  "Error: %m in file %f at line %l",
  "Warning: %m in file %f at line %l",
  "%-G%.%#",
}, ",")

--- Show command output in a scratch split, reusing the window if it's open.
---@param name string
---@param lines string[]
local function show_output(name, lines)
  local buf = vim.fn.bufnr(name)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, name)
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].swapfile = false
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, buf)
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

--- Run the current program, printing every .output relation to the split.
---@param args string[]
local function souffle_run(args)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("souffle: buffer is not backed by a file", vim.log.levels.ERROR)
    return
  end
  if vim.bo.modified then
    vim.cmd.write()
  end

  -- Facts and #includes are resolved relative to the program by default.
  local dir = vim.fs.dirname(file)
  local cmd = { "souffle", "-F", dir, "-I", dir, "-D", "-" }
  vim.list_extend(cmd, args)
  table.insert(cmd, file)

  vim.notify("souffle: running " .. vim.fs.basename(file))
  vim.system(cmd, { text = true, cwd = dir }, function(res)
    vim.schedule(function()
      local out = vim.split((res.stdout or "") .. (res.stderr or ""), "\n", { trimempty = true })
      if #out == 0 then
        out = { "(no output — did you declare a .output relation?)" }
      end
      show_output("souffle://output", out)
      if res.code ~= 0 then
        vim.notify("souffle: exited " .. res.code, vim.log.levels.WARN)
      end
    end)
  end)
end

vim.api.nvim_buf_create_user_command(0, "Souffle", function(opts)
  souffle_run(opts.fargs)
end, { nargs = "*", desc = "Run the current Souffle program" })

local map = function(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = 0, silent = true, desc = desc })
end

map("<localleader>c", "<cmd>make<cr>", "Souffle: check")
map("<localleader>r", "<cmd>Souffle<cr>", "Souffle: run")

vim.b.undo_ftplugin = table.concat({
  "setlocal commentstring< comments< makeprg< errorformat<",
  "silent! delcommand -buffer Souffle",
  "silent! nunmap <buffer> <localleader>c",
  "silent! nunmap <buffer> <localleader>r",
}, " | ")
