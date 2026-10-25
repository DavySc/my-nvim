-- Copy to lua/local.lua (git-ignored) and keep only what this machine changes.
-- Merged over the defaults in lua/config/machine.lua.
return {
  name = "work",

  -- Languages this machine never needs: not loaded, and mason won't install
  -- their tools. Everything not listed keeps its default (on).
  langs = { haskell = false, nix = false, souffle = false },

  -- Set false on a machine where tools come from elsewhere (nix, IT images).
  tools = { install = true },

  -- Dialect for .sql buffers that don't say otherwise.
  sql = { dialect = "tsql" },

  -- Passed to require("dbbliss").setup(). Passwords are references, never
  -- literals (see :help dbbliss).
  dbbliss = {
    connections = {
      -- dev_mssql = {
      --   engine = "sqlserver",
      --   env = "dev",
      --   connection_string = "Server=localhost,1433;Integrated Security=true;TrustServerCertificate=true",
      -- },
    },
  },

  org = {
    agenda_files = "~/work/org/**/*",
    default_notes_file = "~/work/org/inbox.org",
  },

  -- Anything else, run last.
  extra = function()
    -- vim.opt.shell = "pwsh"
  end,
}
