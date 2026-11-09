-- Pretty LaTeX in org buffers, as kittymax had with org-pretty-entities:
-- \alpha shows as α, \rightarrow as →, x^{2} as x², a_{ij} as aᵢⱼ. The text
-- itself is unchanged; the line under the cursor shows it as typed
-- (concealcursor is empty), like org-appear.
--
-- Drawn by a decoration provider, so only the lines on screen are looked at
-- and nothing is stored in the buffer. Lines in src, example and export blocks,
-- fixed-width lines (": ...") and =verbatim= / ~code~ are left alone, as org
-- does. Sub- and superscripts need braces (org-use-sub-superscripts '{}), and
-- only show when every character has a Unicode form; others stay as typed.
--
-- Rendered math (images of $...$, \(...\), \[...\], equation blocks) is
-- snacks.image's job, through nvim-orgmode's queries/org/images.scm.

local M = {}

-- org-entities, the ones that are one character wide.
M.entities = {
  -- Greek
  alpha = "α", beta = "β", gamma = "γ", delta = "δ", epsilon = "ϵ", varepsilon = "ε", zeta = "ζ",
  eta = "η", theta = "θ", vartheta = "ϑ", iota = "ι", kappa = "κ", lambda = "λ", mu = "μ", nu = "ν",
  xi = "ξ", omicron = "ο", pi = "π", varpi = "ϖ", rho = "ρ", varrho = "ϱ", sigma = "σ", varsigma = "ς",
  tau = "τ", upsilon = "υ", phi = "ϕ", varphi = "φ", chi = "χ", psi = "ψ", omega = "ω",
  Gamma = "Γ", Delta = "Δ", Theta = "Θ", Lambda = "Λ", Xi = "Ξ", Pi = "Π", Sigma = "Σ",
  Upsilon = "Υ", Phi = "Φ", Psi = "Ψ", Omega = "Ω",
  -- arrows
  to = "→", rightarrow = "→", leftarrow = "←", gets = "←", leftrightarrow = "↔", uparrow = "↑",
  downarrow = "↓", Rightarrow = "⇒", Leftarrow = "⇐", Leftrightarrow = "⇔", implies = "⇒",
  iff = "⇔", mapsto = "↦", hookrightarrow = "↪", longrightarrow = "⟶", Longrightarrow = "⟹",
  -- relations
  leq = "≤", le = "≤", geq = "≥", ge = "≥", neq = "≠", ne = "≠", approx = "≈", equiv = "≡",
  sim = "∼", simeq = "≃", cong = "≅", propto = "∝", ll = "≪", gg = "≫", prec = "≺", succ = "≻",
  mid = "∣", nmid = "∤", parallel = "∥", perp = "⊥", models = "⊨", vdash = "⊢",
  -- sets and logic
  ["in"] = "∈", notin = "∉", ni = "∋", subset = "⊂", subseteq = "⊆", supset = "⊃", supseteq = "⊇",
  cup = "∪", cap = "∩", emptyset = "∅", varnothing = "∅", forall = "∀", exists = "∃", nexists = "∄",
  neg = "¬", lnot = "¬", land = "∧", wedge = "∧", lor = "∨", vee = "∨", top = "⊤", bot = "⊥",
  therefore = "∴", because = "∵",
  -- operators
  pm = "±", mp = "∓", times = "×", div = "÷", cdot = "⋅", circ = "∘", ast = "∗", star = "⋆",
  oplus = "⊕", otimes = "⊗", sum = "∑", prod = "∏", int = "∫", oint = "∮", partial = "∂",
  nabla = "∇", sqrt = "√", infty = "∞", angle = "∠",
  -- letters and misc
  hbar = "ℏ", ell = "ℓ", Re = "ℜ", Im = "ℑ", aleph = "ℵ", wp = "℘",
  langle = "⟨", rangle = "⟩", lceil = "⌈", rceil = "⌉", lfloor = "⌊", rfloor = "⌋",
  ldots = "…", dots = "…", cdots = "⋯", vdots = "⋮", ddots = "⋱",
  deg = "°", checkmark = "✓", dagger = "†", ddagger = "‡", S = "§", P = "¶",
  copy = "©", reg = "®", trade = "™", euro = "€", pound = "£", yen = "¥", cent = "¢",
  nbsp = " ", laquo = "«", raquo = "»", mdash = "—", ndash = "–",
}

local sup = {
  ["0"] = "⁰", ["1"] = "¹", ["2"] = "²", ["3"] = "³", ["4"] = "⁴", ["5"] = "⁵", ["6"] = "⁶",
  ["7"] = "⁷", ["8"] = "⁸", ["9"] = "⁹", ["+"] = "⁺", ["-"] = "⁻", ["="] = "⁼", ["("] = "⁽", [")"] = "⁾",
  a = "ᵃ", b = "ᵇ", c = "ᶜ", d = "ᵈ", e = "ᵉ", f = "ᶠ", g = "ᵍ", h = "ʰ", i = "ⁱ", j = "ʲ", k = "ᵏ",
  l = "ˡ", m = "ᵐ", n = "ⁿ", o = "ᵒ", p = "ᵖ", r = "ʳ", s = "ˢ", t = "ᵗ", u = "ᵘ", v = "ᵛ", w = "ʷ",
  x = "ˣ", y = "ʸ", z = "ᶻ", T = "ᵀ",
}
local sub = {
  ["0"] = "₀", ["1"] = "₁", ["2"] = "₂", ["3"] = "₃", ["4"] = "₄", ["5"] = "₅", ["6"] = "₆",
  ["7"] = "₇", ["8"] = "₈", ["9"] = "₉", ["+"] = "₊", ["-"] = "₋", ["="] = "₌", ["("] = "₍", [")"] = "₎",
  a = "ₐ", e = "ₑ", h = "ₕ", i = "ᵢ", j = "ⱼ", k = "ₖ", l = "ₗ", m = "ₘ", n = "ₙ", o = "ₒ", p = "ₚ",
  r = "ᵣ", s = "ₛ", t = "ₜ", u = "ᵤ", v = "ᵥ", x = "ₓ",
}

--- Byte ranges of =verbatim= and ~code~ in `line` (1-based, inclusive).
local function verbatim_spans(line)
  local spans = {}
  local init = 1
  while true do
    local s, e = line:find("[=~][^%s=~][^=~]-[=~]", init)
    if not s then break end
    local mark = line:sub(s, s)
    local before = s == 1 and " " or line:sub(s - 1, s - 1)
    local after = e == #line and " " or line:sub(e + 1, e + 1)
    if line:sub(e, e) == mark and before:match("[%s%(%[{'\"]") and after:match("[%s%p]") then
      spans[#spans + 1] = { s, e }
      init = e + 1
    else
      init = s + 1
    end
  end
  return spans
end

local function inside(spans, pos)
  for _, sp in ipairs(spans) do
    if pos >= sp[1] and pos <= sp[2] then return true end
  end
  return false
end

--- What to conceal in `line`: a list of { col, end_col, text }, 0-based byte
--- columns (end exclusive), each `text` one character (or "" to hide).
---@param line string
---@return { [1]: integer, [2]: integer, [3]: string }[]
function M.matches(line)
  local out = {}
  if not line:find("[\\^_]") then return out end
  local spans = verbatim_spans(line)
  -- \entity, optionally ended by {}
  local init = 1
  while true do
    local s, e, name = line:find("\\(%a+)", init)
    if not s then break end
    init = e + 1
    local char = M.entities[name]
    if char and not inside(spans, s) then
      if line:sub(e + 1, e + 2) == "{}" then e = e + 2 end
      out[#out + 1] = { s - 1, e, char }
    end
  end
  -- x^{...} and x_{...}
  init = 1
  while true do
    local s, e, mark, body = line:find("([%^_]){([^{}]+)}", init)
    if not s then break end
    init = e + 1
    local map = mark == "^" and sup or sub
    local ok = s > 1 and not line:sub(s - 1, s - 1):match("%s") and not inside(spans, s)
    for c in body:gmatch(".") do
      if not map[c] then ok = false end
    end
    if ok then
      -- "^{" and the first character become one mark, then one per character,
      -- and the closing brace is hidden.
      local first = s + 2 -- 1-based position of the first character
      out[#out + 1] = { s - 1, first, map[body:sub(1, 1)] }
      for i = 2, #body do
        out[#out + 1] = { first + i - 2, first + i - 1, map[body:sub(i, i)] }
      end
      out[#out + 1] = { e - 1, e, "" }
    end
  end
  return out
end

--- Rows (0-based) that are left alone: src/example/export blocks and
--- fixed-width lines.
---@param lines string[]
---@return table<integer, true>
function M.skipped_rows(lines)
  local skip, block = {}, nil
  for i, line in ipairs(lines) do
    local row = i - 1
    local lower = line:lower()
    if block then
      skip[row] = true
      if lower:match("^%s*#%+end_" .. block) then block = nil end
    else
      local kind = lower:match("^%s*#%+begin_(%a+)")
      if kind == "src" or kind == "example" or kind == "export" then
        block = kind
        skip[row] = true
      elseif line:match("^%s*:%s") or line:match("^%s*:$") then
        skip[row] = true
      end
    end
  end
  return skip
end

-- ── Drawing ─────────────────────────────────────────────────────────────

local ns = vim.api.nvim_create_namespace("config-org-pretty")
local attached = {} ---@type table<integer, true>
local cache = {} ---@type table<integer, { tick: integer, skip: table<integer, true> }>

local function skipped(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local c = cache[buf]
  if not c or c.tick ~= tick then
    c = { tick = tick, skip = M.skipped_rows(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) }
    cache[buf] = c
  end
  return c.skip
end

local provider_set = false
local function set_provider()
  if provider_set then return end
  provider_set = true
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, _, buf)
      return attached[buf] == true and vim.g.org_pretty ~= false
    end,
    on_line = function(_, _, buf, row)
      if skipped(buf)[row] then return end
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
      if not line then return end
      for _, m in ipairs(M.matches(line)) do
        vim.api.nvim_buf_set_extmark(buf, ns, row, m[1], { end_col = m[2], conceal = m[3], ephemeral = true })
      end
    end,
  })
end

--- Show pretty symbols in `buf` (an org buffer).
function M.attach(buf)
  set_provider()
  attached[buf] = true
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      attached[buf], cache[buf] = nil, nil
    end,
  })
end

function M.attached(buf) return attached[buf] == true end

return M
