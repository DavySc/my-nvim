-- What differs between machines (home, work, a fresh Windows box) lives in
-- lua/local.lua, which is git-ignored: copy lua/local.example.lua to start one.
-- It returns a table that is merged over the defaults below, so a machine only
-- states what it changes. With no local.lua you get the defaults: every
-- language on.

---@class Machine
---@field name string shown nowhere important; handy in `extra` and :lua print()
---@field langs table<string, boolean> lua/lang/<name>.lua to use; a language that's off is never loaded or installed
---@field tools { install: boolean } let mason install missing tools for the enabled languages
---@field extra? fun() runs last, after everything else is set up

---@type Machine
local defaults = {
  name = "default",
  langs = {
    lua = true,
    c = true,
    rust = true,
    nix = true,
    verilog = true,
    glsl = true,
    markdown = true,
  },
  tools = { install = true },
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
