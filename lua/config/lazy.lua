-- Lazy loading on top of vim.pack, in the spirit of lua/config/cmake.lua: no
-- plugin manager beyond Neovim's own, just the triggers this config needs.
--
-- Every plugin is installed by one vim.pack.add() call (so installs run in
-- parallel). An eager plugin is put on 'runtimepath' straight away; a lazy one
-- stays in pack/core/opt until the first of its triggers fires:
--   event  autocmd event(s), e.g. "InsertEnter"
--   ft     filetype(s)
--   cmd    user command name(s) or globs, via CmdUndefined
--   on     a function that loading code calls (M.load)
-- and, for any lazy plugin, the first require() of one of its Lua modules.
-- That last one means keymaps can just call require("dap") and friends.

local M = {}

---@class LazySpec
---@field src string
---@field name? string
---@field version? string
---@field lazy? boolean default true; false puts it on 'runtimepath' at startup
---@field event? string|string[]
---@field ft? string|string[]
---@field cmd? string|string[]
---@field config? fun() runs once, right after the plugin is loaded
---@field build? fun() runs after an install or update (the plugin is loaded first)

---@type table<string, LazySpec>
local specs = {}
---@type string[] in declaration order
local order = {}
---@type table<string, boolean>
local loaded = {}
---@type table<string, string> top-level Lua module -> plugin name
local owners = {}

local function list(v)
  if v == nil then return {} end
  return type(v) == "table" and v or { v }
end

local function plugin_name(spec)
  return spec.name or spec.src:gsub("%.git$", ""):match("[^/]+$")
end

--- Declare a plugin. Call before M.install(); a second declaration of the same
--- plugin merges into the first (lang files may share a dependency).
---@param spec LazySpec|string
function M.add(spec)
  if type(spec) == "string" then spec = { src = spec } end
  local name = plugin_name(spec)
  if specs[name] then
    local old = specs[name]
    if spec.lazy == false then old.lazy = false end
    if spec.config then
      local a, b = old.config, spec.config
      old.config = a and function() a() b() end or b
    end
    return name
  end
  spec.name = name
  specs[name] = spec
  order[#order + 1] = name
  return name
end

local function source_after(path)
  -- :packadd sources plugin/ but not after/plugin/ once startup has passed
  -- load-plugins; before that, startup itself sources them.
  if vim.v.vim_did_init == 0 then return end
  for _, file in ipairs(vim.fn.glob(path .. "/after/plugin/**/*.{vim,lua}", false, true)) do
    vim.cmd.source(vim.fn.fnameescape(file))
  end
end

--- Load a lazy plugin (and run its config) if it isn't loaded yet.
---@param name string
function M.load(name)
  if loaded[name] then return end
  local spec = specs[name]
  if not spec then
    return vim.notify("lazy: unknown plugin " .. name, vim.log.levels.ERROR)
  end
  loaded[name] = true
  vim.cmd.packadd(name)
  local path = vim.fn.stdpath("data") .. "/site/pack/core/opt/" .. name
  source_after(path)
  if spec.config then
    local ok, err = pcall(spec.config)
    if not ok then vim.notify("lazy: config of " .. name .. " failed: " .. err, vim.log.levels.ERROR) end
  end
end

--- Plugins loaded so far, and declared in all.
---@return integer loaded, integer count
function M.stats()
  return vim.tbl_count(loaded), #order
end

--- Whether `name` has been loaded.
function M.is_loaded(name)
  return loaded[name] == true
end

-- require() of a lazy plugin's module loads the plugin, then hands the module
-- back to the regular searchers (now that it is on 'runtimepath').
local function searcher(modname)
  local owner = owners[modname:match("^[^.]+")]
  if not owner or loaded[owner] then return end
  M.load(owner)
  -- The plugin's config may already have required it.
  local mod = package.loaded[modname]
  if mod ~= nil then
    return function() return mod end
  end
  for _, s in ipairs(package.loaders) do
    if s ~= searcher then
      local found = s(modname)
      if type(found) == "function" then return found end
    end
  end
end

local function register_modules(name, path)
  local handle = vim.uv.fs_scandir(path .. "/lua")
  while handle do
    local entry = vim.uv.fs_scandir_next(handle)
    if not entry then break end
    local mod = entry:gsub("%.lua$", "")
    owners[mod] = owners[mod] or name
  end
end

local group = vim.api.nvim_create_augroup("config-lazy", { clear = true })

local function set_triggers(name, spec)
  local events = list(spec.event)
  if #events > 0 then
    vim.api.nvim_create_autocmd(events, {
      group = group,
      once = true,
      callback = function() M.load(name) end,
    })
  end
  local fts = list(spec.ft)
  if #fts > 0 then
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = fts,
      once = true,
      callback = function(ev)
        if loaded[name] then return end
        M.load(name)
        -- Let the plugin's own FileType handlers and ftplugin/ see this buffer.
        vim.api.nvim_buf_call(ev.buf, function() vim.cmd("doautocmd <nomodeline> FileType " .. ev.match) end)
      end,
    })
  end
  for _, cmd in ipairs(list(spec.cmd)) do
    vim.api.nvim_create_autocmd("CmdUndefined", {
      group = group,
      pattern = cmd,
      once = true,
      callback = function() M.load(name) end,
    })
  end
end

--- Install everything declared so far and put the eager plugins on
--- 'runtimepath'. Lazy plugins are installed but left out until triggered.
function M.install()
  -- Must exist before vim.pack.add, which fires it while installing.
  vim.api.nvim_create_autocmd("PackChanged", {
    group = group,
    callback = function(ev)
      local d = ev.data
      local spec = specs[d.spec.name]
      if spec and spec.build and (d.kind == "install" or d.kind == "update") then
        if not d.active then vim.cmd.packadd(d.spec.name) end
        spec.build()
      end
    end,
  })
  local list_ = {}
  for _, name in ipairs(order) do
    local s = specs[name]
    list_[#list_ + 1] = { src = s.src, name = name, version = s.version }
  end
  vim.pack.add(list_, {
    load = function(plug)
      local spec = specs[plug.spec.name]
      if spec.lazy == false then
        vim.cmd.packadd({ plug.spec.name, bang = vim.v.vim_did_init == 0 })
        loaded[plug.spec.name] = true
      else
        register_modules(plug.spec.name, plug.path)
        set_triggers(plug.spec.name, spec)
      end
    end,
  })
  table.insert(package.loaders, searcher)
  for _, name in ipairs(order) do
    local spec = specs[name]
    if spec.lazy == false and spec.config then spec.config() end
  end
end

return M
