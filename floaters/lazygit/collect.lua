local ctx = ...
local directory = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
local U = dofile(directory .. "../../lib/util.lua")
local G = dofile(directory .. "../../lib/git.lua")
local root = U.real(ctx.cwd)
-- Lazygit owns worktree switching inside a checkout; collection never changes that checkout.
if G.try(root, { "rev-parse", "--show-toplevel" }) then return { { value = root, label = root } } end
print("Finding Git repositories in " .. U.display(root) .. "…")
local discovery = G.discover(root)
for _, warning in ipairs(discovery.warnings) do print(U.display(warning)) end
local groups, count, checkout = {}, 0, nil
for _, item in ipairs(discovery.items) do
  if not groups[item.group] then groups[item.group] = true; count = count + 1 end
  if U.inside(root, item.cwd) and (not checkout or item.cwd == item.primary) then checkout = item end
end
if count <= 1 then
  local cwd = (checkout or discovery.items[1] or {}).cwd or root
  return { { value = cwd, label = cwd } }
end
return U.map(discovery.items, function(item)
  return { value = item.cwd,
    label = item.repository .. " / " .. item.branch .. " · " .. (item.dirty and "modified" or "clean"),
    description = item.cwd }
end)
