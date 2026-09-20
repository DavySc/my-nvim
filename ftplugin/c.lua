-- C shares the C++ setup; ftplugin/cpp.lua branches on &filetype where the two
-- differ (compiler driver and -std).
vim.cmd("runtime ftplugin/cpp.lua")
