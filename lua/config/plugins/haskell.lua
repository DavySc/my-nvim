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
      -- LSP setup for Haskell
      require('lspconfig').hls.setup({capabilities = capabilities,})

      -- Treesitter configuration for Haskell
      require('nvim-treesitter.configs').setup {
        ensure_installed = { 'haskell' },
        highlight = { enable = true },
        indent = { enable = true },
        auto_install = true,
      }

      -- conform.nvim for formatting with ormolu
      require('conform').setup({
        formatters_by_ft = {
          haskell = { 'ormolu' },
        },
        -- If you want to pass specific flags to ormolu:
        -- formatters = {
        --   ormolu = {
        --     prepend_args = {
        --       "--color", "always"
        --     },
        --   },
        -- },
      })

      -- Keybindings for Telescope fuzzy finder
      local opts = { noremap = true, silent = true }
      vim.api.nvim_set_keymap('n', '<leader>ff', '<cmd>Telescope find_files<cr>', opts)
      vim.api.nvim_set_keymap('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', opts)
      vim.api.nvim_set_keymap('n', '<leader>fb', '<cmd>Telescope buffers<cr>', opts)
      vim.api.nvim_set_keymap('n', '<leader>fm', '<cmd>Telescope marks<cr>', opts)
    end,
  },

}


