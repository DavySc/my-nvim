-- SQL snippets (LuaSnip, loaded by config/core/completion.lua). Lower case, as
-- the formatter writes it. Some differ by dialect: lang/sql.lua decides the
-- buffer's dialect (connection, .tsql/.pgsql, b:sql_dialect, machine default).
-- Globals s, t, i, fmt, rep come from LuaSnip's Lua loader.

local function dialect() return require("lang.sql").dialect(vim.api.nvim_get_current_buf()) end
local function tsql() return dialect() == "tsql" end
local function pg() return dialect() == "postgres" end
local only_tsql = { condition = tsql, show_condition = tsql }
local only_pg = { condition = pg, show_condition = pg }

return {
  s({ trig = "cte", desc = "with ... as (...) select" }, fmt([[
with {} as (
    {}
)
select {}
from {};]], { i(1, "cte"), i(2, "select 1"), i(3, "*"), rep(1) })),

  s({ trig = "sel", desc = "select ... from ... where" }, fmt([[
select {}
from {}
where {};]], { i(1, "*"), i(2, "t"), i(3, "true") })),

  -- Run something and look at it without keeping it.
  s({ trig = "txtest", desc = "begin ... rollback (try a change safely)" }, fmt([[
begin{};
{}
rollback;]], { f(function() return tsql() and " transaction" or "" end), i(1) })),

  s({ trig = "upsert", desc = "insert ... on conflict do update" }, fmt([[
insert into {} ({})
values ({})
on conflict ({}) do update
set {} = excluded.{};]], { i(1, "t"), i(2, "id, name"), i(3), i(4, "id"), i(5, "name"), rep(5) }), only_pg),

  s({ trig = "upsert", desc = "merge ... when matched / not matched" }, fmt([[
merge into {} as target
using ({}) as source
on target.{} = source.{}
when matched then
    update set {} = source.{}
when not matched by target then
    insert ({}) values ({});]], { i(1, "dbo.t"), i(2, "select ..."), i(3, "id"), rep(3), i(4, "name"), rep(4), i(5, "id, name"), i(6, "source.id, source.name") }), only_tsql),

  s({ trig = "proc", desc = "create or alter procedure" }, fmt([[
create or alter procedure {}
    {}
as
begin
    set nocount on;
    {}
end;
go]], { i(1, "dbo.p"), i(2, "@id int"), i(3) }), only_tsql),

  s({ trig = "fn", desc = "create or replace function" }, fmt([[
create or replace function {}({})
returns {}
language {}
as $$
{}
$$;]], { i(1, "f"), i(2, "p_id int"), i(3, "int"), i(4, "sql"), i(5, "select 1") }), only_pg),

  s({ trig = "dropif", desc = "drop table if exists" }, fmt("drop {} if exists {};", { i(1, "table"), i(2, "t") })),
}
