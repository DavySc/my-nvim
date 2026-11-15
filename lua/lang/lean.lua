-- Lean 4, through lean.nvim (github.com/Julian/lean.nvim): the Lean server
-- (`lake serve` in a Lake project, `lean --server` otherwise), the infoview
-- with goals, widgets and pins, `\alpha` → α input, interactive hover,
-- semantic highlighting, inlay hints and the goal markers in the sign column.
-- On top of it (lua/config/lean.lua, keys in ftplugin/lean.lua): Lake builds
-- into the quickfix list, new projects with Mathlib, and Snacks pickers for
-- symbols, Loogle and the library sources.
--
-- Lean itself comes from elan, which mason doesn't have: install it once per
-- machine (README, "Lean 4"). elan then fetches whichever Lean each project's
-- lean-toolchain names, so lean.nvim never has to match a version.

---@type Lang
return {
  ft = { "lean" },
  plugins = {
    { src = "https://github.com/Julian/lean.nvim" },
  },
  declare = function()
    -- Read when lean.nvim loads (plugin/lean.lua), so it's set at startup.
    ---@type lean.Config
    vim.g.lean_config = {
      -- lean.nvim's suggested keys, all on <LocalLeader> (\): \i infoview,
      -- \x pin, \c clear pins, \dd auto-diff, \s accept a suggestion,
      -- \\ how to type the symbol under the cursor, \r restart the file.
      -- K is lean.nvim's hover, where terms are clickable.
      mappings = true,
      infoview = {
        -- A column on the right on a wide screen, a strip at the bottom on a
        -- narrow one (a laptop split in two).
        orientation = "auto",
        width = 1 / 3,
        height = 1 / 3,
      },
      -- The same `\` Lean uses everywhere (VS Code, the web editor): \to → →,
      -- \N → ℕ, \< \> → ⟨ ⟩; <Tab> or a space ends it. Add your own here.
      abbreviations = { leader = "\\", extra = {} },
    }

    -- Works outside Lean buffers (it is how a project starts).
    vim.api.nvim_create_user_command("LeanNew", function(opts)
      local name, kind = opts.fargs[1], opts.fargs[2]
      if kind and kind ~= "math" then
        return vim.notify("LeanNew: second argument is `math` or nothing", vim.log.levels.ERROR)
      end
      require("config.lean").new_project(name, kind == "math")
    end, {
      nargs = "+",
      complete = function(_, line)
        return #vim.split(line, "%s+", { trimempty = true }) >= 2 and { "math" } or {}
      end,
      desc = "New Lean project here: :LeanNew name [math] (math: with Mathlib, prebuilt)",
    })
  end,
  setup = function()
    -- lean.nvim's snippets (VS Code format: theorem, lemma, def, match, ...).
    -- LuaSnip's vscode loader only looked at 'runtimepath' when completion
    -- loaded, which was before this plugin, so point it at them.
    local plugin = vim.fn.stdpath("data") .. "/site/pack/core/opt/lean.nvim"
    require("luasnip.loaders.from_vscode").lazy_load({ paths = { plugin } })
  end,
}
