-- Rust.

---@type Lang
return {
  ft = { "rust", "toml" },
  parsers = { "rust", "toml" },
  tools = { codelldb = "codelldb" },
  plugins = {
    { src = "https://github.com/saecki/crates.nvim", config = function() require("crates").setup({}) end },
  },
  setup = function()
    -- Like HLS, rust-analyzer must match the project's toolchain (its
    -- proc-macro server is tied to rustc's version), so in a flake project it
    -- runs through `nix develop` to get the flake's rust-analyzer/cargo/
    -- RUST_SRC_PATH; otherwise PATH (rustup). Formatting falls through conform
    -- to the LSP (rustfmt).
    vim.lsp.config("rust_analyzer", {
      cmd = require("config.core.lsp").flake_cmd({ "rust-analyzer" }),
      -- nvim-lspconfig's root_dir runs rustc/cargo to tell library files
      -- apart, and throws when neither is on PATH, which is the normal state
      -- of a flake project outside its dev shell. This one just looks for the
      -- workspace: the outermost Cargo.toml with a [workspace] table, else the
      -- nearest one, else rust-project.json.
      root_dir = function(bufnr, on_dir)
        local name = vim.api.nvim_buf_get_name(bufnr)
        local dir = name ~= "" and vim.fs.dirname(name) or (vim.uv.cwd() or ".")
        local root
        for _, toml in ipairs(vim.fs.find("Cargo.toml", { path = dir, upward = true, limit = math.huge })) do
          root = root or vim.fs.dirname(toml)
          local f = io.open(toml)
          if f then
            local text = f:read("*a") or ""
            f:close()
            if text:find("^%[workspace%]") or text:find("\n%[workspace%]") then root = vim.fs.dirname(toml) end
          end
        end
        root = root or vim.fs.root(bufnr, { "rust-project.json" })
        if root then on_dir(root) end
      end,
      settings = {
        ["rust-analyzer"] = { check = { command = "clippy" } },
      },
    })
    require("config.core.lsp").enable({ "rust_analyzer" })

    require("config.core.dap").configure({ "rust" }, {
      {
        name = "Launch (codelldb)",
        type = "codelldb",
        request = "launch",
        program = function()
          -- `cargo build` first; target/debug/<crate> is the usual answer.
          local root = vim.fs.root(0, "Cargo.toml") or vim.uv.cwd()
          return vim.fn.input({ prompt = "Executable: ", default = root .. "/target/debug/", completion = "file" })
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        console = "integratedTerminal",
      },
    })
  end,
}
