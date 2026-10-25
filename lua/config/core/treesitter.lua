-- Treesitter (nvim-treesitter main branch; needs tree-sitter-cli on PATH).
-- Languages list their parsers; the missing ones are installed in the
-- background shortly after startup. Highlighting and indentation start on
-- FileType for any buffer whose parser is present.

local lazy = require("config.lazy")

local M = {}

local parsers = { "lua", "luadoc", "markdown", "markdown_inline", "vimdoc", "query" }
---@type table<string, table> out-of-tree grammars: name -> nvim-treesitter parser entry
local extra = {}
---@type table<string, boolean> filetypes that must not get treesitter
local skip = {}

---@param list string[]
function M.parsers(list) vim.list_extend(parsers, list) end

--- Register a grammar that isn't in nvim-treesitter's registry.
function M.register(name, info) extra[name] = info end

--- Keep treesitter off for these filetypes (regex syntax instead).
function M.skip(fts) for _, ft in ipairs(fts) do skip[ft] = true end end

function M.declare()
  -- Eager: its queries/ must be on 'runtimepath' before the first buffer.
  lazy.add({ src = "https://github.com/nvim-treesitter/nvim-treesitter", lazy = false })
end

function M.setup()
  -- nvim-treesitter reloads its parser table on every install/update and fires
  -- `User TSUpdate` so out-of-tree grammars can re-register.
  vim.api.nvim_create_autocmd("User", {
    pattern = "TSUpdate",
    desc = "Register grammars that aren't in nvim-treesitter's registry",
    callback = function()
      local registry = require("nvim-treesitter.parsers")
      for name, info in pairs(extra) do registry[name] = info end
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    desc = "Start treesitter highlighting + indentation when a parser exists",
    callback = function(ev)
      if skip[ev.match] then return end
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
