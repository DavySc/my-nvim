-- Theme, pickers, explorer, statusline, motions, diagnostics list, keymap hints.
-- The theme, snacks and the statusline are needed for the first frame; the
-- rest loads on its keys or commands (which-key just after the UI is up).

local lazy = require("config.lazy")

local M = {}

---@type { n: integer, count: integer, ms: number }?
local footer_stats

---@type table[] which-key group specs added by other modules
local groups = {
  { "<leader>g", group = "git" },
  { "<leader>m", group = "make / run" },
  { "<leader>h", group = "hunks", mode = { "n", "v" } },
  { "<leader>d", group = "debug" },
  { "<leader>f", group = "find" },
  { "<leader>x", group = "diagnostics" },
  { "<leader>c", group = "code" },
  { "<leader>a", group = "ai (Claude)", mode = { "n", "v" } },
  { "<leader>u", group = "ui toggles" },
}

--- Add a which-key group (e.g. a language's <leader> prefix).
function M.group(spec)
  groups[#groups + 1] = spec
  if lazy.is_loaded("which-key.nvim") then require("which-key").add({ spec }) end
end

function M.declare()
  lazy.add({
    src = "https://github.com/catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    config = function()
      require("catppuccin").setup({ transparent_background = true })
      vim.cmd.colorscheme("catppuccin")
    end,
  })
  lazy.add({
    src = "https://github.com/folke/snacks.nvim",
    lazy = false,
    config = function()
      -- Snacks refuses a second setup(); a reload keeps the first one.
      if Snacks and Snacks.did_setup then return end
      require("snacks").setup({
        bigfile = { enabled = true },
        -- Images and rendered LaTeX math in org and markdown buffers, in
        -- terminals with the kitty graphics protocol (kitty, Ghostty,
        -- WezTerm); elsewhere it does nothing. Math needs tectonic or
        -- pdflatex, and ImageMagick.
        image = { enabled = true },
        dashboard = {
          enabled = true,
          -- Snacks' own "startup" section asks lazy.nvim for its numbers,
          -- which this config doesn't have; this one asks config.lazy.
          sections = {
            -- The kittymax cat, animated (config/core/splash.lua); it leaves
            -- 18 lines for the keys and the footer below it.
            require("config.core.splash").section(18),
            { section = "keys", gap = 1, padding = 1 },
            function()
              -- Measured once: the dashboard redraws with the animation, and
              -- a live clock would keep counting up.
              if not footer_stats then
                local n, count = lazy.stats()
                local ms = (vim.uv.hrtime() - (vim.g.config_start_ns or vim.uv.hrtime())) / 1e6
                footer_stats = { n = n, count = count, ms = ms }
              end
              local n, count, ms = footer_stats.n, footer_stats.count, footer_stats.ms
              return {
                align = "center",
                text = {
                  { "⚡ Neovim loaded ", hl = "footer" },
                  { n .. "/" .. count, hl = "special" },
                  { " plugins in ", hl = "footer" },
                  { ("%.1fms"):format(ms), hl = "special" },
                },
              }
            end,
          },
        },
        -- No animation while navigating: the indent guides draw at once and
        -- scrolling jumps instead of gliding.
        indent = { enabled = true, animate = { enabled = false } },
        input = { enabled = true },
        picker = { enabled = true },
        notifier = { enabled = true },
        quickfile = { enabled = true },
        scope = { enabled = true },
        scroll = { enabled = false },
        statuscolumn = { enabled = true },
        words = { enabled = true },
      })
    end,
  })
  lazy.add({
    src = "https://github.com/echasnovski/mini.nvim",
    lazy = false,
    config = function()
      require("mini.statusline").setup({ use_icons = true })
      -- Additions to vim's grammar, each an operator or a text object:
      -- ga{motion}{char} aligns (Kakoune's &): gaip= lines up a SET list.
      require("mini.align").setup()
      -- a/i objects for arguments (cia: one item of (a, b, c)), calls (af) and
      -- the next/last pair (ciN(, ciL"). The next/last suffixes are N/L because
      -- Neovim 0.12 already uses van / vin for treesitter nodes.
      require("mini.ai").setup({
        n_lines = 200,
        mappings = { around_next = "aN", inside_next = "iN", around_last = "aL", inside_last = "iL" },
      })
      -- vim-surround's keys: ys{motion}{char} adds, cs{old}{new} changes,
      -- ds{char} deletes; gs in visual mode surrounds the selection. Flash keeps s.
      require("mini.surround").setup({
        mappings = {
          add = "ys", delete = "ds", replace = "cs",
          find = "", find_left = "", highlight = "", update_n_lines = "",
          suffix_last = "", suffix_next = "",
        },
        search_method = "cover_or_next",
        -- ys iw * makes **bold** in markdown; ys iw ] makes a [T-SQL] name.
        custom_surroundings = {
          ["*"] = { input = { "%*%*().-()%*%*" }, output = { left = "**", right = "**" } },
        },
      })
      -- y in visual mode must yank at once, not wait for ys.
      pcall(vim.keymap.del, "x", "ys")
      vim.keymap.set("x", "gs", [[:<C-u>lua MiniSurround.add("visual")<CR>]], { silent = true, desc = "Surround selection" })
    end,
  })
  -- Eager: setup() also takes over f/t/F/T, which should work from the start.
  lazy.add({ src = "https://github.com/folke/flash.nvim", lazy = false, config = function() require("flash").setup({}) end })
  lazy.add({
    src = "https://github.com/folke/trouble.nvim",
    cmd = { "Trouble" },
    config = function() require("trouble").setup({}) end,
  })
  lazy.add({
    src = "https://github.com/folke/which-key.nvim",
    config = function()
      require("which-key").setup({ delay = 400 })
      require("which-key").add(groups)
    end,
  })
end

function M.setup()
  require("config.core.splash").setup()
  -- which-key is only useful once you're typing; load it right after the UI.
  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("config-ui", { clear = true }),
    once = true,
    callback = function() vim.schedule(function() lazy.load("which-key.nvim") end) end,
  })

  vim.keymap.set("n", "<leader>fg", function() Snacks.picker.grep() end, { desc = "Grep" })
  vim.keymap.set("n", "<leader>,", function() Snacks.picker.buffers() end, { desc = "Buffers" })
  vim.keymap.set("n", "<leader>ff", function() Snacks.picker.smart() end, { desc = "Find Files" })
  vim.keymap.set("n", "<leader>e", function() Snacks.explorer() end, { desc = "File Explorer" })
  -- gd, gD and the gr* keys are set per buffer when a language server attaches
  -- (config/core/lsp.lua); elsewhere they stay vim's own.
  vim.keymap.set("n", "<leader>fr", function() Snacks.picker.registers() end, { desc = "Registers" })
  vim.keymap.set("n", "<leader>uz", function() Snacks.zen() end, { desc = "Zen (writing room)" })
  -- Neovim's own undo tree (0.12+); 'undofile' keeps the history across restarts.
  vim.keymap.set("n", "<leader>uu", function()
    if vim.fn.exists(":Undotree") == 0 then pcall(vim.cmd.packadd, "nvim.undotree") end
    if vim.fn.exists(":Undotree") == 2 then
      vim.cmd.Undotree()
    else
      vim.notify("No :Undotree in this Neovim (0.12+)", vim.log.levels.WARN)
    end
  end, { desc = "Undo tree" })
  local function float_term() Snacks.terminal.toggle(nil, { win = { position = "float", border = "rounded" } }) end
  -- Most terminals send Ctrl+/ as <C-_> (0x1F), so map both spellings.
  vim.keymap.set({ "n", "t" }, "<c-/>", float_term, { desc = "Floating terminal" })
  vim.keymap.set({ "n", "t" }, "<c-_>", float_term, { desc = "which_key_ignore" })
  vim.keymap.set("n", "<leader>ft", float_term, { desc = "Floating terminal" })

  -- ── Motions: flash ────────────────────────────────────────────────────
  vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash" })
  vim.keymap.set({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })
  vim.keymap.set("o", "r", function() require("flash").remote() end, { desc = "Remote Flash" })
  vim.keymap.set({ "o", "x" }, "R", function() require("flash").treesitter_search() end, { desc = "Treesitter Search" })
  vim.keymap.set("c", "<c-s>", function() require("flash").toggle() end, { desc = "Toggle Flash Search" })

  -- ── Diagnostics (trouble) ─────────────────────────────────────────────
  vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
  vim.keymap.set("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer Diagnostics" })
  vim.keymap.set("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols" })
  vim.keymap.set("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "LSP refs" })
  vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List" })
  vim.keymap.set("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List" })
end

return M
