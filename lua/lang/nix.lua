-- Nix. Buffer-local settings live in ftplugin/nix.lua.

---@type Lang
return {
  ft = { "nix" },
  parsers = { "nix" },
  tools = { ["nil"] = "nil", nixfmt = "nixfmt" },
  setup = function()
    -- `nil` (mason has no nixd) gives diagnostics, completion, go-to-def and
    -- rename. Formatting is left to conform (nixfmt), so nil's own is unused.
    vim.lsp.config("nil_ls", {
      settings = { ["nil"] = { formatting = { command = { "nixfmt" } } } },
    })
    require("config.core.format").add({ nix = { "nixfmt" } })
    require("config.core.lsp").enable({ "nil_ls" })
  end,
}
