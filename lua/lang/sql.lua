-- SQL: T-SQL (SQL Server) and PostgreSQL, through dbbliss.nvim for running
-- queries, completion of live table/column names, plans and the schema tree.
-- See :help dbbliss. No other SQL client or generic SQL server (sqls): they'd
-- overlap it.
--
-- Both dialects share the `sql` filetype, so the dialect is decided per
-- buffer by M.dialect() below; it drives sqlfluff's --dialect.

local M = {}

local ENGINE_DIALECT = { postgres = "postgres", sqlserver = "tsql" }
local EXT_DIALECT = { pgsql = "postgres", psql = "postgres", tsql = "tsql" }

---@type Machine
local machine

--- The dialect of `bufnr` and whether something said so explicitly. First
--- match wins: the engine of the dbbliss connection the buffer runs on, the
--- extension (.pgsql/.psql, .tsql), b:sql_dialect (set it in a modeline-ish
--- `-- vim: let` line or by hand), then the machine default.
---@param bufnr integer
---@return "tsql"|"postgres" dialect, boolean explicit
function M.dialect(bufnr)
  local ok, conn = pcall(function() return require("dbbliss")._completion_connection(bufnr) end)
  if ok and conn and ENGINE_DIALECT[conn.engine] then return ENGINE_DIALECT[conn.engine], true end
  local ext = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":e"):lower()
  if EXT_DIALECT[ext] then return EXT_DIALECT[ext], true end
  local b = vim.b[bufnr].sql_dialect
  if b == "tsql" or b == "postgres" then return b, true end
  return machine.sql.dialect, false
end

local function has_sqlfluff_config(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
  return vim.fs.find({ ".sqlfluff", "pyproject.toml", "setup.cfg", "tox.ini" }, { path = dir, upward = true })[1] ~= nil
end

M.ft = { "sql" }
M.tools = { sqlfluff = "sqlfluff" }
M.parsers = { "sql" }
M.plugins = {
  {
    src = "https://github.com/DavySc/dbbliss.nvim",
    cmd = { "Dbbliss" },
    -- The .NET backend has to be built once per install/update (needs the
    -- .NET 10 SDK); asynchronous, reports when done. :checkhealth dbbliss.
    build = function() require("dbbliss.build").run() end,
    config = function()
      require("dbbliss").setup(require("config.machine").dbbliss)
      local completion = require("config.core.completion")
      completion.load()
      -- A config reload runs this again: one dbbliss source, not two.
      local cmp = require("cmp")
      if vim.g.config_dbbliss_cmp then cmp.unregister_source(vim.g.config_dbbliss_cmp) end
      vim.g.config_dbbliss_cmp = cmp.register_source("dbbliss", require("dbbliss.completion.cmp").new())
      completion.source("sql", { { name = "dbbliss" }, { name = "nvim_lsp" }, { name = "luasnip" } })
    end,
  },
}

---@param m Machine
function M.declare(m)
  machine = m
  vim.filetype.add({ extension = { pgsql = "sql", psql = "sql", tsql = "sql" } })
end

function M.setup()
  -- Formats with sqlfluff in the buffer's dialect. On save only when the
  -- project has a sqlfluff config (like clang-format: no silent rewrites of
  -- someone else's style); :Format always. An explicit buffer dialect wins
  -- over the project's; otherwise the project's config decides.
  require("config.core.format").add({ sql = { "sqlfluff" } })
  require("config.core.format").formatter("sqlfluff", {
    require_cwd = false,
    -- 1 = fixed what it could, some lint left: still a formatted result.
    exit_codes = { 0, 1 },
    args = function(_, ctx)
      local dialect, explicit = M.dialect(ctx.buf)
      if not explicit and has_sqlfluff_config(ctx.buf) then return { "fix", "-" } end
      return { "fix", "--dialect", dialect, "-" }
    end,
  })
  require("config.core.format").guard({ "sql" }, has_sqlfluff_config)

  -- PostgreSQL only, and only in projects with a postgres-language-server.jsonc
  -- (nvim-lspconfig's root marker; workspace_required). Not installed by
  -- mason here: see https://pg-language-server.com for the binary.
  require("config.core.lsp").enable({ "postgres_lsp" })
end

return M
