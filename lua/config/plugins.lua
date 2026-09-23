-- Plugins are managed by Neovim's native vim.pack (0.12+).
-- Update with :lua vim.pack.update()   Remove: delete the line + :lua vim.pack.del()

vim.pack.add({
  -- Theme
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },

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
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/stevearc/conform.nvim",

  -- Languages
  "https://github.com/p00f/clangd_extensions.nvim",

  -- Debugging
  "https://github.com/mfussenegger/nvim-dap",
  "https://github.com/rcarriga/nvim-dap-ui",
  "https://github.com/theHamsta/nvim-dap-virtual-text",
  "https://github.com/nvim-neotest/nvim-nio",

  -- UI / navigation
  "https://github.com/folke/snacks.nvim",
  "https://github.com/echasnovski/mini.nvim",
  "https://github.com/folke/flash.nvim",
  "https://github.com/chrisgrieser/nvim-spider",
  "https://github.com/folke/trouble.nvim",

  -- Git
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/NeogitOrg/neogit",

  -- Keymap discoverability
  "https://github.com/folke/which-key.nvim",
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

-- Make a fresh machine (Windows especially) self-sufficient: install any tool
-- that isn't already on PATH. Runs async; restart nvim once it finishes.
local function ensure_tools(tools)
  local ok, registry = pcall(require, "mason-registry")
  if not ok then return end
  registry.refresh(function()
    for name, exe in pairs(tools) do
      if vim.fn.executable(exe) == 0 then
        local found, pkg = pcall(registry.get_package, name)
        if found and not pkg:is_installed() and not pkg:is_installing() then
          vim.notify("mason: installing " .. name)
          pkg:install()
        end
      end
    end
  end)
end
ensure_tools({
  clangd = "clangd",
  ["clang-format"] = "clang-format",
  codelldb = "codelldb",
  ["lua-language-server"] = "lua-language-server",
  stylua = "stylua",
  ["nil"] = "nil",
  nixfmt = "nixfmt",
  ["haskell-language-server"] = "haskell-language-server-wrapper",
  fourmolu = "fourmolu",
})
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

-- C/C++. nvim-lspconfig supplies filetypes, root markers, the utf-8 offset
-- encoding clangd prefers, and the :LspClangd* commands; the flags below are
-- what it does not set.
vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--all-scopes-completion",
    "--function-arg-placeholders",
    -- Insert the header the completed symbol lives in, honouring IWYU pragmas.
    "--header-insertion=iwyu",
    "--header-insertion-decorators",
    -- Without a compile_commands.json, format/parse as LLVM rather than bail.
    "--fallback-style=llvm",
    "--enable-config", -- honour .clangd files in the project
    "--pch-storage=memory",
    "-j=" .. math.max(2, math.floor(#(vim.uv.cpu_info() or {}) / 2)),
  },
  init_options = {
    usePlaceholders = true,
    completeUnimported = true,
    clangdFileStatus = true,
  },
})

-- Nix. `nil` (mason has no nixd) gives diagnostics, completion, go-to-def and
-- rename. Formatting is left to conform (nixfmt), so nil's own is unused.
vim.lsp.config("nil_ls", {
  settings = { ["nil"] = { formatting = { command = { "nixfmt" } } } },
})

-- Haskell (and Clash, which is plain Haskell under the hood). Widen past
-- nvim-lspconfig's default filetypes so .cabal files get diagnostics too.
-- Formatting is left to conform (fourmolu), so HLS's own is unused.
-- HLS must be built against the same GHC as the project. In a flake project
-- run it through `nix develop` so it sees the flake's ghc/cabal/HLS (nvim
-- itself usually isn't started from inside the dev shell); otherwise use PATH.
vim.lsp.config("hls", {
  filetypes = { "haskell", "lhaskell", "cabal" },
  cmd = function(dispatchers, config)
    local root = config.root_dir
    local cmd = { "haskell-language-server-wrapper", "--lsp" }
    if root and not vim.env.IN_NIX_SHELL and vim.uv.fs_stat(root .. "/flake.nix") then
      cmd = vim.list_extend({ "nix", "develop", root, "--command" }, cmd)
    end
    return vim.lsp.rpc.start(cmd, dispatchers, { cwd = root })
  end,
  -- Semantic tokens (off by default in HLS) stand in for treesitter
  -- highlighting, which is disabled for Haskell (see the FileType autocmd).
  settings = {
    haskell = { plugin = { semanticTokens = { globalOn = true } } },
  },
})

vim.lsp.enable({ "lua_ls", "clangd", "nil_ls", "hls" })

-- clang-tidy findings are worth reading inline; the default only shows signs.
vim.diagnostic.config({
  virtual_text = { spacing = 2, source = "if_many", prefix = "●" },
  severity_sort = true,
  underline = true,
  float = { border = "rounded", source = "if_many" },
})

