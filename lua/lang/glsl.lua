-- GLSL (OpenGL / Vulkan shaders). Neovim already gives .glsl, .vert, .frag,
-- .geom, .tesc, .tese and .comp the `glsl` filetype; glsl_analyzer (mason)
-- does completion, go-to-definition and diagnostics. Buffer-local bits live
-- in ftplugin/glsl.lua.

---@type Lang
return {
  ft = { "glsl" },
  parsers = { "glsl" },
  tools = { glsl_analyzer = "glsl_analyzer" },
  setup = function()
    -- nvim-lspconfig's glsl_analyzer config supplies cmd, filetypes and root.
    require("config.core.lsp").enable({ "glsl_analyzer" })

    -- clang-format understands GLSL well enough; same rule as C/C++: only on
    -- save when the project pins a style, :Format always.
    local format = require("config.core.format")
    format.add({ glsl = { "clang-format" } })
    format.guard({ "glsl" }, require("lang.c").has_clang_format)
  end,
}
