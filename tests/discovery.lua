-- The vendored Git discovery contract is exercised independently in each standalone package.
return function(H,kind)
H.test("Git/Worktrunk discovery, supported JSON schemas, and safe fallback without Node",function(t)
  local f=H.fixture(t,kind)
  local function discover() return f:lua("return G.discover(rex.args.directory)",{directory=f.workspace}) end
  local fallback=discover(); local paths={}; for _,item in ipairs(fallback.items) do paths[item.cwd]=item.dirty end
  H.equal(paths,{[f.core]=false,[f.web]=false,[f.linked]=true})
  local wtFile,wtLog=f.bin.."/wt",f.directory.."/wt.args"
  local wt=H.which("wt")
  if wt then
    H.write(wtFile,"#!/bin/sh\nprintf '%s\\n' \"$@\" >> "..H.quote(wtLog).."\nexec "..H.quote(wt).." \"$@\"\n"); H.command({"chmod","700",wtFile})
    local result=discover(); H.equal(result.items,fallback.items); H.equal(result.warnings,{})
    H.contains(H.read(wtLog),"list.full=false\nlist\n--format=json")
  end
  for _,schema in ipairs({1,2}) do
    local row={branch="from-worktrunk"}
    if schema==1 then row.kind="worktree"; row.path=f.linked; row.is_main=true; row.working_tree={staged=false,modified=true,untracked=false,renamed=false,deleted=false}
    else row.worktree={path=f.linked,main=true,changes={staged=false,modified=true,untracked=false,renamed=false,deleted=false}} end
    local items={row,{branch="branch-without-checkout"}}
    local data=f.directory.."/wt.json"; H.write_json(data,schema==1 and items or {schema=2,items=items})
    H.write(wtFile,"#!/bin/sh\n/bin/cat "..H.quote(data).."\n"); H.command({"chmod","700",wtFile})
    local result=discover(); H.equal(#result.items,1); H.equal(result.items[1].branch,"from-worktrunk"); H.equal(result.items[1].dirty,true)
  end
  H.write(wtFile,"#!/bin/sh\nprintf 'invalid JSON'\n")
  local broken=discover(); H.equal(broken.items,fallback.items)
  for _,warning in ipairs(broken.warnings) do assert(warning:find("Worktrunk.*using Git")) end
  H.command({"rm",wtFile}); H.equal(discover().items,fallback.items); f:no_node()
end)
end
