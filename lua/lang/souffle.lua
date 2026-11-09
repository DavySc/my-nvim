-- Soufflé (Datalog): filetype, comment string and a Vim syntax file
-- (syntax/souffle.vim); the nvim-treesitter parser has no highlights query,
-- so treesitter is stopped for these buffers. There is no
-- language server or formatter for it, so no tools. `souffle` itself is run
-- from a terminal.

---@type Lang
return {
	ft = { "souffle" },
	declare = function()
		vim.filetype.add({ extension = { dl = "souffle", souffle = "souffle" } })
	end,
	setup = function()
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "souffle",
			group = vim.api.nvim_create_augroup("config_souffle", { clear = true }),
			callback = function(ev)
				vim.bo[ev.buf].commentstring = "// %s"
				-- A souffle parser is installed but ships no highlights query, so
				-- treesitter paints nothing and suppresses syntax/souffle.vim.
				if vim.b[ev.buf].ts_highlight then
					pcall(vim.treesitter.stop, ev.buf)
				end
				vim.bo[ev.buf].syntax = "souffle"
			end,
		})
	end,
}
