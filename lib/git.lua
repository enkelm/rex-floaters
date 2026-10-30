local U = dofile(debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)") .. "util.lua")
local M = {}
local function argv(cwd, args) local out={"git","-C",cwd}; for _, v in ipairs(args) do out[#out+1]=v end; return out end
function M.run(cwd, args) return U.command(argv(cwd,args), {env={GIT_OPTIONAL_LOCKS="0"}}) end
function M.try(cwd, args) local ok, value=pcall(M.run,cwd,args); if ok then return U.trim(value) end end
local function start(cwd,args) return U.start(argv(cwd,args),{env={GIT_OPTIONAL_LOCKS="0"}}) end
local function git_group(seed,common)
  local records=U.array()
  for _, record in ipairs(U.split(M.run(seed,{"worktree","list","--porcelain","-z"}),"\0\0")) do
    local cwd,branch,head
    for _,field in ipairs(U.split(record,"\0")) do
      if field:sub(1,9)=="worktree " then cwd=field:sub(10) elseif field:sub(1,18)=="branch refs/heads/" then branch=field:sub(19) elseif field:sub(1,5)=="HEAD " then head=field:sub(6) end
    end
    if cwd then records[#records+1]={cwd=cwd,branch=branch or (head and head:find("[^0]") and "detached "..head:sub(1,8) or "unborn")} end
  end
  local primary=records[1] and records[1].cwd or seed
  return {key=U.real(common),label=U.basename(primary),primary=primary},records
end
function M.repository(directory)
  local cwd=U.real(directory); local common=M.try(cwd,{"rev-parse","--path-format=absolute","--git-common-dir"}); if not common then return end
  local repo,records=git_group(cwd,common); local selected
  for _,record in ipairs(records) do if U.inside(record.cwd,cwd) and (not selected or #record.cwd>#selected.cwd) then selected=record end end
  repo.branch=selected and selected.branch; return repo
end
-- Accept both Worktrunk JSON schemas, as the upstream extension does. Only physical worktrees belong here.
function M.worktrunk(text,seed,common)
  local json=U.decode(text); local items=json.items or json
  if type(items)~="table" or (json.items==nil and text:match("^%s*%[")==nil) then error("Unsupported Worktrunk list JSON schema",0) end
  local records,primary={},nil
  for _,item in ipairs(items) do
    local tree=type(item.worktree)=="table" and item.worktree or nil
    local kind=item.kind or (tree and "worktree" or "branch"); local cwd=item.path or (tree and tree.path)
    if kind=="worktree" then
      if type(cwd)~="string" or cwd:sub(1,1)~="/" then error("Worktrunk returned an invalid worktree path",0) end
      local isMain=item.is_main or (tree and tree.main)
      if isMain then primary=cwd end
      local head=item.head or item.commit or {}; local branch=item.branch or (head.sha and "detached "..head.sha:sub(1,8) or "unborn")
      local changes=tree and tree.changes or item.working_tree; local dirty
      if type(changes)=="table" then
        local complete=true; dirty=false
        for _,key in ipairs({"staged","modified","untracked","renamed","deleted"}) do if changes[key]==nil then complete=false elseif changes[key] then dirty=true end end
        if changes.conflicted or item.operation_state=="conflicts" then dirty=true end
        if not complete and not dirty then dirty=nil end
      end
      records[#records+1]={cwd=cwd,branch=branch,dirty=dirty}
    end
  end
  if #records==0 then error("Worktrunk returned no worktrees",0) end
  primary=primary or records[1].cwd or seed
  return {repo={key=U.real(common),label=U.basename(primary),primary=primary},records=records}
end
function M.discover(directory)
  local root=U.real(directory); local seeds,seen,warnings,visited,truncated={},{},U.array(),0,false
  local skip={[".git"]=true,node_modules=true,vendor=true,dist=true,build=true,[".next"]=true,[".venv"]=true}
  local function seed(value) if not seen[value] then seen[value]=true; seeds[#seeds+1]=value end end
  local function walk(dir,depth)
    if visited>=1500 then truncated=true; return end; visited=visited+1
    local ok,entries=pcall(U.entries,dir); if not ok then warnings[#warnings+1]=dir..": "..tostring(entries); return end
    for _,entry in ipairs(entries) do if entry.name==".git" then seed(dir) end end
    if depth==3 then return end
    for _,entry in ipairs(entries) do if not entry.file and not entry.symlink and not skip[entry.name] then walk(U.join(dir,entry.name),depth+1); if truncated then return end end end
  end
  walk(root,0)
  local containing=M.try(root,{"rev-parse","--show-toplevel"}); if containing then seed(containing) end
  local commons=U.parallel(seeds,function(value) return start(value,{"rev-parse","--path-format=absolute","--git-common-dir"}) end,
    function(handle,value) local r=U.checked(handle:wait()); return {seed=value,common=r.ok and U.trim(r.stdout) or false} end)
  local unique,groups={},{}
  for _,entry in ipairs(commons) do if entry.common and not unique[entry.common] then unique[entry.common]=true; groups[#groups+1]=entry end end
  local checkouts,paths={},{}
  local wt=U.trim(U.run({"/bin/sh","-c","command -v wt"}).stdout)
  local listings=wt~="" and U.parallel(groups,function(entry)
    -- Same list command and schema normalization as rex-worktrunk, without its switch/create actions.
    -- Force local-only collection even when the user's Worktrunk config enables full mode.
    return U.start({wt,"--config-set","list.full=false","list","--format=json"},{cwd=entry.seed,env={GIT_OPTIONAL_LOCKS="0"}})
  end,function(handle) return U.checked(handle:wait()) end) or {}
  for i,entry in ipairs(groups) do
    local repo,records
    if listings[i] then
      local ok,result=pcall(function()
        if not listings[i].ok then error(listings[i].stderr,0) end
        return M.worktrunk(listings[i].stdout,entry.seed,entry.common)
      end)
      if ok then repo,records=result.repo,result.records else warnings[#warnings+1]="Worktrunk listing failed for "..entry.seed.."; using Git: "..tostring(result) end
    end
    if not records then local ok,a,b=pcall(git_group,entry.seed,entry.common); if ok then repo,records=a,b else warnings[#warnings+1]=entry.seed..": "..tostring(a) end end
    for _,record in ipairs(records or {}) do
      local exists,absolute=pcall(U.real,record.cwd)
      if exists and not checkouts[absolute] then checkouts[absolute]={repo=repo,branch=record.branch,dirty=record.dirty}; paths[#paths+1]=absolute end
    end
  end
  local items=U.parallel(paths,function(cwd)
    if checkouts[cwd].dirty~=nil then return false end
    return start(cwd,{"status","--porcelain=v1","-z","--untracked-files=normal"})
  end,function(handle,cwd)
      local entry=checkouts[cwd]; local dirty=entry.dirty
      if handle then local r=U.checked(handle:wait()); if not r.ok then warnings[#warnings+1]=cwd..": "..r.stderr; return false end; dirty=r.stdout~="" end
      return {cwd=cwd,group=entry.repo.key,repository=entry.repo.label,primary=entry.repo.primary,branch=entry.branch,dirty=dirty}
    end)
  items=U.filter(items,function(item) return item end)
  table.sort(items,function(a,b) if a.repository~=b.repository then return a.repository<b.repository elseif a.group~=b.group then return a.group<b.group else return a.cwd<b.cwd end end)
  if truncated then warnings[#warnings+1]="Directory scan stopped at 1,500 directories. Choose a narrower directory if a repository is missing." end
  return {root=root,items=items,warnings=warnings}
end
function M.base(cwd)
  local configured=M.try(cwd,{"config","--get","hunk.reviewBase"}) or M.try(cwd,{"config","--get","pi.hunkBase"})
  local branch=M.try(cwd,{"symbolic-ref","--quiet","--short","HEAD"})
  local upstream=M.try(cwd,{"rev-parse","--abbrev-ref","--symbolic-full-name","@{upstream}"})
  local remote=M.try(cwd,{"symbolic-ref","--quiet","refs/remotes/origin/HEAD"})
  local candidates={configured or false,upstream and (not branch or upstream:sub(-#branch-1)~="/"..branch) and upstream or false,
    remote and remote:gsub("^refs/remotes/","") or false,"origin/main","origin/master","origin/trunk","main","master","trunk"}
  for _,ref in ipairs(candidates) do if ref and M.try(cwd,{"rev-parse","--verify","--end-of-options",ref.."^{commit}"}) then return ref end end
end
local function commit(cwd,ref)
  if type(ref)~="string" or U.trim(ref)=="" or ref:sub(1,1)=="-" or ref:find("[%z\r\n]") then error("Choose a valid Git commit or branch ref.",0) end
  return U.trim(M.run(cwd,{"rev-parse","--verify","--end-of-options",ref.."^{commit}"}))
end
M.scopes={{"full","Full changes since base"},{"working","Uncommitted"},{"staged","Staged"},{"branch","Branch commits"},{"commit","Commit"},{"stash","Latest stash"},{"auto","Auto"}}
M.labels={}; for _,entry in ipairs(M.scopes) do M.labels[entry[1]]=entry[2] end
function M.recent(cwd)
  local fields=U.split(M.run(cwd,{"log","-80","--format=%H%x00%s%x00"}),"\0"); local out={}
  for i=1,#fields-1,2 do local sha=U.trim(fields[i]); if sha~="" then out[#out+1]={value=sha,label=sha:sub(1,8).." "..fields[i+1]} end end; return out
end
function M.resolve(item,options)
  local cwd=U.real(item.cwd); local head=commit(cwd,"HEAD"); local mode,base=options.mode,options.base; local merge,ref,args
  if mode=="auto" then base=base or M.base(cwd); mode=(M.run(cwd,{"status","--porcelain=v1","-z","--untracked-files=normal"})~="" or not base) and "working" or "branch" end
  if mode=="full" or mode=="branch" then
    base=base or M.base(cwd); if not base then error("No base found for "..cwd..". Choose a base or another scope.",0) end
    merge=U.trim(M.run(cwd,{"merge-base",commit(cwd,base),head})); ref=mode=="full" and merge or merge..".."..head
    args={"diff",ref}; if mode=="full" then args[#args+1]="--no-exclude-untracked" end
  elseif mode=="working" then args={"diff",head,"--no-exclude-untracked"}
  elseif mode=="staged" then args={"diff","--staged"}
  elseif mode=="commit" then ref=commit(cwd,options.ref or "HEAD"); args={"show",ref}
  elseif mode=="stash" then ref=commit(cwd,"stash@{0}"); args={"stash","show",ref}
  else error("Unknown review scope: "..tostring(mode),0) end
  return U.extend(item,{cwd=cwd,mode=mode,base=base,mergeBase=merge,ref=ref,head=head,args=args,
    scope=M.labels[mode]..((mode=="full" or mode=="branch") and " · "..base or mode=="commit" and " · "..ref:sub(1,8) or "")})
end
return M
