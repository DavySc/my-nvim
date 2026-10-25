-- Config hot reload (lua/config/core/reload.lua).
--   nvim --headless -c 'luafile tests/reload_test.lua'
-- Writes lua/local.lua in the config directory, so tests/run.sh runs it in
-- its throwaway copy; it refuses to run where a lua/local.lua exists.

local failures, passed = {}, 0
local errors = {}
-- Errors reported through vim.notify count too. Snacks puts its own
-- vim.notify in place on VimEnter, so this goes on top again after that.
local function watch_notify()
  local notify = vim.notify
  vim.notify = function(msg, level, ...)
    if level == vim.log.levels.ERROR then errors[#errors + 1] = msg end
    return notify(msg, level, ...)
  end
end
watch_notify()
local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failures[#failures + 1] = name .. (detail and (": " .. detail) or "")
  end
end

-- Counted across all groups: an autocmd outside a cleared group would pile up.
local function autocmds(event)
  return #vim.api.nvim_get_autocmds({ event = event })
end

local function run()
  local local_file = vim.fn.stdpath("config") .. "/lua/local.lua"
  assert(vim.fn.filereadable(local_file) == 0, "refusing to overwrite " .. local_file)

  check("<leader>R is mapped", vim.fn.maparg("<leader>R", "n") ~= "")
  check(":ConfigReload exists", vim.fn.exists(":ConfigReload") == 2)

  local loaders = #package.loaders
  vim.cmd.edit(vim.fn.fnameescape(vim.fn.tempname() .. ".lua"))
  local before = {}
  for _, event in ipairs({ "BufWritePre", "LspAttach", "FileType", "UIEnter", "InsertEnter" }) do
    before[event] = autocmds(event)
  end

  -- An unsaved edit of a config file: the reload saves it, then applies it.
  vim.cmd.edit(vim.fn.fnameescape(local_file))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "return { extra = function() vim.g.reload_probe = (vim.g.reload_probe or 0) + 1 end }",
  })
  local buf = vim.api.nvim_get_current_buf()
  require("config.core.reload").reload()
  check("reload saved the edited config buffer", not vim.bo[buf].modified)
  check("reload applied lua/local.lua", vim.g.reload_probe == 1, tostring(vim.g.reload_probe))
  require("config.core.reload").reload()
  check("second reload ran it once more", vim.g.reload_probe == 2, tostring(vim.g.reload_probe))

  -- Nothing piles up.
  check("one lazy searcher", #package.loaders == loaders, ("%d, was %d"):format(#package.loaders, loaders))
  for event, n in pairs(before) do
    check(event .. " autocmds don't pile up", autocmds(event) == n, ("%d, was %d"):format(autocmds(event), n))
  end
  check("lua language set up again", vim.lsp.is_enabled("lua_ls"))

  -- Lazy plugins still load on their triggers, and loaded ones stay loaded.
  local lazy = require("config.lazy")
  check("eager plugin still loaded", lazy.is_loaded("snacks.nvim"))
  check("trouble not loaded yet", not lazy.is_loaded("trouble.nvim"))
  check("require() still loads a lazy plugin", pcall(require, "trouble") and lazy.is_loaded("trouble.nvim"))
  pcall(vim.cmd, "NeogitResetState")
  check("a command still loads a lazy plugin", lazy.is_loaded("neogit"))

end

-- A broken lua/local.lua is reported (on the next tick), not thrown.
local function broken()
  watch_notify()
  local local_file = vim.fn.stdpath("config") .. "/lua/local.lua"
  vim.fn.writefile({ "return {" }, local_file)
  check("broken config doesn't throw", pcall(require("config.core.reload").reload))
  vim.fn.delete(local_file)
end

local function finish()
  local broke = 0
  for i = #errors, 1, -1 do
    if errors[i]:find("lua/local.lua", 1, true) then
      broke = broke + 1
      table.remove(errors, i)
    end
  end
  check("broken config is reported", broke == 1, tostring(broke))
  for _, msg in ipairs(errors) do failures[#failures + 1] = "error notified: " .. msg end
  io.stdout:write(("reload: %d passed, %d failed\n"):format(passed, #failures))
  for _, f in ipairs(failures) do io.stdout:write("  FAIL " .. f .. "\n") end
  vim.cmd(#failures == 0 and "qa!" or "cquit!")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then failures[#failures + 1] = "crashed: " .. err end
vim.defer_fn(function()
  local ok2, err2 = xpcall(broken, debug.traceback)
  if not ok2 then failures[#failures + 1] = "crashed: " .. err2 end
  vim.defer_fn(finish, 100)
end, 50)
