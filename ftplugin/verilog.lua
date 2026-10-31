-- Verilog / SystemVerilog (ftplugin/systemverilog.lua sources this file).
-- verible (lua/lang/verilog.lua) does LSP and formatting; this adds the
-- simulate loop for the nand2tetris chips:
--   :make        -- verilator --lint-only on this file (quickfix)
--   :VerilogRun  -- iverilog this file (a testbench, usually) and run it with
--                   vvp in a terminal; compile errors go to the quickfix list
-- <leader>mm lints, <leader>mr runs. Neither tool comes from mason: install
-- verilator and iverilog (Icarus) yourself.

vim.bo.commentstring = "// %s"
vim.bo.comments = "sO:* -,mO:*  ,exO:*/,s1:/*,mb:*,ex:*/,://"

-- Treesitter folds; start with everything open.
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldlevel = 99

local is_sv = vim.bo.filetype == "systemverilog"

-- Verilator prints "%Error: file:line:col: msg" and
-- "%Warning-WIDTH: file:line:col: msg", then the offending source line and a
-- caret ruler, which the final %-G discards.
vim.bo.makeprg = "verilator --lint-only -Wall " .. (is_sv and "-sv " or "") .. "%:p"
vim.bo.errorformat = table.concat({
  "%%Error: %f:%l:%c: %m",
  "%%Error-%*[A-Z0-9_]: %f:%l:%c: %m",
  "%%Warning-%*[A-Z0-9_]: %f:%l:%c: %m",
  "%-G%.%#",
}, ",")

--- Where a compiled simulation lands: out of the source tree, keyed by full
--- path so two tb.v in different directories can't collide.
---@param file string
---@return string
local function sim_binary(file)
  local dir = vim.fn.stdpath("cache") .. "/verilog"
  vim.fn.mkdir(dir, "p")
  return dir .. "/" .. vim.fn.fnamemodify(file, ":t:r") .. "-" .. vim.fn.sha256(file):sub(1, 8) .. ".vvp"
end

--- Compile the current buffer with iverilog and run the result with vvp in a
--- terminal. Modules it instantiates are found through `-y` in the file's
--- directory, so a testbench next to its chips just works.
---@param args string[] forwarded to vvp (plusargs like +dump)
local function verilog_run(args)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("verilog: buffer is not backed by a file", vim.log.levels.ERROR)
  end
  if vim.bo.modified then
    vim.cmd.write()
  end
  local dir = vim.fs.dirname(file)
  local out = sim_binary(file)
  local cmd = { "iverilog", "-g2012", "-Wall", "-y", dir, "-I", dir, "-o", out, file }

  vim.notify("verilog: compiling " .. vim.fs.basename(file))
  vim.system(cmd, { text = true, cwd = dir }, vim.schedule_wrap(function(res)
    if res.code ~= 0 then
      -- iverilog: "file:line: error: msg" (or just "file:line: syntax error").
      local lines = vim.split((res.stderr or "") .. (res.stdout or ""), "\n", { trimempty = true })
      vim.fn.setqflist({}, " ", { title = "iverilog", lines = lines, efm = "%f:%l: %m" })
      vim.cmd("botright copen")
      return vim.notify("verilog: compilation failed", vim.log.levels.ERROR)
    end
    local run = vim.list_extend({ "vvp", out }, args or {})
    Snacks.terminal.open(run, {
      cwd = dir,
      win = { position = "bottom", height = 0.35 },
    })
  end))
end

vim.api.nvim_buf_create_user_command(0, "VerilogRun", function(opts)
  verilog_run(opts.fargs)
end, { nargs = "*", desc = "Compile the current file with iverilog and run it with vvp" })

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = 0, silent = true, desc = desc })
end

map("<leader>mm", "<cmd>make<cr>", "Verilog: lint (verilator)")
map("<leader>mr", "<cmd>VerilogRun<cr>", "Verilog: run (iverilog + vvp)")

vim.b.undo_ftplugin = table.concat({
  "setlocal commentstring< comments< foldmethod< foldexpr< foldlevel< makeprg< errorformat<",
  "silent! delcommand -buffer VerilogRun",
  "silent! nunmap <buffer> <leader>mm",
  "silent! nunmap <buffer> <leader>mr",
}, " | ")
