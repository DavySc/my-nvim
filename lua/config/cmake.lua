-- Minimal CMake driver: no plugin, just
-- the commands an edit-build-run-debug loop actually needs.
--
-- Target discovery goes through the CMake File API (build/.cmake/api/v1)
-- instead of parsing `cmake --build --target help`, because the File API also
-- hands back each executable's real artifact path -- which is exactly what
-- `:CMake run` and `:CMake debug` need to exec.

local M = {}

local is_win = vim.fn.has("win32") == 1

local BUILD_TYPES = { "Debug", "RelWithDebInfo", "Release", "MinSizeRel" }

-- gcc/clang patterns already live in the default errorformat; CMake's own
-- diagnostics do not.
local EFM = table.concat({
  "CMake Error at %f:%l (%.%#):",
  "CMake Warning at %f:%l (%.%#):",
  vim.o.errorformat,
}, ",")

---@class CMakeTarget
---@field name string
---@field path string absolute path to the built executable

---@class CMakeProject
---@field root string directory holding the top-level CMakeLists.txt
---@field build string build directory
---@field build_type string
---@field target? CMakeTarget

---@type table<string, CMakeProject> keyed by project root
local projects = {}

--- Topmost directory of the unbroken chain of CMakeLists.txt above `dir`, so a
--- buffer inside src/ resolves to the project root rather than its subdirectory.
---@param dir string
---@return string?
local function find_root(dir)
  local root
  local found = vim.fs.find("CMakeLists.txt", { path = dir, upward = true, type = "file", limit = math.huge })
  for _, path in ipairs(found) do
    local d = vim.fs.dirname(path)
    if root and d ~= vim.fs.dirname(root) then
      break
    end
    root = d
  end
  return root
end

