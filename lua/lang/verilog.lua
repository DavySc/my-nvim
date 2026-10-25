-- Verilog and SystemVerilog (and what Clash generates): verible for
-- diagnostics, formatting and navigation, one treesitter grammar for both.

---@type Lang
return {
  ft = { "verilog", "systemverilog" },
  parsers = { "systemverilog" },
  tools = { verible = "verible-verilog-ls" },
  declare = function()
    -- Neovim guesses between Verilog, V and Coq for .v by content (and picks
    -- V for a new file); only Verilog is written here.
    vim.filetype.add({ extension = { v = "verilog", vh = "verilog", svh = "systemverilog" } })
    vim.treesitter.language.register("systemverilog", { "verilog" })
  end,
  setup = function()
    require("config.core.format").add({
      verilog = { "verible" },
      systemverilog = { "verible" },
    })
    require("config.core.lsp").enable({ "verible" })
  end,
}
