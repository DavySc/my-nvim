-- Edit a fenced code block in its own buffer (Emacs's org-edit-special, C-c ').
-- <leader>ce inside a ``` fence in markdown opens the block's lines in a split
-- with the fence's filetype, so a SQL block gets the SQL setup: its dialect
-- (```tsql / ```pgsql), formatting, completion, iq/aq. :w writes the lines back
-- into the note (and leaves the note unsaved, for you to look at); :q drops
-- the edit. The block is tracked with extmarks, so editing the note meanwhile
-- is fine.

local M = {}

local ns = vim.api.nvim_create_namespace("config-edit-block")

-- Fence names that aren't filetypes, and the SQL dialect they mean.
local ALIAS = { tsql = "sql", pgsql = "sql", postgres = "sql", postgresql = "sql", mssql = "sql", sh = "bash", js = "javascript" }
local DIALECT = { tsql = "tsql", mssql = "tsql", pgsql = "postgres", postgres = "postgres", postgresql = "postgres" }

--- The fence around `row` (1-based) in `lines`: open and close rows and the
--- info word, or nil when `row` is not inside one.
---@return { open: integer, close: integer, lang: string }?
function M.find(lines, row)
  local open, lang
  for r = 1, #lines do
    local fence, info = lines[r]:match("^%s*(```+)%s*([%w_+-]*)")
    if fence then
      if not open then
        open, lang = r, info
      else
        if r >= row and open < row then return { open = open, close = r, lang = lang } end
        open, lang = nil, nil
      end
    end
  end
  return nil
end

function M.open()
  local src = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local block = M.find(vim.api.nvim_buf_get_lines(src, 0, -1, false), row)
  if not block then
    return vim.notify("Not inside a ``` code block", vim.log.levels.INFO)
  end
  local lang = block.lang:lower()
  local ft = ALIAS[lang] or (lang ~= "" and (vim.filetype.match({ filename = "x." .. lang }) or lang)) or "text"
  -- Marks on the fence lines follow edits to the note.
  local top = vim.api.nvim_buf_set_extmark(src, ns, block.open - 1, 0, {})
  local bottom = vim.api.nvim_buf_set_extmark(src, ns, block.close - 1, 0, {})
  local body = vim.api.nvim_buf_get_lines(src, block.open, block.close - 1, false)

  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, ("edit-block://%d/%d.%s"):format(src, top, lang ~= "" and lang or "txt"))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, body)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  if DIALECT[lang] then vim.b[buf].sql_dialect = DIALECT[lang] end
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.bo[buf].filetype = ft
  vim.bo[buf].modified = false

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      if not vim.api.nvim_buf_is_valid(src) then
        return vim.notify("The note is gone; nothing written", vim.log.levels.ERROR)
      end
      local a = vim.api.nvim_buf_get_extmark_by_id(src, ns, top, {})[1]
      local b = vim.api.nvim_buf_get_extmark_by_id(src, ns, bottom, {})[1]
      if not a or not b or b <= a then
        return vim.notify("The block was removed from the note; nothing written", vim.log.levels.ERROR)
      end
      vim.api.nvim_buf_set_lines(src, a + 1, b, false, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      vim.bo[buf].modified = false
      vim.notify("Written back to the note")
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_buf_is_valid(src) then
        pcall(vim.api.nvim_buf_del_extmark, src, ns, top)
        pcall(vim.api.nvim_buf_del_extmark, src, ns, bottom)
      end
    end,
  })
end

return M
