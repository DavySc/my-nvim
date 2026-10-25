-- C support: header filetypes, Makefile projects, clangd flags.
--   nvim --headless -c 'luafile tests/c_test.lua'

local failures, passed = {}, 0
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failures[#failures + 1] = name .. (detail and (": " .. detail) or "")
  end
end

local root = vim.fn.tempname()
local function write(rel, lines)
  local path = root .. "/" .. rel
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
  return path
end
local function ft_of(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  return vim.bo.filetype
end

local function run()
  -- .h headers
  write("pair/foo.c", { "int x;" })
  check("header next to foo.c is C", ft_of(write("pair/foo.h", { "int f(void);" })) == "c")
  write("cxx/bar.cpp", { "int x;" })
  check("header next to bar.cpp is C++", ft_of(write("cxx/bar.h", { "int f();" })) == "cpp")
  write("lib/src/a.c", { "int x;" })
  check("include/ header of a C project is C", ft_of(write("lib/include/lib.h", { "int f(void);" })) == "c")
  check("lone header with a class is C++", ft_of(write("lone1/x.h", { "class X {", "};" })) == "cpp")
  check("lone plain header is C", ft_of(write("lone2/y.h", { "#pragma once", "int y(void);" })) == "c")

  -- clangd
  local cmd = vim.lsp.config.clangd and vim.lsp.config.clangd.cmd or {}
  local drivers
  for _, a in ipairs(type(cmd) == "table" and cmd or {}) do
    drivers = drivers or a:match("^%-%-query%-driver=(.*)")
  end
  if vim.fn.executable("gcc") == 1 then
    check("clangd may query gcc", drivers and drivers:find(vim.fs.normalize(vim.fn.exepath("gcc")), 1, true) ~= nil, drivers)
  end
  local init = vim.lsp.config.clangd and vim.lsp.config.clangd.init_options or {}
  check("clangd fallback flags", vim.deep_equal(init.fallbackFlags, { "-Wall", "-Wextra" }))

  -- A Makefile project
  if vim.fn.executable("make") == 0 or vim.fn.executable("cc") == 0 then return end
  write("mk/Makefile", { "app: main.c", "\tcc -Wall -o app main.c" })
  local main = write("mk/main.c", { "int main(void) { return undefined_thing; }" })
  vim.cmd.edit(vim.fn.fnameescape(main))
  check(":make runs make in the project", vim.bo.makeprg:find("make %-C ") ~= nil, vim.bo.makeprg)
  local make = require("config.make")
  local p = make.project()
  check("Makefile project found", p and p.root == vim.fs.normalize(root .. "/mk"), p and p.root)
  vim.fn.setqflist({}, " ", { title = "before" })
  vim.api.nvim_feedkeys(vim.keycode("<leader>mm"), "x", false)
  local function title() return vim.fn.getqflist({ title = 1 }).title end
  vim.wait(10000, function() return title():find("make") ~= nil end)
  check("<leader>mm builds with make", title():find("make") ~= nil, title())
  local qf = vim.fn.getqflist()
  check("compiler error in quickfix", #qf > 0 and vim.fs.basename(vim.api.nvim_buf_get_name(qf[1].bufnr)) == "main.c"
    and qf[1].lnum == 1, vim.inspect(qf[1]))

  vim.fn.writefile({ "int main(void) { return 0; }" }, main)
  local ok = false
  make.build(p, nil, function() ok = true end)
  vim.wait(10000, function() return ok end)
  check("fixed build succeeds", ok and vim.uv.fs_stat(root .. "/mk/app") ~= nil)
  p.program = root .. "/mk/app"
  local configs = require("dap").configurations.c or {}
  local program = configs[1] and configs[1].program
  check("dap launch uses the project's program", type(program) == "function" and program() == p.program)
end

local ok, err = xpcall(run, debug.traceback)
if not ok then failures[#failures + 1] = "crashed: " .. err end
vim.fn.delete(root, "rf")
io.stdout:write(("c: %d passed, %d failed\n"):format(passed, #failures))
for _, f in ipairs(failures) do io.stdout:write("  FAIL " .. f .. "\n") end
vim.cmd(#failures == 0 and "qa!" or "cquit!")
