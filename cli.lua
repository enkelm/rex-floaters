local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
local runner = dofile(directory .. "lib/runner.lua")
local ok, code = pcall(runner.run, assert(rex.args.entry, "Missing floater definition."))
if not ok then
  io.stderr:write("rex-floaters: " .. tostring(code) .. "\n")
  code = 1
end
local restored, message = pcall(dofile, directory .. "dismiss.lua")
if not restored then io.stderr:write("Could not restore the previous Rex view: " .. tostring(message) .. "\n") end
rex.stop(code)
