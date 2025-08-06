return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  keys = {
	    {
		"<leader>fg", 
		function() Snacks.picker.grep()
		end
	    },
	    { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
	    { "<leader>ff", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
	    { "<leader>e", function() Snacks.explorer() end, desc = "File Explorer" },
	    { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
	    { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
    	    { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
    	    { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
   
	 },

  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    bigfile = { enabled = true },
    dashboard = { enabled = true },
    image = {enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    picker = { enabled = true },
    notifier = { enabled = true },
    quickfile = { enabled = true },
    scope = { enabled = true },
    scroll = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
  },
}
