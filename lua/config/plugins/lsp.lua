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
      -- Mason setup
      require('mason').setup()

      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- Haskell LSP
      require('lspconfig').hls.setup({capabilities = capabilities,})

      -- C++ (and WASM via clangd) LSP
      require('lspconfig').clangd.setup({
        capabilities = capabilities,
        -- Optionally, add cmd = { "clangd", "--compile-commands-dir=build" }, if needed
      })

      -- TypeScript/JavaScript LSP (ts_ls)
      -- Show inlay hints (requires Neovim 0.10+ or plugin support)
      require('lspconfig').ts_ls.setup({
        capabilities = capabilities,
        init_options = {
          preferences = {
            includeInlayParameterNameHints = true,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayVariableTypeHints = true,
            includeInlayPropertyDeclarationTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
            includeInlayEnumMemberValueHints = true,
          }
        }
      })
	    
     require('lspconfig').eslint.setup({
       capabilities = capabilities,
     })

      -- Treesitter configuration for Haskell, C, and C++
      require('nvim-treesitter.configs').setup {
        ensure_installed = {'markdown', 'markdown_inline', 'rust', 'haskell','html','css', 'cpp', 'c', 'regex', 'tsx', 'javascript', 'typescript'}, -- add other languages as needed
        highlight = { enable = true },
        indent = { enable = true },
        auto_install = true,
      }
      

require('lspconfig').veryl_ls.setup({
  cmd = { 'veryl-ls' },
  filetypes = { 'veryl' },
  root_dir = require('lspconfig.util').root_pattern('Veryl.toml', '.git'),
  on_attach = function(client, bufnr)
    local opts = { noremap=true, silent=true, buffer=bufnr }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  end,
})
      -- Formatters: ormolu for Haskell and clang-format for C/C++
      require('conform').setup({
        formatters_by_ft = {
          haskell = { 'ormolu' },
          cpp = { 'clang_format' },
          c = { 'clang_format' },
	  rust = { 'rustfmt' },
        },
      })

    end,
  },
}
