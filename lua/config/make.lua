-- Plain Makefile projects (no CMakeLists.txt): build with make, errors to the
-- quickfix list, then run or debug a program you name once per project. The
-- CMake driver (lua/config/cmake.lua) wins where both exist.
--
-- clangd needs a compile_commands.json, which make doesn't write. With bear
-- (https://github.com/rizsotto/Bear) on PATH, builds run as `bear --append --
-- make` and leave one in the project root. Without it, clangd falls back to
-- guessing flags, and the build says so once.

local M = {}

local MAKEFILES = { "GNUmakefile", "makefile", "Makefile" }

---@class MakeProject
---@field root string directory holding the Makefile
---@field program? string executable that run/debug start

---@type table<string, MakeProject>
local projects = {}
local warned_bear = false

--- The make program: make, else MinGW's mingw32-make (Windows).
---@return string?
function M.exe()
  for _, name in ipairs({ "make", "mingw32-make" }) do
    if vim.fn.executable(name) == 1 then return name end
  end
end

--- The project of the nearest Makefile above the buffer, if any.
---@param bufnr? integer
---@return MakeProject?
function M.project(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  local dir = name ~= "" and vim.fs.dirname(name) or assert(vim.uv.cwd())
  local found = vim.fs.find(MAKEFILES, { path = dir, upward = true, type = "file" })[1]
  if not found then return nil end
  local root = vim.fs.dirname(found)
  projects[root] = projects[root] or { root = root }
  return projects[root]
end

--- The build command, as a list: bear around make when bear is there.
---@param p MakeProject
---@param args? string[] make arguments (targets, VAR=value)
---@return string[]?
function M.command(p, args)
  local make = M.exe()
  if not make then return nil end
  local cmd = { make }
  if vim.fn.executable("bear") == 1 then
    cmd = { "bear", "--append", "--output", p.root .. "/compile_commands.json", "--", make }
  end
  return vim.list_extend(cmd, args or {})
end

---@param p MakeProject
---@param args? string[]
---@param on_success? fun()
function M.build(p, args, on_success)
  local cmd = M.command(p, args)
  if not cmd then
    return vim.notify("make: neither make nor mingw32-make is on PATH", vim.log.levels.ERROR)
  end
  if cmd[1] ~= "bear" and not warned_bear and not vim.uv.fs_stat(p.root .. "/compile_commands.json") then
    warned_bear = true
    vim.notify("make: no compile_commands.json; install bear for clangd to see the real flags", vim.log.levels.WARN)
  end
  vim.notify("make: building " .. vim.fs.basename(p.root) .. "...")
  vim.system(cmd, { cwd = p.root, text = true }, vim.schedule_wrap(function(res)
    local out = vim.split((res.stdout or "") .. (res.stderr or ""), "\n", { trimempty = true })
    -- The default 'errorformat' knows gcc, clang and make's directory changes.
    local items = vim.tbl_filter(
      function(item) return item.valid == 1 end,
      vim.fn.getqflist({ lines = out, efm = vim.o.errorformat }).items
    )
    vim.fn.setqflist({}, " ", { title = table.concat(cmd, " "), items = items })
    if #items > 0 then vim.cmd("botright copen") else vim.cmd("cclose") end
    if res.code ~= 0 then
      return vim.notify(("make: build failed (exit %d)"):format(res.code), vim.log.levels.ERROR)
    end
    vim.notify("make: build ok")
    if on_success then on_success() end
  end))
end

--- The program to run or debug, asked for once per project.
---@param p MakeProject
---@param cb fun(program: string)
function M.with_program(p, cb)
  if p.program then return cb(p.program) end
  vim.ui.input({ prompt = "Program: ", default = p.root .. "/", completion = "file" }, function(path)
    if not path or path == "" then return end
    p.program = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
    cb(p.program)
  end)
end

---@param p MakeProject
function M.select_program(p)
  p.program = nil
  M.with_program(p, function(path) vim.notify("make: program " .. path) end)
end

---@param p MakeProject
---@param args? string[] forwarded to the program
function M.run(p, args)
  M.build(p, nil, function()
    M.with_program(p, function(program)
      if not vim.uv.fs_stat(program) then
        return vim.notify("make: " .. program .. " does not exist", vim.log.levels.ERROR)
      end
      Snacks.terminal.open(vim.list_extend({ program }, args or {}), {
        cwd = p.root,
        win = { position = "bottom", height = 0.35 },
      })
    end)
  end)
end

---@param p MakeProject
---@param args? string[] forwarded to the program
function M.debug(p, args)
  local dap = require("dap")
  if not dap.adapters.codelldb then
    return vim.notify("make: codelldb not installed (:MasonInstall codelldb)", vim.log.levels.ERROR)
  end
  M.build(p, nil, function()
    M.with_program(p, function(program)
      dap.run({
        name = "make: " .. vim.fs.basename(program),
        type = "codelldb",
        request = "launch",
        program = program,
        cwd = p.root,
        args = args or {},
        stopOnEntry = false,
        console = "integratedTerminal",
      })
    end)
  end)
end

return M
