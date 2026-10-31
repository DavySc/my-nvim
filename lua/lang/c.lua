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
  local dir = project and project.build or vim.uv.cwd()
  return vim.fn.input({ prompt = "Executable: ", default = dir .. "/", completion = "file" })
end

--- Whether a .clang-format governs `bufnr`. clang-format always has an
--- opinion: with no config in the tree it silently rewrites the whole file to
--- LLVM style, so C/C++ (and GLSL, lua/lang/glsl.lua) only format on save
--- when the project actually pins a style.
---@param bufnr integer
---@return boolean
local function has_clang_format(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
  return vim.fs.find({ ".clang-format", "_clang-format" }, { path = dir, upward = true })[1] ~= nil
end

---@type Lang
return {
  ft = vim.list_extend({ "cmake" }, C_FAMILY),
  has_clang_format = has_clang_format,
  -- doxygen is injected into /** */ comments, printf into format strings,
  -- cmake/make for the build files.
  parsers = { "c", "cpp", "doxygen", "printf", "cmake", "make" },
  tools = { clangd = "clangd", ["clang-format"] = "clang-format", codelldb = "codelldb" },
  plugins = { "https://github.com/p00f/clangd_extensions.nvim" },
  setup = function()
    -- nvim-lspconfig supplies filetypes, root markers, the utf-8 offset
    -- encoding clangd prefers, and the :LspClangd* commands; the flags below
    -- are what it does not set.
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
      },
      init_options = {
        usePlaceholders = true,
        completeUnimported = true,
        clangdFileStatus = true,
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
    format.guard(C_FAMILY, has_clang_format)

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
