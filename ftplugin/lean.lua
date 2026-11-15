-- Lean 4: build, run and search keys (lua/config/lean.lua). lean.nvim's own
-- ftplugin sets indenting, comments and its <LocalLeader> keys; this file
-- must not set b:did_ftplugin, or lean.nvim's would skip itself.
--   <leader>mm  lake build: errors and warnings to the quickfix list
--   <leader>mr  run this file's main (lake env lean --run)
--   <leader>mc  lake exe cache get: prebuilt Mathlib
--   :Lake ...   any lake command in a terminal at the project root
--   \u  unicode symbol picker     \l  Loogle (Mathlib search)
--   \/  grep core Lean + deps     \f  files in core Lean + deps
--   \S  a `· sorry` per open goal below this line (lean.nvim's :LeanSorryFill)

local lean = function(fn, ...)
  local args = { ... }
  return function() require("config.lean")[fn](unpack(args)) end
end

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = 0, silent = true, desc = desc })
end
map("<leader>mm", lean("build"), "Lean: lake build (quickfix)")
map("<leader>mr", lean("run_file"), "Lean: run this file's main")
map("<leader>mc", lean("lake", { "exe", "cache", "get" }), "Lean: get prebuilt Mathlib (cache get)")
map("<localleader>u", lean("pick_unicode"), "Lean: unicode symbol picker")
map("<localleader>l", lean("loogle"), "Lean: Loogle search")
map("<localleader>/", lean("grep_library"), "Lean: grep core Lean and dependencies")
map("<localleader>f", lean("files_library"), "Lean: files in core Lean and dependencies")
map("<localleader>S", "<cmd>LeanSorryFill<cr>", "Lean: a sorry per open goal")

local SUBCOMMANDS = { "build", "update", "exe", "test", "clean", "env", "lint", "check-test", "script", "serve", "new", "init" }
vim.api.nvim_buf_create_user_command(0, "Lake", function(opts)
  require("config.lean").lake(opts.fargs)
end, {
  nargs = "+",
  complete = function(arg, line)
    if #vim.split(line, "%s+", { trimempty = true }) > (arg == "" and 1 or 2) then return {} end
    return vim.tbl_filter(function(s) return vim.startswith(s, arg) end, SUBCOMMANDS)
  end,
  desc = "Run lake in a terminal at the project root",
})

vim.b.undo_ftplugin = (vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | ") or "")
  .. "silent! delcommand -buffer Lake"
  .. " | silent! nunmap <buffer> <leader>mm | silent! nunmap <buffer> <leader>mr | silent! nunmap <buffer> <leader>mc"
  .. " | silent! nunmap <buffer> <localleader>u | silent! nunmap <buffer> <localleader>l"
  .. " | silent! nunmap <buffer> <localleader>/ | silent! nunmap <buffer> <localleader>f"
  .. " | silent! nunmap <buffer> <localleader>S"
