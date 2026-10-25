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
