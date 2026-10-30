local directory=debug.getinfo(1,"S").source:gsub("^@", ""):match("(.*/)")
local U,G,P=dofile(directory.."lib/util.lua"),dofile(directory.."lib/git.lua"),dofile(directory.."lib/picker.lua")
local code=0
local ok,err=pcall(function()
  local root=U.real("."); local cwd=root
  -- Lazygit owns worktree switching inside a repository. Discover only when the origin is an umbrella.
  if not G.try(root,{"rev-parse","--show-toplevel"}) then
    print("Finding Git repositories in "..U.display(root).."…")
    local discovery=G.discover(root); for _,warning in ipairs(discovery.warnings) do print(U.display(warning)) end
    local groups,count,checkout={},0,nil
    for _,item in ipairs(discovery.items) do
      if not groups[item.group] then groups[item.group]=true; count=count+1 end
      if U.inside(root,item.cwd) and (not checkout or item.cwd==item.primary) then checkout=item end
    end
    if count>1 then
      local picked=P.choose("Lazygit · Choose a worktree · "..root,U.map(discovery.items,function(item)
        return {value=item.cwd,label=item.repository.." / "..item.branch.." · "..(item.dirty and "modified" or "clean"),description=item.cwd}
      end))
      if not picked then return end; cwd=picked[1]
    else
      -- Prefer a checkout under the umbrella, and its main checkout when present, over outside siblings.
      cwd=(checkout or discovery.items[1] or {}).cwd or root
    end
  end
  local result=U.checked(rex.exec({"/bin/sh","-c",'exec lazygit </dev/tty >/dev/tty 2>/dev/tty'},{cwd=cwd})); code=result.code<0 and 1 or result.code
end)
if not ok then code=1; io.stderr:write("Lazygit: "..tostring(err).."\n") end
if code~=0 then P.input("Lazygit exited with status "..code..". Press Enter to close this popup") end
local restored,message=pcall(dofile,directory.."dismiss.lua"); if not restored then io.stderr:write("Could not restore the previous Rex view: "..tostring(message).."\n") end
rex.stop(code)
