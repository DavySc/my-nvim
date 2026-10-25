-- The Racket process behind lua/config/drracket (racket/drracket.rkt): one
-- JSON object per line each way. Requests get a callback; events (program
-- output, values) go to whoever registered with M.on().

local M = {}

---@class DrRacketError
---@field message string
---@field kind string runtime | syntax | read | break | killed | busy | ...
---@field srclocs DrRacketSrcloc[] where the error itself points (syntax and read errors)
---@field stack DrRacketSrcloc[] innermost first (errortrace when it's on)

---@class DrRacketSrcloc
---@field file string
---@field line integer 1-based
---@field col integer 0-based, in characters
---@field pos? integer 1-based character offset in the file
---@field span integer characters

-- :ConfigReload loads this file again; the old copy's Racket process can't
-- be adopted (its callbacks belong to the old copy), so it's ended and the
-- next command starts a new one, as after :Racket restart.
local survivor = package.loaded["drracket.process"] or {}
package.loaded["drracket.process"] = survivor
if survivor.job then
  pcall(survivor.job.kill, survivor.job, "sigterm")
  survivor.job = nil
end

local job ---@type vim.SystemObj?
local next_id = 0
---@type table<integer, fun(err: DrRacketError?, result: any)>
local pending = {}
---@type table<string, fun(params: table)>
local handlers = {}
local partial = ""

M.racket = "racket"

--- racket/drracket.rkt from this config's runtimepath.
function M.script()
  return vim.api.nvim_get_runtime_file("racket/drracket.rkt", false)[1]
end

local function dispatch(line)
  local ok, msg = pcall(vim.json.decode, line, { luanil = { object = true, array = true } })
  if not ok or type(msg) ~= "table" then
    vim.notify("drracket: " .. line, vim.log.levels.WARN)
    return
  end
  if msg.id ~= nil and pending[msg.id] then
    local cb = pending[msg.id]
    pending[msg.id] = nil
    cb(msg.error, msg.result)
  elseif msg.method and handlers[msg.method] then
    handlers[msg.method](msg.params or {})
  end
end

local function on_stdout(_, data)
  if not data then return end
  vim.schedule(function()
    partial = partial .. data
    while true do
      local nl = partial:find("\n", 1, true)
      if not nl then break end
      local line = partial:sub(1, nl - 1)
      partial = partial:sub(nl + 1)
      if line ~= "" then dispatch(line) end
    end
  end)
end

local function on_exit(obj)
  vim.schedule(function()
    job = nil
    partial = ""
    local waiting = pending
    pending = {}
    for _, cb in pairs(waiting) do
      cb({ message = ("Racket exited (code %d)"):format(obj.code), kind = "exit", srclocs = {}, stack = {} })
    end
    if handlers.exit then handlers.exit({ code = obj.code }) end
  end)
end

function M.running() return job ~= nil end

function M.start()
  if job then return true end
  local script = M.script()
  if not script then
    vim.notify("drracket: racket/drracket.rkt not found on 'runtimepath'", vim.log.levels.ERROR)
    return false
  end
  if vim.fn.executable(M.racket) == 0 then
    vim.notify("drracket: `" .. M.racket .. "` is not on PATH", vim.log.levels.ERROR)
    return false
  end
  job = vim.system({ M.racket, script }, {
    stdin = true,
    stdout = on_stdout,
    stderr = function(_, data)
      if data and handlers.stderr then vim.schedule(function() handlers.stderr({ text = data }) end) end
    end,
  }, on_exit)
  survivor.job = job
  return true
end

function M.stop()
  if job then job:kill("sigterm") end
end

---@param method string
---@param params table
---@param cb fun(err: DrRacketError?, result: any)
function M.request(method, params, cb)
  if not M.start() then
    cb({ message = "the Racket back end could not start", kind = "exit", srclocs = {}, stack = {} })
    return
  end
  next_id = next_id + 1
  pending[next_id] = cb
  job:write(vim.json.encode({ id = next_id, method = method, params = params }) .. "\n")
end

---@param method string output | value | log | stderr | exit
---@param fn fun(params: table)
function M.on(method, fn) handlers[method] = fn end

return M
