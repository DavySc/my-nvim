
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

      -- LSP setup for OCaml
      require('lspconfig').ocamllsp.setup({})

      -- Treesitter configuration
      require('nvim-treesitter.configs').setup {
        ensure_installed = { 'ocaml' },
        highlight = { enable = true },
      }

      -- conform.nvim for formatting with ocamlformat
      require('conform').setup({
        formatters_by_ft = {
          ocaml = { 'ocamlformat' },
        },
        formatters = {
          ocamlformat = {
            prepend_args = {
              '--if-then-else', 'vertical',
              '--break-cases', 'fit-or-vertical',
              '--type-decl', 'sparse',
            },
          },
        },
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

