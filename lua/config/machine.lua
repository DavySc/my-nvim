-- What differs between machines (home, work, a fresh Windows box) lives in
-- lua/local.lua, which is git-ignored: copy lua/local.example.lua to start one.
-- It returns a table that is merged over the defaults below, so a machine only
-- states what it changes. With no local.lua you get the defaults: every
-- language on.

---@class Machine
---@field name string shown nowhere important; handy in `extra` and :lua print()
---@field langs table<string, boolean> lua/lang/<name>.lua to use; a language that's off is never loaded or installed
---@field tools { install: boolean } let mason install missing tools for the enabled languages
---@field sql { dialect: "tsql"|"postgres" } default for .sql buffers that don't say otherwise
---@field dbbliss table passed to require("dbbliss").setup() (connections etc.)
---@field org { agenda_files: string|string[], default_notes_file: string }
---@field extra? fun() runs last, after everything else is set up

---@type Machine
local defaults = {
  name = "default",
  langs = {
    lua = true,
    c = true,
    rust = true,
    haskell = true,
    nix = true,
    souffle = true,
    sql = true,
    csharp = true,
    verilog = true,
    racket = true,
    org = true,
  },
  tools = { install = true },
  sql = { dialect = "postgres" },
  dbbliss = { connections = {} },
  org = {
    agenda_files = "~/org/**/*",
    default_notes_file = "~/org/inbox.org",
  },
}

local ok, overrides = pcall(require, "local")
if not ok then
  -- A missing file is the normal case; anything else is a mistake in it.
  if not tostring(overrides):find("module 'local' not found", 1, true) then
    vim.schedule(function() vim.notify("lua/local.lua: " .. tostring(overrides), vim.log.levels.ERROR) end)
  end
  overrides = {}
end

---@type Machine
return vim.tbl_deep_extend("force", defaults, overrides or {})
