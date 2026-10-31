-- Markdown: marksman for link/heading completion, references and diagnostics;
-- render-markdown.nvim draws headings, lists, tables and code blocks in the
-- buffer; prettier formats, but only through :Format (never on save: other
-- people's READMEs keep their wrapping). Buffer-local bits in
-- ftplugin/markdown.lua. The treesitter parsers are in the base set.

---@type Lang
return {
  ft = { "markdown" },
  tools = { marksman = "marksman", prettier = "prettier" },
  plugins = {
    {
      src = "https://github.com/MeanderingProgrammer/render-markdown.nvim",
      config = function() require("render-markdown").setup({}) end,
    },
  },
  setup = function()
    require("config.core.lsp").enable({ "marksman" })
    local format = require("config.core.format")
    format.add({ markdown = { "prettier" } })
    format.guard({ "markdown" }, function() return false end)
  end,
}
