-- Multicursor keys (lua/config/core/multicursor.lua), Neovim 0.13+ only.
--   nvim --headless -c 'luafile tests/multicursor_test.lua'
-- Keys go through nvim_input: the cursor cascade runs on typed input, not
-- on feedkeys(…, "x").

if vim.fn.has("nvim-0.13") == 0 then
  io.stdout:write("multicursor: skipped (needs Neovim 0.13)\n")
  return vim.cmd("qa!")
end

local cases = {
  { "<C-n><C-n>ciwX<Esc>", "X bar X baz X" }, -- two added cursors + the primary
  { "<C-n>ciwX<Esc>", "X bar X baz foo" },
  { " MciwY<Esc>", "Y bar Y baz Y" },
}
local failures, i = {}, 0

local function next_case()
  i = i + 1
  local case = cases[i]
  if not case then
    io.stdout:write(("multicursor: %d passed, %d failed\n"):format(#cases - #failures, #failures))
    for _, f in ipairs(failures) do io.stdout:write("  FAIL " .. f .. "\n") end
    return vim.cmd(#failures == 0 and "qa!" or "cquit!")
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo bar foo baz foo" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_input(case[1])
  vim.defer_fn(function()
    local got = vim.api.nvim_get_current_line()
    if got ~= case[2] then failures[#failures + 1] = ("%s: got %q, want %q"):format(case[1], got, case[2]) end
    vim.api.nvim_input("<C-l>")
    vim.defer_fn(next_case, 200)
  end, 500)
end

vim.cmd("enew")
next_case()
