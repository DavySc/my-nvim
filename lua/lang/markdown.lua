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
      config = function()
        -- Hide the # markers entirely (empty icons overlay them with blanks);
        -- the heading highlight colours alone show the level.
        require("render-markdown").setup({ heading = { icons = { "", "", "", "", "", "" } } })
      end,
    },
  },
  declare = function()
    -- Heading folds from Neovim's markdown ftplugin (ftplugin/markdown.lua opens them).
    vim.g.markdown_folding = 1
  end,
  setup = function()
    require("config.core.lsp").enable({ "marksman" })
    -- Prose: links and headings from marksman, paths and snippets; buffer words
    -- only from the fourth letter, so a sentence doesn't pop a menu per letter.
    require("config.core.completion").source(
      "markdown",
      { { name = "nvim_lsp" }, { name = "path" }, { name = "luasnip" } },
      { { name = "buffer", keyword_length = 4 } }
    )
    local format = require("config.core.format")
    -- "injected": each fenced block through its own formatter (SQL via sqldiff).
    format.add({ markdown = { "prettier", "injected" } })
    format.guard({ "markdown" }, function() return false end)
  end,
}
