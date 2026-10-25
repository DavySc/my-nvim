-- Racket. Nothing from mason: the server and formatter are raco packages,
--   raco pkg install racket-langserver fmt
-- DrRacket's Run, Interactions, error boxes, macro stepper and binding arrows
-- come from lua/config/drracket (back end: racket/drracket.rkt):
--   <leader>mr run          <leader>mi Interactions    <leader>ms stop
--   <leader>me send form / selection to Interactions
--   <leader>mx macro stepper (file, or the selection)  <leader>mX every macro
--   <leader>ma binding arrows on/off                   <leader>md raco docs
--   <leader>mc a plain `racket -i` in a terminal, with the file loaded
--   <C-\> in insert mode types λ, as in DrRacket

---@type Lang
return {
  ft = { "racket" },
  parsers = { "racket" },
  setup = function()
    vim.lsp.config("racket_langserver", { filetypes = { "racket" } })
    require("config.core.lsp").enable({ "racket_langserver" })
    require("config.core.format").add({ racket = { "racketfmt" } })

    local drracket = require("config.drracket")
    drracket.setup()

    local function term(cmd)
      local file = vim.api.nvim_buf_get_name(0)
      Snacks.terminal.open(vim.list_extend(cmd, { file }), {
        cwd = vim.fs.dirname(file),
        win = { position = "bottom", height = 0.35 },
      })
    end
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("config-racket", { clear = true }),
      pattern = "racket",
      callback = function(ev)
        -- The macro stepper's buffer is racket too, but has no file to run.
        if vim.bo[ev.buf].buftype ~= "" then return end
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = "Racket: " .. desc })
        end
        map("n", "<leader>mr", function() drracket.run() end, "run")
        map("n", "<leader>mi", "<cmd>Racket interactions<cr>", "Interactions")
        map("n", "<leader>ms", "<cmd>Racket stop<cr>", "stop")
        map("n", "<leader>me", "<cmd>Racket send<cr>", "send form")
        map("x", "<leader>me", ":Racket send<cr>", "send selection")
        map("n", "<leader>mx", "<cmd>Racket expand<cr>", "macro stepper")
        map("x", "<leader>mx", ":Racket expand<cr>", "macro stepper (selection)")
        map("n", "<leader>mX", "<cmd>Racket! expand<cr>", "macro stepper, every macro")
        map("n", "<leader>ma", "<cmd>Racket arrows<cr>", "binding arrows")
        map("n", "<leader>md", function()
          vim.system({ "raco", "docs", vim.fn.expand("<cword>") }, { detach = true })
        end, "docs for word")
        map("n", "<leader>mc", function() term({ "racket", "-i", "-t" }) end, "terminal REPL")
        map("i", "<C-\\>", "λ", "λ")
      end,
    })
  end,
}
