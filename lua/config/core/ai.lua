-- AI: Claude Code (claudecode.nvim), loaded on the first <leader>a key or
-- :ClaudeCode* command. Until then its IDE server isn't running, so a `claude`
-- started in another terminal won't find this nvim; <leader>ac starts both.
-- Claude runs in a snacks split and talks to nvim over the IDE protocol: it sees
-- the current selection, and proposed edits open as diffs (:w / <leader>aa
-- accepts, :q / <leader>ad rejects). Claude reads the project's CLAUDE.md, so a
-- repo can set its tone (e.g. "hint, don't solve").

local lazy = require("config.lazy")

local M = {}

function M.declare()
  lazy.add({
    src = "https://github.com/coder/claudecode.nvim",
    cmd = { "ClaudeCode*" },
    config = function()
      require("claudecode").setup({ terminal = { provider = "snacks", split_width_percentage = 0.38 } })
    end,
  })
end

function M.setup()
  -- The <cmd> keys below hit CmdUndefined first, which loads the plugin.
  vim.keymap.set("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude" })
  vim.keymap.set("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude" })
  vim.keymap.set("n", "<leader>aC", "<cmd>ClaudeCode --continue<cr>", { desc = "Continue last session" })
  vim.keymap.set("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add buffer to context" })
  vim.keymap.set("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Accept diff" })
  vim.keymap.set("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "Reject diff" })
  vim.keymap.set("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send selection (ask your own)" })

  -- Select, press a key, get an answer: send the selection as an @-mention, then
  -- type a canned question after it. The mention is delivered asynchronously over
  -- the websocket, hence the short delay before the question.
  local function ask_about_selection(question)
    return function()
      if not require("claudecode").is_claude_connected() then
        vim.cmd("ClaudeCode")
        vim.notify("Claude is starting; select again once it's up", vim.log.levels.INFO)
        return
      end
      vim.cmd("ClaudeCodeSend")
      vim.defer_fn(function() require("claudecode.terminal").send_to_terminal(question) end, 300)
    end
  end
  vim.keymap.set("v", "<leader>ae", ask_about_selection(
    "Explain this code: what it does, step by step, and which language concepts it relies on (with where to read more). Don't change anything."
  ), { desc = "Explain selection" })
  vim.keymap.set("v", "<leader>ar", ask_about_selection(
    "Suggest a refactor of this code to make it more idiomatic and clearer. Propose it as an edit and explain each change and why."
  ), { desc = "Refactor selection" })
  vim.keymap.set("v", "<leader>at", ask_about_selection(
    "I'm learning this language. Give me one or two short tips about this code: an idiom, a pitfall, or a concept worth studying next."
  ), { desc = "Learning tips for selection" })
end

return M
