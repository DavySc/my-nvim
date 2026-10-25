-- C and C++. Build/run keys live in ftplugin/cpp.lua (c.lua sources it), the
-- CMake driver in lua/config/cmake.lua.

local C_FAMILY = { "c", "cpp", "cuda", "objc", "objcpp" }

--- Executable to debug: the CMake target if this buffer is in a project,
--- otherwise ask. Runs inside dap's coroutine, so a blocking prompt is fine.
local function debug_program()
  local project = require("config.cmake").project()
  if project and project.target then
    return project.target.path
  end
  local made = not project and require("config.make").project()
  if made and made.program then
    return made.program
  end
  local dir = project and project.build or made and made.root or vim.uv.cwd()
  return vim.fn.input({ prompt = "Executable: ", default = dir .. "/", completion = "file" })
end

local CPP_EXT = { cpp = true, cc = true, cxx = true, ["c++"] = true, hpp = true, hh = true, hxx = true }
local CPP_MARKERS = { "^%s*class%s", "^%s*namespace[%s{]", "^%s*template%s*<", "std::", "^%s*using%s", "^%s*public:", "^%s*private:" }

--- Neovim opens every .h as C++ unless g:c_syntax_for_h is set. Decide per
--- header instead: a same-named .c or .cpp next to it, else which of the two
--- the directory holds (for include/: the project root and its src/), else
--- C++ syntax in the file, else C.
---@param path string
---@param bufnr integer
---@return string
local function header_filetype(path, bufnr)
  local dir, stem = vim.fs.dirname(path), vim.fn.fnamemodify(path, ":t:r")
  if vim.uv.fs_stat(dir .. "/" .. stem .. ".c") then return "c" end
  for ext in pairs(CPP_EXT) do
    if ext:sub(1, 1) ~= "h" and vim.uv.fs_stat(dir .. "/" .. stem .. "." .. ext) then return "cpp" end
  end
  local dirs = { dir }
  if ({ include = true, inc = true, headers = true })[vim.fs.basename(dir)] then
    local root = vim.fs.dirname(dir)
    vim.list_extend(dirs, { root, root .. "/src" })
  end
  for _, d in ipairs(dirs) do
    local c, cpp = 0, 0
    for name, kind in vim.fs.dir(d) do
      if kind == "file" then
        local ext = name:match("%.([^.]+)$")
        if ext == "c" then c = c + 1 elseif ext and CPP_EXT[ext] then cpp = cpp + 1 end
      end
    end
    if c > 0 and cpp == 0 then return "c" end
    if cpp > 0 and c == 0 then return "cpp" end
  end
  local objc = require("vim.filetype.detect").header(path, bufnr)
  if objc == "objc" or objc == "objcpp" then return objc end
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 200, false)) do
    for _, marker in ipairs(CPP_MARKERS) do
      if line:find(marker) then return "cpp" end
    end
  end
  return "c"
end

--- Compilers clangd may ask for their system include paths: those on PATH. A
--- compile_commands.json naming gcc or MinGW then gets the right headers
--- instead of clang's own (the usual "stdio.h not found" on Windows).
---@return string?
local function query_drivers()
  local found = {}
  for _, name in ipairs({ "gcc", "g++", "cc", "c++", "clang", "clang++", "arm-none-eabi-gcc", "arm-none-eabi-g++" }) do
    local path = vim.fn.exepath(name)
    if path ~= "" then found[#found + 1] = vim.fs.normalize(path) end
  end
  return #found > 0 and table.concat(found, ",") or nil
end

---@type Lang
return {
  ft = vim.list_extend({ "cmake" }, C_FAMILY),
  -- doxygen is injected into /** */ comments, printf into format strings,
  -- cmake/make for the build files.
  parsers = { "c", "cpp", "doxygen", "printf", "cmake", "make" },
  tools = { clangd = "clangd", ["clang-format"] = "clang-format", codelldb = "codelldb" },
  plugins = { "https://github.com/p00f/clangd_extensions.nvim" },
  declare = function()
    vim.filetype.add({ extension = { h = header_filetype } })
  end,
  setup = function()
    -- nvim-lspconfig supplies filetypes, root markers, the utf-8 offset
    -- encoding clangd prefers, and the :LspClangd* commands; the flags below
    -- are what it does not set.
    local drivers = query_drivers()
    vim.lsp.config("clangd", {
      cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--completion-style=detailed",
        "--all-scopes-completion",
        "--function-arg-placeholders",
        -- Insert the header the completed symbol lives in, honouring IWYU pragmas.
        "--header-insertion=iwyu",
        "--header-insertion-decorators",
        -- Without a compile_commands.json, format/parse as LLVM rather than bail.
        "--fallback-style=llvm",
        "--enable-config", -- honour .clangd files in the project
        "--pch-storage=memory",
        "-j=" .. math.max(2, math.floor(#(vim.uv.cpu_info() or {}) / 2)),
        drivers and ("--query-driver=" .. drivers) or nil,
      },
      init_options = {
        usePlaceholders = true,
        completeUnimported = true,
        clangdFileStatus = true,
        -- For files no compile_commands.json covers (scratch files, headers
        -- of a Makefile project without bear): warn like the :make build does.
        fallbackFlags = { "-Wall", "-Wextra" },
      },
    })
    require("config.core.lsp").enable({ "clangd" })

    -- :ClangdAST / :ClangdTypeHierarchy / :ClangdMemoryUsage. Inlay hints are
    -- native (<leader>uh), so the plugin's own renderer stays off.
    require("clangd_extensions").setup({ inlay_hints = { inline = false } })

    local format = require("config.core.format")
    local fmt = {}
    for _, ft in ipairs(C_FAMILY) do fmt[ft] = { "clang-format" } end
    format.add(fmt)
    -- clang-format always has an opinion: with no .clang-format in the tree it
    -- silently rewrites the whole file to LLVM style. Only format C/C++ on save
    -- when the project actually pins a style.
    format.guard(C_FAMILY, function(bufnr)
      local name = vim.api.nvim_buf_get_name(bufnr)
      local dir = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
      return vim.fs.find({ ".clang-format", "_clang-format" }, { path = dir, upward = true })[1] ~= nil
    end)

    local configs = {
      {
        name = "Launch (codelldb)",
        type = "codelldb",
        request = "launch",
        program = debug_program,
        cwd = "${workspaceFolder}",
        args = {},
        stopOnEntry = false,
        console = "integratedTerminal",
      },
      {
        name = "Launch (gdb)",
        type = "gdb",
        request = "launch",
        program = debug_program,
        cwd = "${workspaceFolder}",
        stopAtBeginningOfMainSubprogram = false,
      },
      {
        name = "Attach to process",
        type = "codelldb",
        request = "attach",
        pid = function() return require("dap.utils").pick_process() end,
        cwd = "${workspaceFolder}",
      },
    }
    require("config.core.dap").configure({ "c", "cpp" }, configs)

    require("config.cmake").setup()
  end,
}
