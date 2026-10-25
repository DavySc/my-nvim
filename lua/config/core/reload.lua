-- Hot reload: <leader>R (or :ConfigReload) saves the config files you are
-- editing and runs init.lua again in this session. Options, keymaps,
-- autocmds, plugin configs and lua/local.lua are redone; plugins stay loaded
-- (vim.pack can't unload them), and open buffers see FileType again so
-- ftplugins and language setups apply to them.
--
-- What a reload can't undo: a keymap, command or plugin you deleted stays
-- until you restart, and a plugin that refuses a second setup() (snacks)
-- keeps its first one.

local M = {}

--- Modules that come from this config, so require() must read them again.
local function ours(name)
  return name == "config" or name == "local" or name:find("^config%.") ~= nil or name:find("^lang%.") ~= nil
end

local function save_config_buffers(root)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].modified and vim.bo[buf].buftype == "" then
      local name = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
      if name ~= "" and vim.startswith(name, root .. "/") then
        vim.api.nvim_buf_call(buf, function() vim.cmd("silent update") end)
      end
    end
  end
end

function M.reload()
  local start = vim.uv.hrtime()
  save_config_buffers(vim.fs.normalize(vim.fn.stdpath("config")))
  -- vim.loader would miss a new file (a first lua/local.lua) otherwise.
  vim.loader.reset()
  for name in pairs(package.loaded) do
    if ours(name) then package.loaded[name] = nil end
  end
  local ok, err = pcall(vim.cmd.source, vim.fn.fnameescape(vim.env.MYVIMRC))
  if not ok then
    return vim.notify("Config reload failed: " .. tostring(err), vim.log.levels.ERROR)
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local ft = vim.bo[buf].filetype
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and ft ~= "" then
      vim.api.nvim_buf_call(buf, function() vim.cmd("doautocmd <nomodeline> FileType " .. ft) end)
    end
  end
  vim.notify(("Config reloaded (%.0f ms)"):format((vim.uv.hrtime() - start) / 1e6))
end

function M.declare() end

function M.setup()
  vim.keymap.set("n", "<leader>R", M.reload, { desc = "Reload config" })
  vim.api.nvim_create_user_command("ConfigReload", M.reload, { desc = "Reload config" })
end

return M
