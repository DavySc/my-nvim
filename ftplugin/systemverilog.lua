-- SystemVerilog shares the Verilog setup; ftplugin/verilog.lua branches on
-- &filetype where the two differ (the -sv / -g2012 flags).
vim.cmd("runtime ftplugin/verilog.lua")
