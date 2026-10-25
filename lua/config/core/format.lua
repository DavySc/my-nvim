-- conform.nvim, loaded on the first save or :Format. Languages add their
-- formatters with M.add() and can veto format-on-save per buffer with M.guard().

local lazy = require("config.lazy")

local M = {}

---@type table<string, table>
local by_ft = {}
---@type table<string, fun(bufnr: integer): boolean>
local guards = {}

---@param fts table<string, table> filetype -> conform formatter list
function M.add(fts)
  by_ft = vim.tbl_extend("force", by_ft, fts)
  if lazy.is_loaded("conform.nvim") then
    local conform = require("conform")
    conform.formatters_by_ft = vim.tbl_extend("force", conform.formatters_by_ft, fts)
  end
end

---@type table<string, table>
local formatters = {}

--- Override or extend a conform formatter's definition (conform's
--- `formatters` option).
---@param name string
---@param def table
function M.formatter(name, def)
  formatters[name] = def
  if lazy.is_loaded("conform.nvim") then require("conform").formatters[name] = def end
end

--- Skip format-on-save for `ft` unless `pred(bufnr)` is true.
---@param fts string[]
---@param pred fun(bufnr: integer): boolean
function M.guard(fts, pred)
  for _, ft in ipairs(fts) do guards[ft] = pred end
end

function M.declare()
  lazy.add({
    src = "https://github.com/stevearc/conform.nvim",
    cmd = { "ConformInfo" },
    config = function() require("conform").setup({ formatters_by_ft = by_ft, formatters = formatters }) end,
  })
end

function M.setup()
  -- conform's own format_on_save is registered by setup(), too late for the
  -- save that loads it, so the autocmd lives here instead.
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("config-format", { clear = true }),
    desc = "Format on save",
    callback = function(ev)
      local guard = guards[vim.bo[ev.buf].filetype]
      if guard and not guard(ev.buf) then return end
      require("conform").format({ bufnr = ev.buf, timeout_ms = 2000, lsp_format = "fallback" })
    end,
  })

  -- :Format works regardless of the guards, for one-off reformatting.
  vim.api.nvim_create_user_command("Format", function(opts)
    local range
    if opts.count ~= -1 then
      range = { start = { opts.line1, 0 }, ["end"] = { opts.line2, math.huge } }
    end
    require("conform").format({ async = true, lsp_format = "fallback", range = range })
  end, { range = true, desc = "Format buffer or range" })
end

return M
