-- Plugins are managed by Neovim's native vim.pack (0.12+).
-- Update with :lua vim.pack.update()   Remove: delete the line + :lua vim.pack.del()

vim.pack.add({
  -- Theme (pinned: newer commits assume a newer nightly than installed, e.g. 'pumborder')
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin", version = "cb5665990a797b102715188e73c44c3931b3b42e" },

  -- Library
  "https://github.com/nvim-lua/plenary.nvim",

  -- Completion
  "https://github.com/hrsh7th/nvim-cmp",
  "https://github.com/hrsh7th/cmp-nvim-lsp",
  "https://github.com/hrsh7th/cmp-buffer",
  "https://github.com/hrsh7th/cmp-path",
  "https://github.com/L3MON4D3/LuaSnip",
  "https://github.com/saadparwaiz1/cmp_luasnip",
  "https://github.com/rafamadriz/friendly-snippets",

  -- LSP / tooling
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/williamboman/mason.nvim",
  -- pinned to master: the new default 'main' branch has a different, incompatible API
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "master" },
  "https://github.com/stevearc/conform.nvim",

  -- Languages
  "https://github.com/mrcjkb/rustaceanvim",
  "https://github.com/Julian/lean.nvim",

  -- Debugging
  "https://github.com/mfussenegger/nvim-dap",
  "https://github.com/rcarriga/nvim-dap-ui",
  "https://github.com/nvim-neotest/nvim-nio",

  -- UI / navigation
  "https://github.com/folke/snacks.nvim",
  "https://github.com/echasnovski/mini.nvim",
  "https://github.com/folke/flash.nvim",
  "https://github.com/chrisgrieser/nvim-spider",
  "https://github.com/folke/trouble.nvim",

  -- Git
  "https://github.com/NeogitOrg/neogit",
  "https://github.com/sindrets/diffview.nvim",
})

-- ── Theme ───────────────────────────────────────────────────────────────
require("catppuccin").setup({ transparent_background = true })
vim.cmd.colorscheme("catppuccin")

-- ── Completion ──────────────────────────────────────────────────────────
local cmp = require("cmp")
local luasnip = require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
  snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then cmp.select_next_item()
      elseif luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump()
      else fallback() end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then luasnip.jump(-1)
      else fallback() end
    end, { "i", "s" }),
  }),
  sources = cmp.config.sources(
    { { name = "nvim_lsp" }, { name = "luasnip" }, { name = "path" } },
    { { name = "buffer" } }
  ),
  completion = { completeopt = "menu,menuone,noinsert", keyword_length = 1 },
})

-- ── LSP (native vim.lsp; server defaults come from nvim-lspconfig) ───────
require("mason").setup()
local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.lsp.config("*", { capabilities = capabilities })

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim", "Snacks" } },
      workspace = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
})

vim.lsp.config("pyright", {
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
})

-- rust -> rustaceanvim, lean -> lean.nvim (configured below)
vim.lsp.enable({ "lua_ls", "pyright", "html", "cssls", "ts_ls" })

vim.api.nvim_create_autocmd("LspAttach", {
  desc = "LSP keymaps",
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true }
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
  end,
})

-- ── Treesitter ──────────────────────────────────────────────────────────
require("nvim-treesitter.configs").setup({
  ensure_installed = {
    "lua", "luadoc",
    "markdown", "markdown_inline",
    "html", "css",
    "javascript", "typescript", "tsx",
    "python", "rust",
    "vimdoc", "query",
  },
  highlight = { enable = true },
  indent = { enable = true },
  auto_install = true,
})

-- ── Formatting ──────────────────────────────────────────────────────────
require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "ruff_format" },
    rust = { "rustfmt" },
    html = { "prettier" },
    css = { "prettier" },
    javascript = { "prettier" },
    typescript = { "prettier" },
    javascriptreact = { "prettier" },
    typescriptreact = { "prettier" },
    markdown = { "prettier" },
  },
  format_on_save = { timeout_ms = 2000, lsp_format = "fallback" },
})

-- ── Rust (rustaceanvim) ─────────────────────────────────────────────────
vim.g.rustaceanvim = {
  server = {
    capabilities = capabilities,
    default_settings = {
      ["rust-analyzer"] = {
        cargo = { allFeatures = true },
        checkOnSave = true,
        check = { command = "clippy" },
        procMacro = { enable = true },
      },
    },
  },
  dap = {}, -- :MasonInstall codelldb to enable debugging
}
vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true }
    vim.keymap.set("n", "<leader>ca", function() vim.cmd.RustLsp("codeAction") end, opts)
    vim.keymap.set("n", "<leader>rr", function() vim.cmd.RustLsp("runnables") end, opts)
    vim.keymap.set("n", "<leader>dr", function() vim.cmd.RustLsp("debuggables") end, opts)
  end,
})

