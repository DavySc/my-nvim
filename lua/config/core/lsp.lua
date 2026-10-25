-- LSP plumbing shared by every language: mason, diagnostics, keymaps. The
-- servers themselves are configured and enabled by lua/lang/*.lua when their
-- filetype is first opened (vim.lsp.config defaults come from nvim-lspconfig).

local lazy = require("config.lazy")

local M = {}

function M.declare()
  lazy.add({ src = "https://github.com/neovim/nvim-lspconfig", lazy = false })
  -- Eager but cheap: setup() only puts mason's bin/ on PATH so servers resolve.
  lazy.add({
    src = "https://github.com/williamboman/mason.nvim",
    lazy = false,
    config = function() require("mason").setup() end,
  })
end

--- Make a fresh machine (Windows especially) self-sufficient: install any tool
--- that isn't already on PATH. Runs async after startup; restart nvim once it
--- finishes.
---@param tools table<string, string> mason package -> executable it provides
function M.ensure_tools(tools)
  if next(tools) == nil then return end
  vim.defer_fn(function()
    local ok, registry = pcall(require, "mason-registry")
    if not ok then return end
    registry.refresh(function()
      for name, exe in pairs(tools) do
        if vim.fn.executable(exe) == 0 then
          local found, pkg = pcall(registry.get_package, name)
          if found and not pkg:is_installed() and not pkg:is_installing() then
            vim.notify("mason: installing " .. name)
            pkg:install()
          end
        end
      end
    end)
  end, 1000)
end

--- An LSP `cmd` that runs `cmd` through `nix develop` when the project root
--- has a flake.nix (and nvim isn't already in a dev shell), so the server
--- matches the flake's toolchain; plain PATH otherwise.
---@param cmd string[]
function M.flake_cmd(cmd)
  return function(dispatchers, config)
    local root = config.root_dir
    local full = vim.deepcopy(cmd)
    if root and not vim.env.IN_NIX_SHELL and vim.uv.fs_stat(root .. "/flake.nix") then
      full = vim.list_extend({ "nix", "develop", root, "--command" }, full)
    end
    return vim.lsp.rpc.start(full, dispatchers, { cwd = root })
  end
end

--- Enable servers (call from a language's setup). Loads completion first so
--- the servers start with its capabilities.
---@param names string[]
function M.enable(names)
  require("config.core.completion").load()
  vim.lsp.enable(names)
end

function M.setup()
  -- clang-tidy findings are worth reading inline; the default only shows signs.
  vim.diagnostic.config({
    virtual_text = { spacing = 2, source = "if_many", prefix = "●" },
    severity_sort = true,
    underline = true,
    float = { border = "rounded", source = "if_many" },
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    desc = "LSP keymaps",
    callback = function(ev)
      local opts = { buffer = ev.buf, silent = true }
      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
      vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)

      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client:supports_method("textDocument/inlayHint") then
        vim.keymap.set("n", "<leader>uh", function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
        end, vim.tbl_extend("force", opts, { desc = "Toggle inlay hints" }))
      end
    end,
  })
end

return M
