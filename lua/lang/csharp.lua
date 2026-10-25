-- C#, with Microsoft's Roslyn language server (the one VS Code's C# extension
-- uses) through roslyn.nvim, which adds solution picking (:Roslyn target)
-- and source-generated files on top of nvim-lspconfig's roslyn_ls.
-- Needs the .NET SDK (`dotnet` on PATH).

---@type Lang
return {
  ft = { "cs", "razor" },
  parsers = { "c_sharp" },
  tools = {
    ["roslyn-language-server"] = "roslyn-language-server",
    csharpier = "csharpier",
    netcoredbg = "netcoredbg",
  },
  -- Loading it enables the `roslyn` server (plugin/roslyn.lua).
  plugins = {
    { src = "https://github.com/seblyng/roslyn.nvim", config = function() require("roslyn").setup({}) end },
  },
  setup = function()
    vim.lsp.config("roslyn", {
      settings = {
        ["csharp|inlay_hints"] = {
          csharp_enable_inlay_hints_for_implicit_object_creation = true,
          csharp_enable_inlay_hints_for_implicit_variable_types = true,
        },
        ["csharp|code_lens"] = { dotnet_enable_references_code_lens = true },
      },
    })
    require("config.core.format").add({ cs = { "csharpier" } })

    require("config.core.dap").configure({ "cs" }, function()
      local dap = require("dap")
      local netcoredbg = vim.fn.exepath("netcoredbg")
      if netcoredbg ~= "" then
        dap.adapters.coreclr = { type = "executable", command = netcoredbg, args = { "--interpreter=vscode" } }
      end
      return {
        {
          name = "Launch (netcoredbg)",
          type = "coreclr",
          request = "launch",
          program = function()
            -- `dotnet build` first; bin/Debug/<tfm>/<Project>.dll is the usual answer.
            local root = vim.fs.root(0, function(name) return name:match("%.csproj$") ~= nil end) or vim.uv.cwd()
            return vim.fn.input({ prompt = "DLL: ", default = root .. "/bin/Debug/", completion = "file" })
          end,
        },
        {
          name = "Attach to process",
          type = "coreclr",
          request = "attach",
          processId = function() return require("dap.utils").pick_process() end,
        },
      }
    end)
  end,
}
