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

  cmp.setup({
    snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<CR>"] = cmp.mapping.confirm({ select = true }),
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
  for ft, sources in pairs(ft_sources) do
    cmp.setup.filetype(ft, { sources = cmp.config.sources(sources, { { name = "buffer" } }) })
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

--- Use these sources (ahead of buffer words) in buffers of filetype `ft`.
---@param ft string
---@param sources table[] cmp source entries, e.g. { { name = "dbbliss" } }
function M.source(ft, sources)
  ft_sources[ft] = sources
  if done then
    local cmp = require("cmp")
    cmp.setup.filetype(ft, { sources = cmp.config.sources(sources, { { name = "buffer" } }) })
  end
end

return M
