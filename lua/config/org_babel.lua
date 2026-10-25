-- Run org source blocks and write their output under #+RESULTS:, the part of
-- org-babel that nvim-orgmode doesn't do (it does tangle and noweb). No
-- plugin: each block is written to a temp file and run as a job.
--
--   #+begin_src python :var n=3 :dir ~/scratch :results output
--   print(n * 2)
--   #+end_src
--
-- Header args: :var name=value (repeatable; plain values only), :dir, and
-- :results silent (notify instead of writing) or replace (the default). Each
-- run starts fresh: there are no sessions. SQL blocks go to dbbliss
-- (:Dbbliss exec over the block body), so their rows show in dbbliss's results
-- window, with its prod and transaction guards, not under #+RESULTS:.

local M = {}

local is_win = vim.fn.has("win32") == 1

---@class OrgBlock
---@field lang string
---@field args table<string, string|string[]>
---@field begin_row integer 0-based row of #+begin_src
---@field end_row integer 0-based row of #+end_src
---@field body string[]

--- Parse `:key value :var a=1 :var b=2`. A value runs up to the next
--- ` :key`, so it may hold spaces or colons (`:dir C:\work`); quotes around
--- it are dropped.
---@param s string
---@return table<string, string|string[]>
function M.parse_args(s)
  local args, key, words = {}, nil, {}
  local function flush()
    if not key then return end
    local value = table.concat(words, " "):gsub('^"(.*)"$', "%1")
    if key == "var" then
      args.var = args.var or {}
      table.insert(args.var, value)
    else
      args[key] = value
    end
  end
  for word in s:gmatch("%S+") do
    local k = word:match("^:([%w_-]+)$")
    if k then
      flush()
      key, words = k, {}
    else
      words[#words + 1] = word
    end
  end
  flush()
  return args
end

--- The source block around `row` (0-based) in `bufnr`, if any.
---@param bufnr integer
---@param row integer
---@return OrgBlock?
function M.block_at(bufnr, row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local begin_row
  for r = row + 1, 1, -1 do
    local line = lines[r]:lower()
    if line:match("^%s*#%+end_src") and r ~= row + 1 then return nil end
    if line:match("^%s*#%+begin_src") then
      begin_row = r - 1
      break
    end
  end
  if not begin_row then return nil end
  for r = begin_row + 2, #lines do
    if lines[r]:lower():match("^%s*#%+end_src") then
      local lang, rest = lines[begin_row + 1]:match("^%s*#%+[bB][eE][gG][iI][nN]_[sS][rR][cC]%s+(%S+)(.*)$")
      if not lang then return nil end
      return {
        lang = lang:lower(),
        args = M.parse_args(rest or ""),
        begin_row = begin_row,
        end_row = r - 1,
        body = vim.list_slice(lines, begin_row + 2, r - 1),
      }
    end
  end
end

--- Every source block in `bufnr`, top to bottom.
---@return OrgBlock[]
function M.blocks(bufnr)
  local found = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for r, line in ipairs(lines) do
    if line:lower():match("^%s*#%+begin_src") then
      local b = M.block_at(bufnr, r - 1)
      if b then found[#found + 1] = b end
    end
  end
  return found
end

local function var_pairs(block)
  local pairs_ = {}
  for _, v in ipairs(block.args.var or {}) do
    local name, value = v:match("^([%w_]+)%s*=%s*(.*)$")
    if name then pairs_[#pairs_ + 1] = { name, value } end
  end
  return pairs_
end

local function quoted(value)
  if tonumber(value) then return value end
  return ("%q"):format(value)
end

--- How to run each language: the file extension, a preamble for :var, and
--- the command(s), where %s is the source file and %o an output binary.
local RUNNERS = {
  sh = { ext = "sh", var = function(n, v) return n .. "=" .. ("%q"):format(v) end, cmd = { { "sh", "%s" } } },
  bash = { ext = "sh", var = function(n, v) return n .. "=" .. ("%q"):format(v) end, cmd = { { "bash", "%s" } } },
  python = { ext = "py", var = function(n, v) return n .. " = " .. quoted(v) end, cmd = { { is_win and "python" or "python3", "%s" } } },
  racket = {
    ext = "rkt",
    head = "#lang racket",
    var = function(n, v) return ("(define %s %s)"):format(n, quoted(v)) end,
    cmd = { { "racket", "%s" } },
  },
  pwsh = { ext = "ps1", var = function(n, v) return ("$%s = %s"):format(n, quoted(v)) end, cmd = { { "pwsh", "-NoProfile", "-File", "%s" } } },
  c = {
    ext = "c",
    var = function(n, v) return tonumber(v) and ("#define %s %s"):format(n, v) or ("#define %s %q"):format(n, v) end,
    -- org-babel style: a block without main() is the body of one.
    wrap = function(body)
      if table.concat(body, "\n"):find("main%s*%(") then return body end
      local out = { "#include <stdio.h>", "#include <stdlib.h>", "int main(void) {" }
      vim.list_extend(out, body)
      vim.list_extend(out, { "return 0;", "}" })
      return out
    end,
    cmd = { { "cc", "-o", "%o", "%s" }, { "%o" } },
  },
  rust = {
    ext = "rs",
    var = function(n, v)
      return tonumber(v) and ("const %s: i64 = %s;"):format(n:upper(), v) or ("const %s: &str = %q;"):format(n:upper(), v)
    end,
    wrap = function(body)
      if table.concat(body, "\n"):find("fn%s+main") then return body end
      local out = { "fn main() {" }
      vim.list_extend(out, body)
      out[#out + 1] = "}"
      return out
    end,
    cmd = { { "rustc", "--edition", "2021", "-o", "%o", "%s" }, { "%o" } },
  },
}
RUNNERS.shell = RUNNERS.sh
RUNNERS.python3 = RUNNERS.python
RUNNERS.powershell = RUNNERS.pwsh

--- Replace the block's #+RESULTS: (if any) with `output`.
---@param bufnr integer
---@param end_row integer 0-based row of #+end_src
---@param output string[]
function M.write_results(bufnr, end_row, output)
  local lines = vim.api.nvim_buf_get_lines(bufnr, end_row + 1, -1, false)
  local first, last = end_row + 1, end_row + 1 -- the range to replace
  local i = 1
  if lines[i] == "" and lines[i + 1] and lines[i + 1]:match("^%s*#%+[Rr][Ee][Ss][Uu][Ll][Tt][Ss]:") then i = i + 1 end
  if lines[i] and lines[i]:match("^%s*#%+[Rr][Ee][Ss][Uu][Ll][Tt][Ss]:") then
    last = end_row + 1 + i
    while lines[i + 1] and lines[i + 1]:match("^%s*:") do
      i = i + 1
      last = last + 1
    end
  end
  local new = { "", "#+RESULTS:" }
  for _, l in ipairs(output) do new[#new + 1] = l == "" and ":" or (": " .. l) end
  vim.api.nvim_buf_set_lines(bufnr, first, last, false, new)
end

local function split_output(s)
  local out = vim.split((s or ""):gsub("\r\n", "\n"):gsub("\n$", ""), "\n", { plain = true })
  if #out == 1 and out[1] == "" then return {} end
  return out
end

local function run_lua(block)
  local out = {}
  local env = setmetatable({
    print = function(...)
      local parts = {}
      for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
      vim.list_extend(out, vim.split(table.concat(parts, "\t"), "\n", { plain = true }))
    end,
  }, { __index = _G })
  local src = {}
  for _, p in ipairs(var_pairs(block)) do src[#src + 1] = ("local %s = %s"):format(p[1], quoted(p[2])) end
  vim.list_extend(src, block.body)
  local chunk, err = load(table.concat(src, "\n"), "org block", "t", env)
  if not chunk then return { "error: " .. err } end
  local ok, res = pcall(chunk)
  if not ok then
    out[#out + 1] = "error: " .. tostring(res)
  elseif res ~= nil and #out == 0 then
    vim.list_extend(out, vim.split(vim.inspect(res), "\n", { plain = true }))
  end
  return out
end

--- Run the block and call `done(output_lines, ok)` on the main loop.
---@param block OrgBlock
---@param done fun(output: string[], ok: boolean)
function M.run(block, done)
  if block.lang == "lua" then return done(run_lua(block), true) end
  local runner = RUNNERS[block.lang]
  if not runner then
    return done({ "org_babel: no runner for " .. block.lang }, false)
  end
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local src = dir .. "/block." .. runner.ext
  local bin = dir .. "/block" .. (is_win and ".exe" or "")
  local text = {}
  if runner.head then text[#text + 1] = runner.head end
  for _, p in ipairs(var_pairs(block)) do text[#text + 1] = runner.var(p[1], p[2]) end
  vim.list_extend(text, runner.wrap and runner.wrap(block.body) or block.body)
  vim.fn.writefile(text, src)
  local cwd = block.args.dir and vim.fn.expand(block.args.dir) or vim.fn.getcwd()

  local steps = vim.deepcopy(runner.cmd)
  local output = {}
  local function step(i)
    if i > #steps then
      vim.fn.delete(dir, "rf")
      return done(output, true)
    end
    local cmd = vim.tbl_map(function(a) return (a:gsub("%%s", src):gsub("%%o", bin)) end, steps[i])
    local ok, err = pcall(vim.system, cmd, { cwd = cwd, text = true, timeout = 60000 }, vim.schedule_wrap(function(res)
      vim.list_extend(output, split_output(res.stdout))
      vim.list_extend(output, split_output(res.stderr))
      if res.code ~= 0 then
        output[#output + 1] = ("[exit %d]"):format(res.code)
        vim.fn.delete(dir, "rf")
        return done(output, false)
      end
      step(i + 1)
    end))
    if not ok then
      vim.fn.delete(dir, "rf")
      done({ "org_babel: " .. tostring(err) }, false)
    end
  end
  step(1)
end

--- Run `block` of `bufnr` and write (or show) its results.
---@param bufnr integer
---@param block OrgBlock
---@param after? fun()
local function execute(bufnr, block, after)
  if block.lang == "sql" then
    if #block.body > 0 then
      vim.cmd(("%d,%dDbbliss exec"):format(block.begin_row + 2, block.end_row))
    end
    return after and after()
  end
  -- Track #+end_src across edits made while the job runs.
  local ns = vim.api.nvim_create_namespace("org_babel")
  local mark = vim.api.nvim_buf_set_extmark(bufnr, ns, block.end_row, 0, {})
  M.run(block, function(output, ok)
    local row = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, mark, {})[1]
    vim.api.nvim_buf_del_extmark(bufnr, ns, mark)
    if block.args.results == "silent" or not row then
      vim.notify(table.concat(output, "\n"), ok and vim.log.levels.INFO or vim.log.levels.WARN)
    else
      M.write_results(bufnr, row, output)
    end
    if after then after() end
  end)
end

--- Run the block under the cursor.
function M.execute()
  local bufnr = vim.api.nvim_get_current_buf()
  local block = M.block_at(bufnr, vim.api.nvim_win_get_cursor(0)[1] - 1)
  if not block then return vim.notify("org_babel: no source block here", vim.log.levels.WARN) end
  execute(bufnr, block)
end

--- Run every block in the buffer, one after another.
function M.execute_all()
  local bufnr = vim.api.nvim_get_current_buf()
  local i = 0
  local function next_block()
    i = i + 1
    -- Re-read: earlier results have moved the rows.
    local block = M.blocks(bufnr)[i]
    if block then execute(bufnr, block, next_block) end
  end
  next_block()
end

return M
