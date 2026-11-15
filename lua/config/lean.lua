-- Lean 4 helpers on top of lean.nvim (lua/lang/lean.lua): Lake builds into
-- the quickfix list, running a file, new projects (with or without Mathlib),
-- and Snacks pickers for unicode input, Loogle and the library sources.
-- lean.nvim itself does the language server, infoview, abbreviations, hover
-- and goals; nothing here repeats it.

local M = {}

--- The Lake project root of a buffer (the nearest lakefile, else
--- lean-toolchain), or nil for a standalone file.
---@param bufnr? integer
---@return string?
function M.root(bufnr)
  return vim.fs.root(bufnr or 0, { "lakefile.toml", "lakefile.lean" })
    or vim.fs.root(bufnr or 0, { "lean-toolchain" })
end

-- A message from `lake build` starts with "error: Some/File.lean:3:4: ..."
-- (also warning / info) and runs on until the next line Lake itself writes:
-- progress (✔ ⚠ ✖ [n/m]), trace, another message, or the summary.
local HEADER = "^(%a+): (.-%.lean):(%d+):(%d+): ?(.*)$"
local KINDS = { error = "E", warning = "W", info = "I" }

---@param line string
local function lake_line(line)
  return line:find("^✔ %[") or line:find("^⚠ %[") or line:find("^✖ %[") or line:match("^trace: ") or line:match("^Some required targets")
    or line:match("^%- ") or line:match("^Build completed") or line:match("^%a+: ")
end