---@param path string
---@return table?
local function read_json(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local text = fd:read("*a")
  fd:close()
  local ok, decoded = pcall(vim.json.decode, text)
  return ok and decoded or nil
end

--- The project the given buffer belongs to, created on first use.
---@param bufnr? integer
---@return CMakeProject?
function M.project(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  local dir = name ~= "" and vim.fs.dirname(name) or assert(vim.uv.cwd())
  local root = find_root(dir)
  if not root then
    return nil
  end
  if not projects[root] then
    projects[root] = {
      root = root,
      build = root .. "/" .. (vim.g.cmake_build_dir or "build"),
      build_type = vim.g.cmake_build_type or "Debug",
    }
  end
  return projects[root]
end

--- Run a command, funnelling compiler output into the quickfix list.
---@param cmd string[]
---@param p CMakeProject
---@param label string
---@param on_success? fun()
local function job(cmd, p, label, on_success)
  vim.notify("cmake: " .. label .. "...")
  vim.system(cmd, { cwd = p.root, text = true }, vim.schedule_wrap(function(res)
    local out = vim.split((res.stdout or "") .. (res.stderr or ""), "\n", { trimempty = true })
    -- getqflist keeps unmatched lines as text-only entries; drop them so the
    -- list stays navigable.
    local items = vim.tbl_filter(
      function(item) return item.valid == 1 end,
      vim.fn.getqflist({ lines = out, efm = EFM }).items
    )
    vim.fn.setqflist({}, " ", { title = table.concat(cmd, " "), items = items })

    if #items > 0 then
      vim.cmd("botright copen")
    else
      vim.cmd("cclose")
    end
    if res.code ~= 0 then
      vim.notify(("cmake: %s failed (exit %d)"):format(label, res.code), vim.log.levels.ERROR)
      return
    end
    vim.notify("cmake: " .. label .. " ok")
    if on_success then
      on_success()
    end
  end))
end

--- clangd finds compile_commands.json next to the sources or in a `build/`
--- subdirectory; symlinking it to the root makes any build-dir name work.
---@param p CMakeProject
function M.link_compile_commands(p)
  local src = p.build .. "/compile_commands.json"
  local dst = p.root .. "/compile_commands.json"
  if not vim.uv.fs_stat(src) then
    return
  end
  local link = vim.uv.fs_lstat(dst)
  if link and link.type ~= "link" then
    -- Windows fallback copies (below); refresh our own copy, but never
    -- clobber a real file the project checked in.
    if not (is_win and M.is_our_copy(dst, p)) then
      return
    end
  end
  if link then
    vim.uv.fs_unlink(dst)
  end
  -- Symlinks on Windows need admin rights or Developer Mode; copy instead.
  if not vim.uv.fs_symlink(src, dst) and is_win then
    vim.uv.fs_copyfile(src, dst)
  end
end

--- Whether `path` is a compile database copied from this project's build dir
--- (its entries' "directory" is the build dir) rather than a checked-in one.
---@param path string
---@param p CMakeProject
---@return boolean
function M.is_our_copy(path, p)
  local db = read_json(path)
  local first = type(db) == "table" and db[1]
  return type(first) == "table"
    and type(first.directory) == "string"
    and vim.fs.normalize(first.directory):lower():find(vim.fs.normalize(p.build):lower(), 1, true) == 1
end

---@param p CMakeProject
---@param on_success? fun()
function M.configure(p, on_success)
  -- Ask for a codemodel reply up front; CMake writes it during the configure run.
  local query = p.build .. "/.cmake/api/v1/query"
  vim.fn.mkdir(query, "p")
  local fd = io.open(query .. "/codemodel-v2", "w")
  if fd then
    fd:close()
  end

  local cmd = {
    "cmake",
    "-S", p.root,
    "-B", p.build,
    "-DCMAKE_BUILD_TYPE=" .. p.build_type,
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
  }
  -- Only pick a generator for a fresh tree: re-specifying one on an existing
  -- cache is a hard error.
  if not vim.uv.fs_stat(p.build .. "/CMakeCache.txt") then
    if vim.fn.executable("ninja") == 1 then
      vim.list_extend(cmd, { "-G", "Ninja" })
    elseif is_win then
      -- Visual Studio generators don't emit compile_commands.json, so clangd
      -- would have nothing to read.
      vim.notify("cmake: ninja not found; clangd needs it for compile_commands.json (winget install Ninja-build.Ninja)", vim.log.levels.WARN)
    end
  end

  job(cmd, p, "configure (" .. p.build_type .. ")", function()
    M.link_compile_commands(p)
    p.target = nil -- the target list may have changed
    if on_success then
      on_success()
    end
  end)
end

---@param p CMakeProject
---@param on_success? fun()
function M.build(p, on_success)
  if not vim.uv.fs_stat(p.build .. "/CMakeCache.txt") then
    return M.configure(p, function() M.build(p, on_success) end)
  end
  -- --config is ignored by single-config generators, needed by multi-config ones.
  job({ "cmake", "--build", p.build, "--config", p.build_type }, p, "build", on_success)
end

--- Executable targets known to the last configure.
---@param p CMakeProject
---@return CMakeTarget[]
function M.targets(p)
  local reply = p.build .. "/.cmake/api/v1/reply"
  local indexes = vim.fn.glob(reply .. "/index-*.json", true, true)
  if #indexes == 0 then
    return {}
  end
  table.sort(indexes) -- index files are timestamped; the last one is current

  local codemodel
  for _, obj in ipairs((read_json(indexes[#indexes]) or {}).objects or {}) do
    if obj.kind == "codemodel" then
      codemodel = read_json(reply .. "/" .. obj.jsonFile)
    end
  end

  local seen, out = {}, {}
  local configs = (codemodel or {}).configurations or {}
  if #configs > 1 then -- multi-config generator: only the selected build type
    configs = vim.tbl_filter(function(cfg) return cfg.name == p.build_type end, configs)
  end
  for _, cfg in ipairs(configs) do
    for _, ref in ipairs(cfg.targets or {}) do
      local t = read_json(reply .. "/" .. ref.jsonFile)
      local artifact = t and t.type == "EXECUTABLE" and t.artifacts and t.artifacts[1]
      if artifact and not seen[t.name] then
        seen[t.name] = true
        out[#out + 1] = { name = t.name, path = vim.fs.normalize(p.build .. "/" .. artifact.path) }
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

--- Resolve the launch target, prompting only when it is ambiguous.
---@param p CMakeProject
---@param cb fun(target: CMakeTarget)
function M.with_target(p, cb)
  if p.target then
    return cb(p.target)
  end
  local targets = M.targets(p)
  if #targets == 0 then
    return vim.notify("cmake: no executable targets (run :CMake configure)", vim.log.levels.WARN)
  end
  if #targets == 1 then
    p.target = targets[1]
    return cb(p.target)
  end
  vim.ui.select(targets, {
    prompt = "CMake target",
    format_item = function(t) return t.name end,
  }, function(choice)
    if not choice then
      return
    end
    p.target = choice
    cb(choice)
  end)
end

---@param p CMakeProject
function M.select_target(p)
  p.target = nil
  M.with_target(p, function(t) vim.notify("cmake: target " .. t.name) end)
end

---@param p CMakeProject
function M.select_build_type(p)
  vim.ui.select(BUILD_TYPES, { prompt = "CMake build type" }, function(choice)
    if not choice then
      return
    end
    p.build_type = choice
    M.configure(p)
  end)
end

---@param p CMakeProject
---@param args string[] forwarded to the executable
function M.run(p, args)
  M.build(p, function()
    M.with_target(p, function(t)
      if not vim.uv.fs_stat(t.path) then
        return vim.notify("cmake: " .. t.path .. " does not exist", vim.log.levels.ERROR)
      end
      local cmd = { t.path }
      vim.list_extend(cmd, args or {})
      -- Snacks owns terminal windows in this config.
      Snacks.terminal.open(cmd, { cwd = p.root, win = { position = "bottom", height = 0.35 } })
    end)
  end)
end

---@param p CMakeProject
---@param args string[] forwarded to the executable
function M.debug(p, args)
  local dap = require("dap")
  if not dap.adapters.codelldb then
    return vim.notify("cmake: codelldb not installed (:MasonInstall codelldb)", vim.log.levels.ERROR)
  end
  if p.build_type == "Release" or p.build_type == "MinSizeRel" then
    vim.notify("cmake: build type is " .. p.build_type .. "; debug info will be sparse", vim.log.levels.WARN)
  end
  M.build(p, function()
    M.with_target(p, function(t)
      dap.run({
        name = "CMake: " .. t.name,
        type = "codelldb",
        request = "launch",
        program = t.path,
        cwd = p.root,
        args = args or {},
        stopOnEntry = false,
        console = "integratedTerminal",
      })
    end)
  end)
end

---@param p CMakeProject
function M.clean(p)
  job({ "cmake", "--build", p.build, "--config", p.build_type, "--target", "clean" }, p, "clean")
end

---@param p CMakeProject
function M.info(p)
  vim.notify(table.concat({
    "root:   " .. p.root,
    "build:  " .. p.build,
    "type:   " .. p.build_type,
    "target: " .. (p.target and p.target.name or "(unset)"),
  }, "\n"))
end

local subcommands = {
  build = function(p) M.build(p) end,
  clean = function(p) M.clean(p) end,
  configure = function(p) M.configure(p) end,
  debug = function(p, args) M.debug(p, args) end,
  info = function(p) M.info(p) end,
  run = function(p, args) M.run(p, args) end,
  target = function(p) M.select_target(p) end,
  type = function(p) M.select_build_type(p) end,
}

function M.setup()
  vim.api.nvim_create_user_command("CMake", function(opts)
    local sub = table.remove(opts.fargs, 1) or "build"
    local handler = subcommands[sub]
    if not handler then
      return vim.notify("cmake: unknown subcommand '" .. sub .. "'", vim.log.levels.ERROR)
    end
    local p = M.project()
    if not p then
      return vim.notify("cmake: no CMakeLists.txt above this buffer", vim.log.levels.ERROR)
    end
    handler(p, opts.fargs)
  end, {
    nargs = "*",
    desc = "CMake configure/build/run/debug",
    complete = function(lead, line)
      if line:match("^%s*CMake%s+%S+%s") then
        return {} -- past the subcommand: the rest are the program's own args
      end
      local names = vim.tbl_keys(subcommands)
      table.sort(names)
      return vim.tbl_filter(function(name) return name:find(lead, 1, true) == 1 end, names)
    end,
  })
end

return M