vim.api.nvim_create_autocmd("LspAttach", {
  desc = "LSP keymaps",
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true }
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)

    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/inlayHint") then
      vim.keymap.set("n", "<leader>uh", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
      end, vim.tbl_extend("force", opts, { desc = "Toggle inlay hints" }))
    end
  end,
})

-- :ClangdAST / :ClangdTypeHierarchy / :ClangdMemoryUsage. Inlay hints are
-- native (<leader>uh above), so the plugin's own renderer stays off.
require("clangd_extensions").setup({ inlay_hints = { inline = false } })

-- ── Souffle datalog (*.dl) ──────────────────────────────────────────────
-- No plugin needed: filetype below, treesitter parser registered just after,
-- queries in queries/souffle/, buffer-local bits in ftplugin/souffle.lua.
vim.filetype.add({ extension = { dl = "souffle" } })

-- ── Treesitter (main branch; needs tree-sitter-cli on PATH) ─────────────
-- nvim-treesitter reloads its parser table on every install/update and fires
-- `User TSUpdate` so out-of-tree grammars can re-register. Must be declared
-- before the install() call below.
vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  desc = "Register grammars that aren't in nvim-treesitter's registry",
  callback = function()
    require("nvim-treesitter.parsers").souffle = {
      install_info = {
        url = "https://github.com/langston-barrett/tree-sitter-souffle",
        revision = "0ca94fad4422bc9a391f81418b5716e3af00ed2f",
      },
      tier = 3,
    }
  end,
})

if vim.fn.executable("tree-sitter") == 0 then
  vim.notify("treesitter: tree-sitter CLI not on PATH (parsers can't be built)", vim.log.levels.WARN)
end
require("nvim-treesitter").install({
  "lua", "luadoc",
  "markdown", "markdown_inline",
  "nix",
  "sql",
  -- C/C++: doxygen is injected into /** */ comments, printf into format
  -- strings, cmake/make for the build files.
  "c", "cpp", "doxygen", "printf", "cmake", "make",
  "souffle",
  "vimdoc", "query",
})
vim.api.nvim_create_autocmd("FileType", {
  desc = "Start treesitter highlighting + indentation when a parser exists",
  callback = function(ev)
    -- tree-sitter-haskell's scanner corrupts the heap (glibc "corrupted size vs.
    -- prev_size" aborts while editing), so Haskell gets regex syntax plus HLS
    -- semantic tokens instead.
    if ev.match == "haskell" or ev.match == "lhaskell" then return end
    if pcall(vim.treesitter.start, ev.buf) then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- ── Formatting ──────────────────────────────────────────────────────────
require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    nix = { "nixfmt" },
    c = { "clang-format" },
    cpp = { "clang-format" },
    cuda = { "clang-format" },
    objc = { "clang-format" },
    objcpp = { "clang-format" },
    haskell = { "fourmolu" },
    lhaskell = { "fourmolu" },
  },
  format_on_save = function(bufnr)
    -- clang-format always has an opinion: with no .clang-format in the tree it
    -- silently rewrites the whole file to LLVM style. Only format C/C++ on save
    -- when the project actually pins a style.
    local ft = vim.bo[bufnr].filetype
    if ft == "c" or ft == "cpp" or ft == "cuda" or ft == "objc" or ft == "objcpp" then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local dir = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
      if not vim.fs.find({ ".clang-format", "_clang-format" }, { path = dir, upward = true })[1] then
        return nil
      end
    end
    return { timeout_ms = 2000, lsp_format = "fallback" }
  end,
})
-- :Format works regardless of the rule above, for one-off reformatting.
vim.api.nvim_create_user_command("Format", function(opts)
  local range
  if opts.count ~= -1 then
    range = { start = { opts.line1, 0 }, ["end"] = { opts.line2, math.huge } }
  end
  require("conform").format({ async = true, lsp_format = "fallback", range = range })
end, { range = true, desc = "Format buffer or range" })

-- ── Debugging (nvim-dap) ────────────────────────────────────────────────
local dap, dapui = require("dap"), require("dapui")
dapui.setup()
require("nvim-dap-virtual-text").setup({ virt_text_pos = "eol" })
dap.listeners.after.event_initialized["dapui_config"] = dapui.open
dap.listeners.before.event_terminated["dapui_config"] = dapui.close
dap.listeners.before.event_exited["dapui_config"] = dapui.close

-- codelldb comes from mason (installed below). On Windows mason's PATH entry is
-- a .cmd shim, which libuv can't spawn directly, so use the real binary.
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

--- Executable to debug: the CMake target if this buffer is in a project,
--- otherwise ask. Runs inside dap's coroutine, so a blocking prompt is fine.
local function debug_program()
  local project = require("config.cmake").project()
  if project and project.target then
    return project.target.path
  end
  local dir = project and project.build or vim.uv.cwd()
  return vim.fn.input({ prompt = "Executable: ", default = dir .. "/", completion = "file" })