--- Quickfix items from Lake's output. Paths are relative to `root`, where
--- Lake ran. Multi-line messages (goals, type mismatches) stay whole.
---@param lines string[]
---@param root string
---@return vim.quickfix.entry[]
function M.parse(lines, root)
  local items, cur = {}, nil
  for _, line in ipairs(lines) do
    local kind, file, lnum, col, msg = line:match(HEADER)
    if kind and KINDS[kind] then
      local path = vim.fs.normalize(file)
      if not (path:match("^/") or path:match("^%a:/")) then path = vim.fs.joinpath(root, path) end
      cur = { filename = path, lnum = tonumber(lnum), col = tonumber(col) + 1, type = KINDS[kind], text = msg }
      items[#items + 1] = cur
    elseif cur and not lake_line(line) then
      cur.text = cur.text .. "\n" .. line
    else
      cur = nil
    end
  end
  return items
end

--- `lake build [target]` in the buffer's project, without blocking. Errors
--- and warnings go to the quickfix list (opened when there are errors).
---@param args? string[]
function M.build(args)
  local root = M.root()
  if not root then return vim.notify("lean: no lakefile above this file", vim.log.levels.ERROR) end
  vim.cmd("silent! wall")
  local cmd = vim.list_extend({ "lake", "build" }, args or {})
  vim.notify("lake: building " .. vim.fs.basename(root) .. " …")
  vim.system(cmd, { cwd = root, text = true }, vim.schedule_wrap(function(res)
    local out = vim.split((res.stdout or "") .. "\n" .. (res.stderr or ""), "\n", { trimempty = true })
    local items = M.parse(out, root)
    vim.fn.setqflist({}, " ", { title = table.concat(cmd, " "), items = items })
    if res.code == 0 then
      local warnings = #items > 0 and (" (" .. #items .. " messages in the quickfix list)") or ""
      vim.notify("lake: build succeeded" .. warnings)
    else
      vim.notify("lake: build failed", vim.log.levels.ERROR)
      if #items > 0 then
        vim.cmd("botright copen")
      else
        -- Not a Lean message (a lakefile error, a missing toolchain): show it all.
        vim.fn.setqflist({}, "r", { lines = out, efm = "%m" })
        vim.cmd("botright copen")
      end
    end
  end))
end

--- Run a command in a terminal split, then the next, and so on while each
--- succeeds. No shell, so it behaves the same on Windows.
---@param steps { cmd: string[], cwd: string }[]
---@param done? fun()
function M.run_steps(steps, done)
  local i, win = 0, nil
  local function next_step()
    i = i + 1
    local step = steps[i]
    if not step then
      if done then done() end
      return
    end
    if win and vim.api.nvim_win_is_valid(win) then
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
    else
      vim.cmd("botright 12split")
      win = vim.api.nvim_get_current_win()
    end
    vim.cmd.enew()
    vim.bo.bufhidden = "wipe"
    vim.fn.jobstart(step.cmd, {
      term = true,
      cwd = step.cwd,
      on_exit = vim.schedule_wrap(function(_, code)
        if code == 0 then
          next_step()
        else
          vim.notify(table.concat(step.cmd, " ") .. ": exit " .. code, vim.log.levels.ERROR)
        end
      end),
    })
  end
  next_step()
end

--- `lake <args>` in a terminal at the project root (`:Lake update`,
--- `:Lake exe cache get`, `:Lake test`, ...).
---@param args string[]
function M.lake(args)
  local root = M.root() or vim.uv.cwd()
  M.run_steps({ { cmd = vim.list_extend({ "lake" }, args), cwd = root } })
end

--- Run the current file's `main` (`lake env lean --run`), in a terminal.
---@param args? string[] passed to main
function M.run_file(args)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then return vim.notify("lean: buffer is not backed by a file", vim.log.levels.ERROR) end
  if vim.bo.modified then vim.cmd.write() end
  local root = M.root()
  local cmd = root and { "lake", "env", "lean", "--run", file } or { "lean", "--run", file }
  M.run_steps({ { cmd = vim.list_extend(cmd, args or {}), cwd = root or vim.fs.dirname(file) } })
end

--- A new Lake project in the current directory. With `math`, it depends on
--- Mathlib, takes Mathlib's toolchain (through elan) and downloads the
--- prebuilt Mathlib (`lake exe cache get`) so nothing compiles for an hour.
---@param name string
---@param math boolean
function M.new_project(name, math)
  local cwd = vim.uv.cwd()
  local dir = vim.fs.joinpath(cwd, name)
  if vim.uv.fs_stat(dir) then return vim.notify("lean: " .. dir .. " already exists", vim.log.levels.ERROR) end
  local steps
  if math then
    steps = {
      { cmd = { "lake", "+leanprover-community/mathlib4:lean-toolchain", "new", name, "math" }, cwd = cwd },
      { cmd = { "lake", "exe", "cache", "get" }, cwd = dir },
    }
  else
    steps = { { cmd = { "lake", "new", name }, cwd = cwd } }
  end
  M.run_steps(steps, function()
    -- `lake new foo` writes Foo/Basic.lean (the library's first module).
    local lib = name:sub(1, 1):upper() .. name:sub(2)
    local basic = vim.fs.joinpath(dir, lib, "Basic.lean")
    vim.cmd.edit(vim.fn.fnameescape(vim.uv.fs_stat(basic) and basic or vim.fs.joinpath(dir, lib .. ".lean")))
    vim.cmd.lcd(vim.fn.fnameescape(dir))
  end)
end

-- ── Pickers ──────────────────────────────────────────────────────────────

--- Every unicode abbreviation (`\alpha` → α), searchable by name or symbol.
--- <CR> puts the symbol after the cursor.
function M.pick_unicode()
  local lead = require("lean.config")().abbreviations.leader
  local all = vim.tbl_extend("force", require("lean.abbreviations").load(), require("lean.config")().abbreviations.extra or {})
  local items = {}
  for abbr, sym in pairs(all) do
    local shown = sym:gsub("%$CURSOR", "")
    items[#items + 1] = { text = shown .. " " .. lead .. abbr, abbr = lead .. abbr, symbol = shown }
  end
  -- Shortest abbreviation first among equals: \a before \alpha.
  table.sort(items, function(a, b) return #a.abbr < #b.abbr or (#a.abbr == #b.abbr and a.abbr < b.abbr) end)
  local win = vim.api.nvim_get_current_win()
  Snacks.picker.pick({
    title = "Lean unicode",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      return { { item.symbol, "Special" }, { "  " }, { item.abbr, "Comment" } }
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
      vim.api.nvim_put({ item.symbol }, "c", true, true)
    end,
  })
end

local LOOGLE = "https://loogle.lean-lang.org/json?q="

--- Search Loogle (Mathlib by name, type shape or subexpression:
--- `Real.sqrt`, `(?a + ?b) * ?c`, `List.map, List.length`) and pick a hit.
--- <CR> puts the name after the cursor; the preview shows its type and module.
---@param query? string asked for when nil
function M.loogle(query)
  if not query or query == "" then
    return vim.ui.input({ prompt = "Loogle: " }, function(q)
      if q and q ~= "" then M.loogle(q) end
    end)
  end
  local win = vim.api.nvim_get_current_win()
  vim.notify("loogle: searching " .. query)
  vim.system({ "curl", "-sS", "-H", "Accept: application/json", "-H", "User-Agent: lean+nvim", LOOGLE .. vim.uri_encode(query) },
    { text = true }, vim.schedule_wrap(function(res)
      local ok, body = pcall(vim.json.decode, res.stdout or "")
      if res.code ~= 0 or not ok or type(body) ~= "table" then
        return vim.notify("loogle: " .. ((res.stderr ~= "" and res.stderr) or "no answer"), vim.log.levels.ERROR)
      end
      if body.error then
        local hint = body.suggestions and ("\nDid you mean: " .. table.concat(body.suggestions, ", ")) or ""
        return vim.notify("loogle: " .. body.error .. hint, vim.log.levels.WARN)
      end
      local hits = body.hits or {}
      if #hits == 0 then return vim.notify("loogle: nothing for " .. query, vim.log.levels.WARN) end
      local items = {}
      for _, hit in ipairs(hits) do
        local text = ("import %s\n\n%s : %s\n"):format(hit.module, hit.name, hit.type)
        if hit.doc and hit.doc ~= vim.NIL and hit.doc ~= "" then text = text .. "\n/-- " .. hit.doc .. " -/\n" end
        items[#items + 1] = { text = hit.name, name = hit.name, module = hit.module, preview = { text = text, ft = "lean" } }
      end
      Snacks.picker.pick({
        title = "Loogle: " .. query,
        items = items,
        preview = "preview",
        format = function(item) return { { item.name, "Function" }, { "  " }, { item.module, "Comment" } } end,
        confirm = function(picker, item)
          picker:close()
          if not item then return end
          if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
          vim.api.nvim_put({ item.name }, "c", true, true)
        end,
      })
    end))
end

--- Directories of the Lean core library and the project's dependencies
--- (Mathlib, Batteries, ...): where `grep` for a lemma name should look.
---@return string[]
function M.library_dirs()
  local ok, paths = pcall(require("lean").current_search_paths)
  if not ok then
    vim.notify("lean: " .. tostring(paths), vim.log.levels.ERROR)
    return {}
  end
  return vim.tbl_filter(function(p) return vim.uv.fs_stat(p) ~= nil end, paths)
end

--- Grep the library sources (core Lean, Mathlib and the other dependencies).
function M.grep_library()
  local dirs = M.library_dirs()
  if #dirs > 0 then Snacks.picker.grep({ title = "Grep Lean library", dirs = dirs, glob = "*.lean" }) end
end

--- Find a file in the library sources.
function M.files_library()
  local dirs = M.library_dirs()
  if #dirs > 0 then Snacks.picker.files({ title = "Lean library files", dirs = dirs }) end
end

return M
