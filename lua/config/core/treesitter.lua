-- Treesitter (nvim-treesitter main branch; needs tree-sitter-cli on PATH).
-- Languages list their parsers; the missing ones are installed in the
-- background shortly after startup. Highlighting and indentation start on
-- FileType for any buffer whose parser is present.

local lazy = require("config.lazy")

local M = {}

local parsers = { "lua", "luadoc", "markdown", "markdown_inline", "vimdoc", "query" }

---@param list string[]
function M.parsers(list) vim.list_extend(parsers, list) end

function M.declare()
  -- Eager: its queries/ must be on 'runtimepath' before the first buffer.
  lazy.add({ src = "https://github.com/nvim-treesitter/nvim-treesitter", lazy = false })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config-treesitter", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    desc = "Start treesitter highlighting + indentation when a parser exists",
    callback = function(ev)
      if pcall(vim.treesitter.start, ev.buf) then
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end,
  })

  vim.defer_fn(function()
    local ts = require("nvim-treesitter")
    local installed = {}
    for _, p in ipairs(ts.get_installed()) do installed[p] = true end
    local missing = vim.tbl_filter(function(p) return not installed[p] end, parsers)
    if #missing == 0 then return end
    if vim.fn.executable("tree-sitter") == 0 then
      vim.notify("treesitter: tree-sitter CLI not on PATH (parsers can't be built)", vim.log.levels.WARN)
    end
    ts.install(missing)
  end, 500)
end

return M
