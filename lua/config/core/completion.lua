-- nvim-cmp + LuaSnip, loaded on the first InsertEnter or when the first
-- language attaches an LSP (for the completion capabilities), whichever comes
-- first. Languages add sources with M.source() (dbbliss does, for SQL).

local lazy = require("config.lazy")

local M = {}

local PLUGINS = {
  "https://github.com/hrsh7th/nvim-cmp",
  "https://github.com/hrsh7th/cmp-nvim-lsp",
  "https://github.com/hrsh7th/cmp-buffer",
  "https://github.com/hrsh7th/cmp-path",
  "https://github.com/L3MON4D3/LuaSnip",
  "https://github.com/saadparwaiz1/cmp_luasnip",
  "https://github.com/rafamadriz/friendly-snippets",
}

---@type table<string, table[]> filetype -> extra cmp sources
local ft_sources = {}

local function setup()
  local cmp = require("cmp")
  local luasnip = require("luasnip")
  require("luasnip.loaders.from_vscode").lazy_load()
  -- This config's own snippets (snippets/<filetype>.lua).
  require("luasnip.loaders.from_lua").lazy_load({ paths = { vim.fs.joinpath(vim.fn.stdpath("config"), "snippets") } })

  cmp.setup({
    snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    -- Vim's own popup keys work as in a plain vim: <C-n>/<C-p> pick, <C-y>
    -- accepts, <C-e> closes (preset.insert). Enter accepts only an item you
    -- picked; otherwise it is a new line, so typing prose or ending a SQL line
    -- never turns into a completion.
    mapping = cmp.mapping.preset.insert({
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<CR>"] = cmp.mapping.confirm({ select = false }),
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then cmp.select_next_item()
        elseif luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump()
        else fallback() end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then luasnip.jump(-1)
        else fallback() end
      end, { "i", "s" }),
    }),
    sources = cmp.config.sources(
      { { name = "nvim_lsp" }, { name = "luasnip" }, { name = "path" } },
      { { name = "buffer" } }
    ),
    completion = { completeopt = "menu,menuone,noinsert", keyword_length = 1 },
  })
  for ft, spec in pairs(ft_sources) do
    cmp.setup.filetype(ft, { sources = cmp.config.sources(spec[1], spec[2]) })
  end

  vim.lsp.config("*", { capabilities = require("cmp_nvim_lsp").default_capabilities() })
end

function M.declare()
  for _, src in ipairs(PLUGINS) do lazy.add(src) end
  -- One trigger for the lot: the sources' after/plugin files need cmp itself.
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = vim.api.nvim_create_augroup("config-completion", { clear = true }),
    once = true,
    callback = function() M.load() end,
  })
end

local done = false
--- Load the completion stack (idempotent).
function M.load()
  if done then return end
  done = true
  for _, src in ipairs(PLUGINS) do lazy.load(src:match("[^/]+$")) end
  setup()
end

--- Use these sources in buffers of filetype `ft`, ahead of `fallback` (default:
--- buffer words).
---@param ft string
---@param sources table[] cmp source entries, e.g. { { name = "dbbliss" } }
---@param fallback? table[] the group offered when `sources` have nothing
function M.source(ft, sources, fallback)
  ft_sources[ft] = { sources, fallback or { { name = "buffer" } } }
  if done then
    local cmp = require("cmp")
    cmp.setup.filetype(ft, { sources = cmp.config.sources(sources, ft_sources[ft][2]) })
  end
end

return M
