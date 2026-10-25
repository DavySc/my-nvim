-- Lua (this config, Neovim plugins).

---@type Lang
return {
  ft = { "lua" },
  tools = { ["lua-language-server"] = "lua-language-server", stylua = "stylua" },
  setup = function()
    vim.lsp.config("lua_ls", {
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim", "Snacks" } },
          -- Every installed plugin, loaded or not, so lazy ones resolve too.
          workspace = {
            library = vim.list_extend(
              { vim.env.VIMRUNTIME },
              vim.fn.glob(vim.fn.stdpath("data") .. "/site/pack/core/opt/*", false, true)
            ),
            checkThirdParty = false,
          },
          telemetry = { enable = false },
        },
      },
    })
    require("config.core.format").add({ lua = { "stylua" } })
    require("config.core.lsp").enable({ "lua_ls" })
  end,
}
