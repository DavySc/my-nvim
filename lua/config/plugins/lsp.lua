return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'stevearc/conform.nvim',
    },
    config = function()
      require('mason').setup()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local lspconfig = require('lspconfig')

      -- Python LSP for z3-solver bindings (pip install z3-solver)
      -- Pyright gives you type inference, go-to-def, and hover docs on z3.* calls
      lspconfig.pyright.setup({
        capabilities = capabilities,
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",        -- "strict" if you want more noise
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,     -- resolves z3 stubs
            },
          },
        },
      })

      -- SMT-LIB2 (.smt2 / .z3) — no dedicated LSP exists, but
      -- nvim-lspconfig has no server for it; rely on Treesitter + syntax only.

      -- Treesitter
      require('nvim-treesitter.configs').setup {
        ensure_installed = {
          'markdown', 'markdown_inline',
          'python',          -- for z3-solver scripts
          'cpp', 'c',        -- z3 C/C++ API if you use it
          'regex',
          -- 'smtlib' is not in the mainline parser set yet;
          -- install manually if you find a community grammar
        },
        highlight = { enable = true },
        indent    = { enable = true },
        auto_install = true,
      }

      -- Formatters
      require('conform').setup({
        formatters_by_ft = {
          python = { 'black' },     -- or 'ruff_format' if you prefer ruff
          cpp    = { 'clang_format' },
          c      = { 'clang_format' },
        },
      })
    end,
  },
}
