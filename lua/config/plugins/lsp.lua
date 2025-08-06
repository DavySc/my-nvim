return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
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

      -- Treesitter configuration for Haskell, C, and C++
      require('nvim-treesitter.configs').setup {
        ensure_installed = { 'haskell', 'cpp', 'c' }, -- add other languages as needed
        highlight = { enable = true },
        indent = { enable = true },
        auto_install = true,
      }

      -- Formatters: ormolu for Haskell and clang-format for C/C++
      require('conform').setup({
        formatters_by_ft = {
          haskell = { 'ormolu' },
          cpp = { 'clang_format' },
          c = { 'clang_format' },
        },
      })

      -- Telescope keybindings
      local opts = { noremap = true, silent = true }
      vim.api.nvim_set_keymap('n', '<leader>ff', '<cmd>Telescope find_files<cr>', opts)
      vim.api.nvim_set_keymap('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', opts)
      vim.api.nvim_set_keymap('n', '<leader>fb', '<cmd>Telescope buffers<cr>', opts)
      vim.api.nvim_set_keymap('n', '<leader>fm', '<cmd>Telescope marks<cr>', opts)
    end,
  },
}
