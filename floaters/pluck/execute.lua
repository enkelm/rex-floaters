local filename = debug.getinfo(1, "S").source:gsub("^@", "")
local directory = assert(filename:match("(.*/)"), "Load Pluck from its execute.lua file.")
package.path = directory .. "../?.lua;" .. directory .. "../?/init.lua;" .. package.path
return require("pluck.executor")(...)
