-- SQL: T-SQL (SQL Server) and PostgreSQL, through dbbliss.nvim for running
-- queries, completion of live table/column names, plans and the schema tree.
-- See :help dbbliss. No other SQL client or generic SQL server (sqls): they'd
-- overlap it.
--
-- Both dialects share the `sql` filetype, so the dialect is decided per
-- buffer by M.dialect() below; it drives sqlfluff's --dialect.

local M = {}

local ENGINE_DIALECT = { postgres = "postgres", sqlserver = "tsql" }
local DIALECT_ENGINE = { postgres = "postgres", tsql = "sqlserver" }
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
  local ok, conn = pcall(function()
    local db = require("dbbliss")
    -- connection_of is the public form (dbbliss decision 80); older versions only had the private one.
    return db.connection_of and db.connection_of(bufnr) or db._completion_connection(bufnr)
  end)
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

local function has_sqldiff_config(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
  return vim.fs.find({ "sqldiff.toml" }, { path = dir, upward = true })[1] ~= nil
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
      -- With no connection open (the usual case here), completion still offers
      -- the keywords of the buffer's dialect; nothing is sent anywhere.
      -- Object info lives on K (after/ftplugin/sql.lua), not <M-F1>.
      local opts = vim.tbl_deep_extend("keep", require("config.machine").dbbliss, {
        mappings = { info = false },
        completion = {
          offline_engine = function(bufnr) return DIALECT_ENGINE[(M.dialect(bufnr))] end,
        },
      })
      require("dbbliss").setup(opts)
      local completion = require("config.core.completion")
      completion.load()
      require("cmp").register_source("dbbliss", require("dbbliss.completion.cmp").new())
      completion.source("sql", { { name = "dbbliss" }, { name = "nvim_lsp" }, { name = "luasnip" } })
    end,
  },
}

---@param m Machine
function M.declare(m)
  machine = m
  -- Neovim's SQL ftplugin maps 13 insert keys that start with <C-c> (its old
  -- omni completion), so <C-c> to leave insert mode waited a second.
  vim.g.omni_sql_no_default_maps = 1
  vim.filetype.add({ extension = { pgsql = "sql", psql = "sql", tsql = "sql" } })
end

function M.setup()
  -- Formats with sqlfluff in the buffer's dialect. On save only when the
  -- project has a sqlfluff config (like clang-format: no silent rewrites of
  -- someone else's style); :Format always. An explicit buffer dialect wins
  -- over the project's; otherwise the project's config decides.
  require("config.core.format").add({ sql = { "sqldiff" } })
  -- sqldiff fmt (SQLDiff repo, `cargo install`): whitespace and keyword case
  -- only, and every result is checked by the engine to mean the same thing.
  -- Reads the buffer on stdin (--stdin-filepath names it for config lookup).
  -- Layout comes from the project's sqldiff.toml; without one, keywords,
  -- functions and types go lowercase. Use sqlfluff instead with
  -- `:lua require("conform").format({formatters={"sqlfluff"}})`.
  require("config.core.format").formatter("sqldiff", {
    command = "sqldiff",
    args = function(_, ctx)
      local args = { "fmt", "-", "--stdin-filepath", ctx.filename, "--dialect", (M.dialect(ctx.buf)) }
      if not has_sqldiff_config(ctx.buf) then vim.list_extend(args, { "--keyword-case", "lower" }) end
      return args
    end,
  })
  require("config.core.format").formatter("sqlfluff", {
    require_cwd = false,
    -- 1 = fixed what it could, some lint left: still a formatted result.
    exit_codes = { 0, 1 },
    args = function(_, ctx)
      local dialect, explicit = M.dialect(ctx.buf)
      if not explicit and has_sqlfluff_config(ctx.buf) then return { "fix", "-" } end
      -- No project config: keywords, functions, literals and types lowercase.
      local lower = vim.fs.joinpath(vim.fn.stdpath("config"), "sqlfluff-lowercase.cfg")
      return { "fix", "--config", lower, "--dialect", dialect, "-" }
    end,
  })
  require("config.core.format").guard({ "sql" }, function(bufnr)
    return has_sqldiff_config(bufnr) or has_sqlfluff_config(bufnr)
  end)

  -- PostgreSQL only, and only in projects with a postgres-language-server.jsonc
  -- (nvim-lspconfig's root marker; workspace_required). Not installed by
  -- mason here: see https://pg-language-server.com for the binary.
  require("config.core.lsp").enable({ "postgres_lsp" })
end

return M
