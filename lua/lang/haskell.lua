-- Haskell (and Clash, which is plain Haskell under the hood). Build/run/REPL
-- and Clash codegen keys live in ftplugin/haskell.lua.

---@type Lang
return {
  ft = { "haskell", "lhaskell", "cabal" },
  tools = {
    ["haskell-language-server"] = "haskell-language-server-wrapper",
    fourmolu = "fourmolu",
  },
  declare = function()
    -- tree-sitter-haskell's scanner corrupts the heap (glibc "corrupted size vs.
    -- prev_size" aborts while editing), so Haskell gets regex syntax plus HLS
    -- semantic tokens instead.
    require("config.core.treesitter").skip({ "haskell", "lhaskell" })
  end,
  setup = function()
    -- Widen past nvim-lspconfig's default filetypes so .cabal files get
    -- diagnostics too. Formatting is left to conform (fourmolu), so HLS's own
    -- is unused. HLS must be built against the same GHC as the project. In a
    -- flake project run it through `nix develop` so it sees the flake's
    -- ghc/cabal/HLS (nvim itself usually isn't started from inside the dev
    -- shell); otherwise use PATH.
    vim.lsp.config("hls", {
      filetypes = { "haskell", "lhaskell", "cabal" },
      cmd = require("config.core.lsp").flake_cmd({ "haskell-language-server-wrapper", "--lsp" }),
      -- Semantic tokens (off by default in HLS) stand in for treesitter
      -- highlighting, which is disabled for Haskell (see declare above).
      settings = {
        haskell = { plugin = { semanticTokens = { globalOn = true } } },
      },
    })
    require("config.core.format").add({ haskell = { "fourmolu" }, lhaskell = { "fourmolu" } })
    require("config.core.lsp").enable({ "hls" })
  end,
}
