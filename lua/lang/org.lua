-- Org mode: todos, agenda, capture and tangling from nvim-orgmode; LSP and
-- completion inside #+begin_src blocks from otter.nvim; running blocks from
-- lua/config/org_babel.lua. Agenda files are per machine (lua/local.lua).
--
--   <leader>oa agenda   <leader>oc capture   (anywhere; orgmode's own keys)
--   <leader>oe run the block under the cursor, <leader>oE every block
--   <leader>obt tangle the file (orgmode)

local lazy = require("config.lazy")

---@type Machine
local machine

-- Languages otter gives LSP inside blocks (when their server is enabled).
local OTTER_LANGS = { "python", "lua", "rust", "c", "cpp", "bash", "sql", "cs", "racket" }

---@type Lang
return {
  ft = { "org" },
  plugins = {
    {
      src = "https://github.com/nvim-orgmode/orgmode",
      config = function()
        require("orgmode").setup({
          org_agenda_files = machine.org.agenda_files,
          org_default_notes_file = machine.org.default_notes_file,
        })
      end,
    },
    "https://github.com/jmbuhr/otter.nvim",
  },
  declare = function(m)
    machine = m
    require("config.core.ui").group({ "<leader>o", group = "org" })
    -- Stand-ins until orgmode loads and maps these itself.
    for lhs, action in pairs({ ["<leader>oa"] = "agenda.prompt", ["<leader>oc"] = "capture.prompt" }) do
      vim.keymap.set("n", lhs, function()
        lazy.load("orgmode")
        require("orgmode").action(action)
      end, { desc = "org " .. action:match("^%w+") })
    end
  end,
  setup = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "org",
      callback = function(ev)
        local babel = require("config.org_babel")
        vim.keymap.set("n", "<leader>oe", babel.execute, { buffer = ev.buf, desc = "org: run block" })
        vim.keymap.set("n", "<leader>oE", babel.execute_all, { buffer = ev.buf, desc = "org: run all blocks" })
        pcall(function() require("otter").activate(OTTER_LANGS, true, true) end)
      end,
    })
  end,
}
