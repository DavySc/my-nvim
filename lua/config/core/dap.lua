-- nvim-dap, loaded on the first <leader>d key, :Dap* command or require("dap")
-- (the C++ and CMake run/debug keys). Languages add launch configurations
-- with M.configure(); they're applied when dap loads.

local lazy = require("config.lazy")

local M = {}

---@type table<string, table[]|fun(): table[]>
local configurations = {}

--- Launch configurations for `fts`: a list, or a function returning one
--- (called when dap loads, so it can look at adapters and paths then).
---@param fts string[]
---@param configs table[]|fun(): table[]
function M.configure(fts, configs)
  for _, ft in ipairs(fts) do configurations[ft] = configs end
  if lazy.is_loaded("nvim-dap") then
    local dap = require("dap")
    for _, ft in ipairs(fts) do dap.configurations[ft] = type(configs) == "function" and configs() or configs end
  end
end

local function setup()
  local dap = require("dap")
  -- dap-ui requires dap while loading, so it's only required from listeners.
  local function ui(method) return function() require("dapui")[method]() end end
  dap.listeners.after.event_initialized["dapui_config"] = ui("open")
  dap.listeners.before.event_terminated["dapui_config"] = ui("close")
  dap.listeners.before.event_exited["dapui_config"] = ui("close")
  lazy.load("nvim-dap-virtual-text")

  -- codelldb comes from mason. On Windows mason's PATH entry is a .cmd shim,
  -- which libuv can't spawn directly, so use the real binary.
  local codelldb = vim.fn.exepath("codelldb")
  local mason_codelldb = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/adapter/codelldb.exe"
  if vim.fn.has("win32") == 1 and vim.uv.fs_stat(mason_codelldb) then
    codelldb = mason_codelldb
  end
  if codelldb ~= "" then
    dap.adapters.codelldb = {
      type = "server",
      port = "${port}",
      executable = { command = codelldb, args = { "--port", "${port}" } },
    }
  end
  -- gdb >= 14 speaks DAP itself, which is the better bet for heavy libstdc++ use.
  if vim.fn.executable("gdb") == 1 then
    dap.adapters.gdb = {
      type = "executable",
      command = "gdb",
      args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
    }
  end

  for ft, configs in pairs(configurations) do
    dap.configurations[ft] = type(configs) == "function" and configs() or configs
  end
end

function M.declare()
  lazy.add("https://github.com/nvim-neotest/nvim-nio")
  lazy.add({ src = "https://github.com/rcarriga/nvim-dap-ui", config = function() require("dapui").setup() end })
  lazy.add({
    src = "https://github.com/theHamsta/nvim-dap-virtual-text",
    config = function() require("nvim-dap-virtual-text").setup({ virt_text_pos = "eol" }) end,
  })
  lazy.add({ src = "https://github.com/mfussenegger/nvim-dap", cmd = { "Dap*" }, config = setup })
end

function M.setup()
  local function dap() return require("dap") end
  vim.keymap.set("n", "<leader>db", function() dap().toggle_breakpoint() end, { desc = "DAP: Breakpoint" })
  vim.keymap.set("n", "<leader>dB", function()
    vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
      if cond then dap().set_breakpoint(cond) end
    end)
  end, { desc = "DAP: Conditional breakpoint" })
  vim.keymap.set("n", "<leader>dc", function() dap().continue() end, { desc = "DAP: Continue" })
  vim.keymap.set("n", "<leader>ds", function() dap().step_over() end, { desc = "DAP: Step over" })
  vim.keymap.set("n", "<leader>di", function() dap().step_into() end, { desc = "DAP: Step into" })
  vim.keymap.set("n", "<leader>do", function() dap().step_out() end, { desc = "DAP: Step out" })
  vim.keymap.set("n", "<leader>du", function() require("dapui").toggle() end, { desc = "DAP: UI toggle" })
  vim.keymap.set("n", "<leader>dl", function() dap().run_last() end, { desc = "DAP: Run last" })
  vim.keymap.set("n", "<leader>dq", function() dap().terminate() end, { desc = "DAP: Terminate" })
  vim.keymap.set({ "n", "v" }, "<leader>de", function() require("dapui").eval(nil, { enter = true }) end, { desc = "DAP: Eval" })
end

return M
