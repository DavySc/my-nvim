-- Racket. Nothing from mason: the server and formatter are raco packages,
--   raco pkg install racket-langserver fmt
-- <leader>mr runs the file, <leader>mc opens a REPL with it loaded.

---@type Lang
return {
  ft = { "racket" },
  parsers = { "racket" },
  setup = function()
    vim.lsp.config("racket_langserver", { filetypes = { "racket" } })
    require("config.core.lsp").enable({ "racket_langserver" })
    require("config.core.format").add({ racket = { "racketfmt" } })

    local function term(cmd)
      local file = vim.api.nvim_buf_get_name(0)
      Snacks.terminal.open(vim.list_extend(cmd, { file }), {
        cwd = vim.fs.dirname(file),
        win = { position = "bottom", height = 0.35 },
      })
    end
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "racket",
      callback = function(ev)
        vim.keymap.set("n", "<leader>mr", function() term({ "racket" }) end, { buffer = ev.buf, desc = "Racket: run" })
        vim.keymap.set("n", "<leader>mc", function() term({ "racket", "-i", "-t" }) end, { buffer = ev.buf, desc = "Racket: REPL" })
      end,
    })
  end,
}
