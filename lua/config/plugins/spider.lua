return {
  "chrisgrieser/nvim-spider",
  lazy = false, -- or true, by your preference
  keys = {
    { "<leader>w", function() require("spider").motion("w") end, mode = { "n", "o", "x" }, desc = "Spider-w" },
    { "<leader>e", function() require("spider").motion("e") end, mode = { "n", "o", "x" }, desc = "Spider-e" },
    { "<leader>b", function() require("spider").motion("b") end, mode = { "n", "o", "x" }, desc = "Spider-b" },
  },
}

