-- Org: nvim-orgmode with kittymax's setup (nixfiles/kittymax/lisp/kitty-org.el):
-- notes in ~/org, an inbox, a journal datetree, the same TODO keywords and
-- capture templates. Emphasis markers and link targets are hidden except on
-- the line under the cursor, headings get bullets (org-bullets.nvim).
--
-- LaTeX, two ways:
--   - pretty symbols everywhere: \alpha → α, x^{2} → x² (config/org_pretty.lua)
--   - rendered math as images in terminals that can show them (kitty, Ghostty,
--     WezTerm): $...$, \(...\), \[...\], \begin{...} and equation blocks, via
--     snacks.image (enabled in config/core/ui.lua). Needs `tectonic` or
--     `pdflatex`, and ImageMagick (`magick`).
--
-- orgmode builds its own treesitter grammar on first use (needs git and a C
-- compiler). <leader>oa (agenda) and <leader>oc (capture) work from anywhere
-- and load orgmode on first use.

local org_dir = "~/org/"

---@type Lang
return {
  ft = { "org" },
  plugins = {
    {
      src = "https://github.com/nvim-orgmode/orgmode",
      config = function()
        require("orgmode").setup({
          org_agenda_files = org_dir .. "**/*",
          org_default_notes_file = org_dir .. "inbox.org",
          org_todo_keywords = { "TODO(t)", "NEXT(n)", "WAIT(w)", "|", "DONE(d)", "CANCELLED(c)" },
          org_hide_emphasis_markers = true,
          org_hide_leading_stars = true,
          org_startup_indented = true,
          org_startup_folded = "content",
          org_ellipsis = " ▾",
          org_log_done = "time",
          org_log_into_drawer = "LOGBOOK",
          org_deadline_warning_days = 5,
          org_capture_templates = {
            t = { description = "Task", template = "* TODO %?\n  %u\n  %a", target = org_dir .. "inbox.org" },
            n = { description = "Note", template = "* %?\n  %U", target = org_dir .. "inbox.org" },
            j = { description = "Journal", template = "* %<%H:%M> %?", target = org_dir .. "journal.org", datetree = true },
          },
        })
      end,
    },
    {
      src = "https://github.com/nvim-orgmode/org-bullets.nvim",
      config = function() require("org-bullets").setup() end,
    },
  },
  declare = function()
    -- Stand-ins until orgmode is loaded; its setup maps the same keys.
    local function org(action)
      return function()
        vim.fn.mkdir(vim.fn.expand(org_dir), "p")
        require("orgmode").action(action)
      end
    end
    vim.keymap.set("n", "<leader>oa", org("agenda.prompt"), { desc = "Org agenda" })
    vim.keymap.set("n", "<leader>oc", org("capture.prompt"), { desc = "Org capture" })
    require("config.core.ui").group({ "<leader>o", group = "org" })
  end,
  setup = function()
    local pretty = require("config.org_pretty")
    local function buffer(buf)
      pretty.attach(buf)
      -- Concealed text (links, emphasis markers, symbols) shows as typed on
      -- the cursor line, like org-appear.
      vim.opt_local.conceallevel = 2
      vim.opt_local.concealcursor = ""
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
    end
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("config-org", { clear = true }),
      pattern = "org",
      callback = function(ev) buffer(ev.buf) end,
    })
    Snacks.toggle.new({
      name = "Org pretty symbols",
      get = function() return vim.g.org_pretty ~= false end,
      set = function(on)
        vim.g.org_pretty = on
        vim.cmd.redraw({ bang = true })
      end,
    }):map("<leader>up")
  end,
}
