return{
require('lspconfig').zls.setup({
  cmd = { 'zls' },
  settings = {
    zls = {
      enable_build_on_save = true,
      build_on_save_step = "check",
      enable_snippets = true,
      semantic_tokens = "partial",
      zig_exe_path = nil -- or specify: '/usr/local/bin/zig'
    }
  },
  on_attach = function(client, bufnr)
    -- Format on save
    vim.api.nvim_create_autocmd("BufWritePre", {
      pattern = {"*.zig", "*.zon"},
      callback = function()
        vim.lsp.buf.format()
      end
    })
    
    -- Keybindings
    local opts = { noremap=true, silent=true, buffer=bufnr }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  end,
})
}
