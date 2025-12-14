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
      -- Mason setup (Ensure 'zls' is installed here if not using system package manager)
      require('mason').setup()

      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local lspconfig = require('lspconfig')

      -- Zig LSP (zls)
      -- Ensure 'zls' is installed on your system or via Mason
      lspconfig.zls.setup({
        capabilities = capabilities,
      })

      -- Haskell LSP
      lspconfig.hls.setup({ capabilities = capabilities })

      -- C++ (and WASM via clangd) LSP
      lspconfig.clangd.setup({
        capabilities = capabilities,
      })


      -- Treesitter configuration
      require('nvim-treesitter.configs').setup {
        -- Added 'zig', removed 'asm' (optional, add back if you read assembly often)
        ensure_installed = { 
            'markdown', 'markdown_inline', 'rust', 'haskell', 
            'html', 'css', 'cpp', 'c', 'regex', 'zig' 
        },
        highlight = { enable = true },
        indent = { enable = true },
        auto_install = true,
      }

      -- Formatters
      require('conform').setup({
        formatters_by_ft = {
          haskell = { 'ormolu' },
          cpp = { 'clang_format' },
          c = { 'clang_format' },
          rust = { 'rustfmt' },
          zig = { 'zigfmt' }, -- Uses the built-in 'zig fmt'
        },
      })
    end,
  },
}