-- ── Lean 4 (lean.nvim) ──────────────────────────────────────────────────
vim.g.lean_config = {
  mappings = true,
  lsp = { capabilities = capabilities },
}

-- ── Debugging (nvim-dap) ────────────────────────────────────────────────
local dap, dapui = require("dap"), require("dapui")
dapui.setup()
dap.listeners.after.event_initialized["dapui_config"] = dapui.open
dap.listeners.before.event_terminated["dapui_config"] = dapui.close
dap.listeners.before.event_exited["dapui_config"] = dapui.close
vim.keymap.set("n", "<leader>db", function() dap.toggle_breakpoint() end, { desc = "DAP: Breakpoint" })
vim.keymap.set("n", "<leader>dc", function() dap.continue() end, { desc = "DAP: Continue" })
vim.keymap.set("n", "<leader>ds", function() dap.step_over() end, { desc = "DAP: Step over" })
vim.keymap.set("n", "<leader>di", function() dap.step_into() end, { desc = "DAP: Step into" })
vim.keymap.set("n", "<leader>do", function() dap.step_out() end, { desc = "DAP: Step out" })
vim.keymap.set("n", "<leader>du", function() dapui.toggle() end, { desc = "DAP: UI toggle" })

-- ── UI: pickers, explorer, statusline ───────────────────────────────────
require("snacks").setup({
  bigfile = { enabled = true },
  dashboard = { enabled = true },
  image = { enabled = true },
  indent = { enabled = true },
  input = { enabled = true },
  picker = { enabled = true },
  notifier = { enabled = true },
  quickfile = { enabled = true },
  scope = { enabled = true },
  scroll = { enabled = true },
  statuscolumn = { enabled = true },
  words = { enabled = true },
})
require("mini.statusline").setup({ use_icons = true })

vim.keymap.set("n", "<leader>fg", function() Snacks.picker.grep() end, { desc = "Grep" })
vim.keymap.set("n", "<leader>,", function() Snacks.picker.buffers() end, { desc = "Buffers" })
vim.keymap.set("n", "<leader>ff", function() Snacks.picker.smart() end, { desc = "Find Files" })
vim.keymap.set("n", "<leader>e", function() Snacks.explorer() end, { desc = "File Explorer" })
vim.keymap.set("n", "gd", function() Snacks.picker.lsp_definitions() end, { desc = "Goto Definition" })
vim.keymap.set("n", "gD", function() Snacks.picker.lsp_declarations() end, { desc = "Goto Declaration" })
vim.keymap.set("n", "gr", function() Snacks.picker.lsp_references() end, { nowait = true, desc = "References" })
vim.keymap.set("n", "gI", function() Snacks.picker.lsp_implementations() end, { desc = "Goto Implementation" })

-- ── Motions: flash + spider ─────────────────────────────────────────────
require("flash").setup({})
vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash" })
vim.keymap.set({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })
vim.keymap.set("o", "r", function() require("flash").remote() end, { desc = "Remote Flash" })
vim.keymap.set({ "o", "x" }, "R", function() require("flash").treesitter_search() end, { desc = "Treesitter Search" })
vim.keymap.set("c", "<c-s>", function() require("flash").toggle() end, { desc = "Toggle Flash Search" })

-- Note: <leader>e is the file explorer (above), so spider only takes w/b here.
vim.keymap.set({ "n", "o", "x" }, "<leader>w", function() require("spider").motion("w") end, { desc = "Spider-w" })
vim.keymap.set({ "n", "o", "x" }, "<leader>b", function() require("spider").motion("b") end, { desc = "Spider-b" })

-- ── Diagnostics (trouble) ───────────────────────────────────────────────
require("trouble").setup({})
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
vim.keymap.set("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer Diagnostics" })
vim.keymap.set("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols" })
vim.keymap.set("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "LSP refs" })
vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List" })
vim.keymap.set("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List" })

-- ── Git (neogit) ────────────────────────────────────────────────────────
require("neogit").setup({})
vim.keymap.set("n", "<leader>gg", function() require("neogit").open() end, { desc = "Neogit" })
