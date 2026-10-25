-- Plugins are managed by Neovim's native vim.pack (0.12+), loaded lazily by
-- lua/config/lazy.lua. Update with :lua vim.pack.update(); remove a plugin by
-- deleting its line, then :lua vim.pack.del({ "name" }).
--
-- Startup only declares things. Each lua/lang/<name>.lua is set up the first
-- time one of its filetypes is opened, and the machine file (lua/local.lua,
-- see lua/config/machine.lua) decides which languages exist at all.

local lazy = require("config.lazy")
local machine = require("config.machine")

local core = {
  require("config.core.ui"),
  require("config.core.lsp"),
  require("config.core.treesitter"),
  require("config.core.completion"),
  require("config.core.format"),
  require("config.core.dap"),
  require("config.core.git"),
  require("config.core.ai"),
}

---@class Lang
---@field ft string[] filetypes that set the language up
---@field plugins? (LazySpec|string)[] loaded with the language
---@field parsers? string[] treesitter parsers to install
---@field tools? table<string, string> mason package -> executable
---@field declare? fun(machine: Machine) at startup; keep it cheap (filetype.add, parser registration)
---@field setup? fun(machine: Machine) once, on the first buffer of one of `ft`

local names = vim.tbl_keys(machine.langs)
table.sort(names)
---@type table<string, Lang>
local langs = {}
for _, name in ipairs(names) do
  if machine.langs[name] then
    local ok, lang = pcall(require, "lang." .. name)
    if ok then
      langs[name] = lang
    else
      vim.schedule(function() vim.notify("lang." .. name .. ": " .. lang, vim.log.levels.ERROR) end)
    end
  end
end

-- ── Declare ─────────────────────────────────────────────────────────────
for _, mod in ipairs(core) do mod.declare() end

local tools = {}
for _, lang in pairs(langs) do
  for _, spec in ipairs(lang.plugins or {}) do
    -- Language plugins load with their language, never on their own.
    local s = type(spec) == "string" and { src = spec } or spec
    lang._plugins = lang._plugins or {}
    table.insert(lang._plugins, lazy.add(s))
  end
  require("config.core.treesitter").parsers(lang.parsers or {})
  if machine.tools.install then tools = vim.tbl_extend("keep", tools, lang.tools or {}) end
  if lang.declare then lang.declare(machine) end
end

lazy.install()

-- ── Set up ──────────────────────────────────────────────────────────────
for _, mod in ipairs(core) do
  if mod.setup then mod.setup() end
end
require("config.core.lsp").ensure_tools(tools)

local group = vim.api.nvim_create_augroup("config-lang", { clear = true })
for name, lang in pairs(langs) do
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = lang.ft,
    once = true,
    desc = "Set up lang." .. name,
    callback = function(ev)
      -- `once` is per pattern, and a language usually has several.
      if lang._done then return end
      lang._done = true
      for _, plugin in ipairs(lang._plugins or {}) do lazy.load(plugin) end
      if lang.setup then
        local ok, err = pcall(lang.setup, machine)
        if not ok then vim.notify("lang." .. name .. ": " .. err, vim.log.levels.ERROR) end
      end
      -- Servers enabled just now (and the plugins' own FileType handlers)
      -- haven't seen this buffer yet.
      vim.api.nvim_buf_call(ev.buf, function() vim.cmd("doautocmd <nomodeline> FileType " .. ev.match) end)
    end,
  })
end

if machine.extra then machine.extra() end
