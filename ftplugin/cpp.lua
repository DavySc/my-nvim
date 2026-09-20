-- C / C++ (ftplugin/c.lua sources this file).
--
-- Two build paths, deliberately kept apart:
--   :make      -- compile just this buffer, for scratch files and single-file
--                exercises. See lua/config/cmake.lua for the project path.
--   :CMake ... -- configure/build/run/debug the surrounding CMake project.
-- <leader>mm picks whichever applies to the current buffer.

local cmake = require("config.cmake")

vim.bo.commentstring = "// %s"
vim.bo.comments = "sO:* -,mO:*  ,exO:*/,s1:/*,mb:*,ex:*/,://"

-- `gf` on an #include line.
vim.bo.include = [[^\s*#\s*include]]
vim.opt_local.path:append({ "include", "src", "/usr/include", "/usr/local/include" })

-- Treesitter folds; start with everything open.
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldlevel = 99

local is_c = vim.bo.filetype == "c"
local is_win = vim.fn.has("win32") == 1

--- First toolchain on PATH: gcc, clang, then (Windows) MSVC's cl.
local function pick_compiler()
  for _, name in ipairs(is_c and { "gcc", "clang", "cl" } or { "g++", "clang++", "cl" }) do
    if vim.fn.executable(name) == 1 then
      return name
    end
  end
  return is_c and "gcc" or "g++"
end

local compiler = vim.g.cpp_compiler or pick_compiler()
local msvc = compiler == "cl"
local flags = vim.g.cpp_flags
  or (msvc and { "/nologo", is_c and "/std:clatest" or "/std:c++latest", "/W4", "/Zi", "/EHsc" } or {
    is_c and "-std=c23" or "-std=c++23",
    "-Wall",
    "-Wextra",
    "-g",
  })

--- Where a single-file build lands: out of the source tree, keyed by full path
--- so two main.cpp in different directories can't collide.
---@param file string
---@return string
local function scratch_binary(file)
  local dir = vim.fn.stdpath("cache") .. "/cpp"
  vim.fn.mkdir(dir, "p")
  return dir .. "/" .. vim.fn.fnamemodify(file, ":t:r") .. "-" .. vim.fn.sha256(file):sub(1, 8) .. (is_win and ".exe" or "")
end

--- Compiler invocation that turns `file` into a standalone executable.
---@param file string
---@return string[]
local function compile_cmd(file)
  local cmd = vim.list_extend({ compiler }, vim.deepcopy(flags))
  local out = scratch_binary(file)
  if msvc then
    -- cl litters the cwd with .obj/.pdb unless told where they go.
    return vim.list_extend(cmd, { file, "/Fe:" .. out, "/Fo:" .. out .. ".obj", "/Fd:" .. out .. ".pdb" })
  end
  return vim.list_extend(cmd, { file, "-o", out })
end

-- `:make` builds the current file alone, so <leader>md has something to
-- attach to even without a CMake project.
if vim.api.nvim_buf_get_name(0) ~= "" then
  vim.bo.makeprg = table.concat(vim.tbl_map(vim.fn.fnameescape, compile_cmd(vim.api.nvim_buf_get_name(0))), " ")
end

--- Compile the current buffer on its own and run the result in a terminal.
---@param args string[] forwarded to the program
local function cpp_run(args)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("cpp: buffer is not backed by a file", vim.log.levels.ERROR)
  end
  if vim.bo.modified then
    vim.cmd.write()
  end

  vim.notify("cpp: compiling " .. vim.fs.basename(file))
  vim.system(compile_cmd(file), { text = true }, vim.schedule_wrap(function(res)
    if res.code ~= 0 then
      local lines = vim.split((res.stderr or "") .. (res.stdout or ""), "\n", { trimempty = true })
      vim.fn.setqflist({}, " ", { title = "cpp", lines = lines, efm = vim.o.errorformat })
      vim.cmd("botright copen")
      return vim.notify("cpp: compilation failed", vim.log.levels.ERROR)
    end
    local run = vim.list_extend({ scratch_binary(file) }, args or {})
    Snacks.terminal.open(run, {
      cwd = vim.fs.dirname(file),
      win = { position = "bottom", height = 0.35 },
    })
  end))
end

vim.api.nvim_buf_create_user_command(0, "CppRun", function(opts)
  cpp_run(opts.fargs)
end, { nargs = "*", desc = "Compile and run the current file on its own" })

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = 0, silent = true, desc = desc })
end

--- Project build when there is a CMakeLists.txt above us, single file otherwise.
local function build()
  if cmake.project() then
    vim.cmd("CMake build")
  else
    vim.cmd.make()
  end
end

local function run()
  if cmake.project() then
    vim.cmd("CMake run")
  else
    cpp_run({})
  end
end

local function debug()
  local p = cmake.project()
  if p then
    return cmake.debug(p, {})
  end
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("cpp: buffer is not backed by a file", vim.log.levels.ERROR)
  end
  require("dap").run({
    name = "Debug " .. vim.fs.basename(file),
    type = "codelldb",
    request = "launch",
    program = scratch_binary(file),
    cwd = vim.fs.dirname(file),
    stopOnEntry = false,
    console = "integratedTerminal",
  })
end

map("<leader>mm", build, "C++: build")
map("<leader>mr", run, "C++: run")
map("<leader>md", debug, "C++: debug")
map("<leader>mg", "<cmd>CMake configure<cr>", "C++: configure")
map("<leader>mt", "<cmd>CMake target<cr>", "C++: select target")
map("<leader>mb", "<cmd>CMake type<cr>", "C++: select build type")
-- Both commands are created by nvim-lspconfig's clangd config on attach.
map("<leader>ma", "<cmd>LspClangdSwitchSourceHeader<cr>", "C++: alternate source/header")
map("<leader>ms", "<cmd>LspClangdShowSymbolInfo<cr>", "C++: symbol info")

vim.b.undo_ftplugin = table.concat({
  "setlocal commentstring< comments< include< path< makeprg<",
  "setlocal foldmethod< foldexpr< foldlevel<",
  "silent! delcommand -buffer CppRun",
  "silent! nunmap <buffer> <leader>mm",
  "silent! nunmap <buffer> <leader>mr",
  "silent! nunmap <buffer> <leader>md",
  "silent! nunmap <buffer> <leader>mg",
  "silent! nunmap <buffer> <leader>mt",
  "silent! nunmap <buffer> <leader>mb",
  "silent! nunmap <buffer> <leader>ma",
  "silent! nunmap <buffer> <leader>ms",
}, " | ")
