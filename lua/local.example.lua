-- Copy to lua/local.lua (git-ignored) and keep only what this machine changes.
-- Merged over the defaults in lua/config/machine.lua.
return {
  name = "work",

  -- Languages this machine never needs: not loaded, and mason won't install
  -- their tools. Everything not listed keeps its default (on).
  langs = { nix = false, rust = false },

  -- Set false on a machine where tools come from elsewhere (nix, IT images).
  tools = { install = true },

  -- Anything else, run last.
  extra = function()
    -- vim.opt.shell = "pwsh"
  end,
}
