-- Souffle datalog (*.dl). No plugin needed: filetype and treesitter grammar
-- are registered here, queries live in queries/souffle/, buffer-local bits in
-- ftplugin/souffle.lua.

---@type Lang
return {
  ft = { "souffle" },
  parsers = { "souffle" },
  declare = function()
    vim.filetype.add({ extension = { dl = "souffle" } })
    require("config.core.treesitter").register("souffle", {
      install_info = {
        url = "https://github.com/langston-barrett/tree-sitter-souffle",
        revision = "0ca94fad4422bc9a391f81418b5716e3af00ed2f",
      },
      tier = 3,
    })
  end,
}
