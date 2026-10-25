-- Theme, pickers, explorer, statusline, motions, diagnostics list, keymap hints.
-- The theme, snacks and the statusline are needed for the first frame; the
-- rest loads on its keys or commands (which-key just after the UI is up).

local lazy = require("config.lazy")

local M = {}

---@type table[] which-key group specs added by other modules
local groups = {
  { "<leader>g", group = "git" },
  { "<leader>m", group = "make (C/C++, Haskell/Clash)" },
  { "<leader>h", group = "hunks", mode = { "n", "v" } },
  { "<leader>d", group = "debug" },
  { "<leader>f", group = "find" },
  { "<leader>x", group = "diagnostics" },
  { "<leader>c", group = "code" },
  { "<leader>a", group = "ai (Claude)", mode = { "n", "v" } },
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
        dashboard = {
          enabled = true,
          -- Snacks' own "startup" section asks lazy.nvim for its numbers,
          -- which this config doesn't have; this one asks config.lazy.
          sections = {
            { section = "header" },
            { section = "keys", gap = 1, padding = 1 },
            function()
              local n, count = lazy.stats()
              local ms = (vim.uv.hrtime() - (vim.g.config_start_ns or vim.uv.hrtime())) / 1e6
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
        image = { enabled = true },
        indent = { enabled = true },
        input = { enabled = true },
        picker = { enabled = true },
        notifier = { enabled = true },
        -- exclude haskell: its treesitter parser corrupts the heap (see lang/haskell.lua)
        quickfile = { enabled = true, exclude = { "haskell" } },
        scope = { enabled = true },
        scroll = { enabled = true },
        statuscolumn = { enabled = true },
        words = { enabled = true },
      })
    end,
  })
  lazy.add({
    src = "https://github.com/echasnovski/mini.nvim",
    lazy = false,
    config = function() require("mini.statusline").setup({ use_icons = true }) end,
  })
  -- Eager: setup() also takes over f/t/F/T, which should work from the start.
  lazy.add({ src = "https://github.com/folke/flash.nvim", lazy = false, config = function() require("flash").setup({}) end })
  lazy.add("https://github.com/chrisgrieser/nvim-spider")
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
  vim.keymap.set("n", "gd", function() Snacks.picker.lsp_definitions() end, { desc = "Goto Definition" })
  vim.keymap.set("n", "gD", function() Snacks.picker.lsp_declarations() end, { desc = "Goto Declaration" })
  vim.keymap.set("n", "gr", function() Snacks.picker.lsp_references() end, { nowait = true, desc = "References" })
  vim.keymap.set("n", "gI", function() Snacks.picker.lsp_implementations() end, { desc = "Goto Implementation" })

  -- ── Motions: flash + spider ───────────────────────────────────────────
  vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash" })
  vim.keymap.set({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })
  vim.keymap.set("o", "r", function() require("flash").remote() end, { desc = "Remote Flash" })
  vim.keymap.set({ "o", "x" }, "R", function() require("flash").treesitter_search() end, { desc = "Treesitter Search" })
  vim.keymap.set("c", "<c-s>", function() require("flash").toggle() end, { desc = "Toggle Flash Search" })

  -- Note: <leader>e is the file explorer (above), so spider only takes w/b here.
  vim.keymap.set({ "n", "o", "x" }, "<leader>w", function() require("spider").motion("w") end, { desc = "Spider-w" })
  vim.keymap.set({ "n", "o", "x" }, "<leader>b", function() require("spider").motion("b") end, { desc = "Spider-b" })

  -- ── Diagnostics (trouble) ─────────────────────────────────────────────
  vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
  vim.keymap.set("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer Diagnostics" })
  vim.keymap.set("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols" })
  vim.keymap.set("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "LSP refs" })
  vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List" })
  vim.keymap.set("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List" })
end

return M
