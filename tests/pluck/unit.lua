local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
local H = dofile(directory .. "../harness.lua")
package.path = H.root .. "/floaters/?.lua;" .. package.path
_G.H = H
dofile(directory .. "tokens.lua")
dofile(directory .. "window.lua")
H.finish()