end

dap.configurations.cpp = {
  {
    name = "Launch (codelldb)",
    type = "codelldb",
    request = "launch",
    program = debug_program,
    cwd = "${workspaceFolder}",
    args = {},
    stopOnEntry = false,
    console = "integratedTerminal",
  },
  {
    name = "Launch (gdb)",
    type = "gdb",
    request = "launch",
    program = debug_program,
    cwd = "${workspaceFolder}",
    stopAtBeginningOfMainSubprogram = false,
  },
  {
    name = "Attach to process",
    type = "codelldb",
    request = "attach",
    pid = function() return require("dap.utils").pick_process() end,
    cwd = "${workspaceFolder}",
  },
}
dap.configurations.c = dap.configurations.cpp

vim.keymap.set("n", "<leader>db", function() dap.toggle_breakpoint() end, { desc = "DAP: Breakpoint" })
vim.keymap.set("n", "<leader>dB", function()
  vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
    if cond then dap.set_breakpoint(cond) end
  end)
end, { desc = "DAP: Conditional breakpoint" })
vim.keymap.set("n", "<leader>dc", function() dap.continue() end, { desc = "DAP: Continue" })
vim.keymap.set("n", "<leader>ds", function() dap.step_over() end, { desc = "DAP: Step over" })
vim.keymap.set("n", "<leader>di", function() dap.step_into() end, { desc = "DAP: Step into" })
vim.keymap.set("n", "<leader>do", function() dap.step_out() end, { desc = "DAP: Step out" })
vim.keymap.set("n", "<leader>du", function() dapui.toggle() end, { desc = "DAP: UI toggle" })
vim.keymap.set("n", "<leader>dl", function() dap.run_last() end, { desc = "DAP: Run last" })
vim.keymap.set("n", "<leader>dq", function() dap.terminate() end, { desc = "DAP: Terminate" })
vim.keymap.set({ "n", "v" }, "<leader>de", function() dapui.eval(nil, { enter = true }) end, { desc = "DAP: Eval" })

-- ── CMake driver (lua/config/cmake.lua) ─────────────────────────────────
require("config.cmake").setup()

-- ── UI: pickers, explorer, statusline ───────────────────────────────────
require("snacks").setup({
  bigfile = { enabled = true },
  dashboard = { enabled = true },
  image = { enabled = true },
  indent = { enabled = true },
  input = { enabled = true },
  picker = { enabled = true },
  notifier = { enabled = true },
  -- exclude haskell: its treesitter parser corrupts the heap (see FileType autocmd)
  quickfile = { enabled = true, exclude = { "haskell" } },
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

-- ── Git ─────────────────────────────────────────────────────────────────
-- gitsigns: signs in the gutter + hunk actions on <leader>h.
-- snacks pickers: browse status/log/diff. neogit: the full commit/push UI.
require("gitsigns").setup({
  on_attach = function(buf)
    local gs = require("gitsigns")
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end
    map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
    map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")
    map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
    map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
    map("v", "<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage selection")
    map("v", "<leader>hr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset selection")
    map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
    map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
    map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
    map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
    map("n", "<leader>hd", gs.diffthis, "Diff against index")
    map("n", "<leader>ht", gs.toggle_current_line_blame, "Toggle inline blame")
    map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
  end,
})

require("neogit").setup({ integrations = { diffview = false, snacks = true } })
vim.keymap.set("n", "<leader>gg", function() require("neogit").open() end, { desc = "Neogit (commit/push/…)" })
vim.keymap.set("n", "<leader>gG", function() Snacks.lazygit() end, { desc = "Lazygit" })
vim.keymap.set("n", "<leader>gs", function() Snacks.picker.git_status() end, { desc = "Git status" })
vim.keymap.set("n", "<leader>gl", function() Snacks.picker.git_log() end, { desc = "Git log" })
vim.keymap.set("n", "<leader>gL", function() Snacks.picker.git_log_file() end, { desc = "Git log (file)" })
vim.keymap.set("n", "<leader>gd", function() Snacks.picker.git_diff() end, { desc = "Git diff (hunks)" })
vim.keymap.set("n", "<leader>gb", function() Snacks.picker.git_branches() end, { desc = "Git branches" })
vim.keymap.set("n", "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Open on GitHub" })

-- ── Keymap discovery: press <leader> and wait ───────────────────────────
require("which-key").setup({ delay = 400 })
require("which-key").add({
  { "<leader>g", group = "git" },
  { "<leader>m", group = "make (C/C++, Haskell/Clash)" },
  { "<leader>h", group = "hunks", mode = { "n", "v" } },
  { "<leader>d", group = "debug" },
  { "<leader>f", group = "find" },
  { "<leader>x", group = "diagnostics" },
  { "<leader>c", group = "code" },
})
