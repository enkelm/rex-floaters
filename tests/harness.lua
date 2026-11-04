-- Test infrastructure only. Run with Rex's embedded Lua; no Node or Lua packages.
local H = {tests={}, failed=0, passed=0, skipped=0}
local directory = debug.getinfo(1,"S").source:gsub("^@", ""):match("(.*/)")
H.root = rex and assert(rex.exec({"realpath", directory..".."})).stdout:gsub("%s+$", "") or directory..".."
function H.json(value) return assert(rex.json.encode(value)) end
function H.decode(text) return assert(rex.json.decode(text)) end
function H.quote(value) return "'"..tostring(value):gsub("'", "'\\''").."'" end
function H.run(argv, opts)
  local result, err = rex.exec(argv, opts or {timeout=30}); assert(result, err)
  return result
end
function H.command(argv, opts)
  local result=H.run(argv,opts)
  assert(result.ok, table.concat(argv," ")..": "..result.stderr..result.stdout)
  return result.stdout
end
function H.which(bin) local r=H.run({"/bin/sh","-c",'command -v "$1"',"test",bin}); if r.ok then return r.stdout:gsub("%s+$", "") end end
function H.read(file) local f=io.open(file,"rb"); if not f then return nil end; local text=f:read("*a"); f:close(); return text end
function H.write(file,text) local f=assert(io.open(file,"wb")); assert(f:write(text)); assert(f:close()) end
function H.read_json(file) local text=H.read(file); if text then return H.decode(text) end end
function H.write_json(file,value) H.write(file,H.json(value)) end
function H.contains(text,part) assert(type(text)=="string" and text:find(part,1,true), "Missing "..part.." in "..tostring(text)) end
function H.equal(a,b,context)
  local function equal(x,y)
    if type(x)~=type(y) then return false end
    if type(x)~="table" then return x==y end
    for k,v in pairs(x) do if not equal(v,y[k]) then return false end end
    for k in pairs(y) do if x[k]==nil then return false end end
    return true
  end
  if not equal(a,b) then
    local format = rex and H.json or tostring
    error((context or "Values differ")..": "..format(a).." != "..format(b), 0)
  end
end
function H.rejects(fn,part) local ok,err=pcall(fn); assert(not ok,"Expected refusal"); H.contains(tostring(err),part) end
function H.wait(fn,message,seconds)
  -- Wall clock only bounds a poll; tests never depend on a fixed process startup delay.
  local deadline=os.time()+(seconds or 12)
  repeat local value=fn(); if value then return value end; rex.sleep(.03) until os.time()>deadline
  error(message,0)
end
function H.test(name,fn) H.tests[#H.tests+1]={name=name,fn=fn} end
function H.finish()
  for _,test in ipairs(H.tests) do
    local t={cleanup={}}
    function t:after(fn) self.cleanup[#self.cleanup+1]=fn end
    function t:skip(message) error({skip=message},0) end
    local ok,err=pcall(test.fn,t)
    for i=#t.cleanup,1,-1 do local clean,message=pcall(t.cleanup[i]); if not clean then ok,err=false,"Cleanup: "..tostring(message) end end
    if ok then H.passed=H.passed+1; print("PASS "..test.name)
    elseif type(err)=="table" and err.skip then H.skipped=H.skipped+1; print("SKIP "..test.name..": "..err.skip)
    else H.failed=H.failed+1; print("FAIL "..test.name..": "..tostring(err)) end
  end
  print(string.format("%d passed; %d failed; %d skipped",H.passed,H.failed,H.skipped))
  assert(H.failed==0,"Test failures")
end
function H.fixture(t,kind)
  local rexbin,fzf=assert(os.getenv("REX_FLOATERS_REX") or H.which("rex"),"Rex is required"),assert(H.which("fzf"),"fzf is required")
  local tv=H.which("tv")
  local dir=H.command({"mktemp","-d","/tmp/rex-lua-suite.XXXXXXXX"}):gsub("%s+$", "")
  dir=H.command({"realpath",dir}):gsub("%s+$", "")
  local f={directory=dir,bin=dir.."/bin",root=dir.."/reviews",nodeLog=dir.."/node-called",kind=kind}
  H.command({"mkdir","-p",f.bin,dir.."/sessions",dir.."/xdg/config",dir.."/xdg/data",dir.."/xdg/cache",dir.."/xdg/state"})
  H.command({"ln","-s",H.root,dir.."/rex-floaters"})
  local config=dir.."/init.lua"; H.write(config,"package.path = "..H.json(dir.."/?/init.lua;").." .. package.path\nrequire('rex-floaters').setup()\n")
  H.command({"ln","-s",rexbin,f.bin.."/rex"})
  H.write(f.bin.."/node","#!/bin/sh\nprintf 'unexpected node\\n' >> "..H.quote(f.nodeLog).."\nexit 86\n")
  H.command({"chmod","700",f.bin.."/node"})
  f.env={PATH=f.bin..":/usr/bin:/bin:/usr/sbin:/sbin",REX_CONFIG=config,REX_SERVER="unix://"..dir.."/rex.sock",REX_SESSION="",REX_BLOCK="",REX_FLOATERS_REX=rexbin,REX_FLOATERS_FZF=fzf,REX_FLOATERS_TV=tv,REX_HUNK_REX=rexbin,REX_HUNK_FZF=fzf,REX_HUNK_STATE_DIR=f.root,REX_AGENT_DIR=dir.."/agents",REX_BIN_DIR=f.bin,
    XDG_CONFIG_HOME=dir.."/xdg/config",XDG_DATA_HOME=dir.."/xdg/data",XDG_CACHE_HOME=dir.."/xdg/cache",XDG_STATE_HOME=dir.."/xdg/state"}
  f.tv=tv
  f.rex=rexbin
  local server=assert(rex.exec.start({rexbin,"server","run","--listen",f.env.REX_SERVER,"--state-dir",dir.."/server","--config",config},{env=f.env,stdout=false,stderr=false}))
  t:after(function() server:kill(); assert(server:wait(10)); H.command({"rm","-rf",dir}) end)
  function f:call(args,raw)
    local argv={rexbin,"--server",self.env.REX_SERVER,"--autostart=false"}; for _,v in ipairs(args) do argv[#argv+1]=v end
    local r=H.run(argv,{env=self.env,timeout=30}); if raw then return r end
    assert(r.ok,r.stderr..r.stdout); return r.stdout
  end
  function f:json(args) return H.decode(self:call(args)) end
  H.wait(function() return f:call({"server","status"},true).ok end,"Isolated Rex server did not start")
  local created=f:json({"new","lua-test","-c",dir,"--shell=none","--json","--","/bin/sh","-c","while :; do sleep 60; done"})
  f.env.REX_SESSION=created.session_id; f.env.REX_BLOCK=created.initial_windows[1].block_ids[1]
  function f:lua(body,args)
    local modules=kind=="hunk" and "/hunk/" or "/lib/"
    local source="local dir="..H.json(H.root..modules).."; local U=dofile(dir..'util.lua'); local G=dofile(dir..'git.lua'); "
    if kind=="hunk" then source=source.."local S=dofile(dir..'state.lua'); local A=dofile(dir..'agents.lua'); local client=dofile(dir..'client.lua').connect(); local workflow=dofile(dir..'workflow.lua').new(client); " end
    return self:json({"do","-e",source.."local function main() "..body.." end; print(U.encode(main()))","--args",H.json(args or {})})
  end
  function f:git(cwd,args) local argv={"git","-C",cwd}; for _,v in ipairs(args) do argv[#argv+1]=v end; return H.command(argv,{env=self.env,timeout=15}) end
  f.workspace=dir.."/workspace"; f.core=f.workspace.."/core"; f.web=f.workspace.."/web"; f.linked=dir.."/feature's worktree"
  for _,cwd in ipairs({f.core,f.web}) do
    H.command({"mkdir","-p",cwd}); f:git(cwd,{"init","-b","main"}); H.write(cwd.."/a.txt","before\n"); f:git(cwd,{"add","."})
    f:git(cwd,{"-c","user.name=Test","-c","user.email=test@example.test","-c","commit.gpgsign=false","-c","core.hooksPath=/dev/null","commit","-m","base"}); H.command({"mkdir",cwd.."/src"})
  end
  f:git(f.core,{"worktree","add","-b","feature/test",f.linked}); H.write(f.linked.."/a.txt","after\n")
  f.notes=dir.."/notes.json"; H.write(f.notes,"[]")
  if kind=="hunk" then
    H.write(f.bin.."/hunk",string.format([=[#!/bin/sh
case "$1" in
 --version) printf 'fixture\n';;
 diff|show|stash)
   printf '{"sessionId":"hunk:%%s","pid":%%s}' "$$" "$$" > '%s/sessions/'"$$".json
   trap 'rm -f "%s/sessions/$$.json"; exit 1' TERM INT
   while [ ! -f '%s/sessions/'"$$".stop ]; do sleep 0.05; done
   rm -f '%s/sessions/'"$$".json;;
 session) case "$2" in
   list) printf '{"sessions":['; separator=''; for file in '%s/sessions/'*.json; do [ -f "$file" ] || continue; printf '%%s' "$separator"; /bin/cat "$file"; separator=','; done; printf ']}';;
   comment) printf '{"comments":'; /bin/cat '%s'; printf '}';;
 esac;;
 *) exit 2;;
esac
]=],dir,dir,dir,dir,dir,f.notes)); H.command({"chmod","700",f.bin.."/hunk"})
  end
  f.lazygitLog=dir.."/lazygit.cwd"
  H.write(f.bin.."/lazygit","#!/bin/sh\nprintf '%s' \"$PWD\" > "..H.quote(f.lazygitLog).."\nprintf '\\nLG_STARTED:%s\\n' \"$PWD\"\n"); H.command({"chmod","700",f.bin.."/lazygit"})
  function f:view() return self:json({"session","inspect",self.env.REX_SESSION,"--json"}) end
  function f:blocks() return self:json({"block","ls","-s",self.env.REX_SESSION,"--json"}).blocks end
  function f:capture(pane) return self:call({"capture","-s",self.env.REX_SESSION,"-b",pane,"--trim"}) end
  function f:no_node() assert(not H.read(self.nodeLog),"A Lua workflow launched Node") end
  return f
end
function H.terminal(t,f,argv,cwd,options)
  local command={"python3",H.root.."/tests/terminal.py"}; for _,arg in ipairs(argv) do command[#command+1]=arg end
  local transcript=f.directory.."/pty-output"; H.write(transcript,"")
  local env={}; for k,v in pairs(f.env) do env[k]=v end
  env.REX_TEST_PTY_OUTPUT=transcript
  for key,value in pairs(options or {}) do env["REX_TEST_"..key]=tostring(value) end
  env.FZF_DEFAULT_OPTS="--filter=no-such-choice --print-query"; env.FZF_DEFAULT_OPTS_FILE="/missing/fzf-options"
  local child=assert(rex.exec.start(command,{env=env,cwd=cwd or f.directory,stdin=true}))
  t:after(function() if child:running() then child:kill() end; assert(child:wait(10)) end)
  local ui={child=child}
  function ui:output() return H.read(transcript) or "" end
  function ui:expect(text,offset)
    local ok,err=pcall(H.wait,function() return self:output():sub(offset or 1):find(text,1,true) end,"Missing "..text,8)
    local result=not child:running() and child:wait(1) or nil
    assert(ok,tostring(err)..". Terminal: "..self:output():sub(-2500)..(result and result.stderr or ""))
  end
  function ui:press(keys,text) local offset=#self:output()+1; assert(child:write(keys)); if text then self:expect(text,offset) else rex.sleep(.15) end end
  function ui:resize(narrow) assert(child:kill(narrow and "SIGUSR1" or "SIGUSR2")); rex.sleep(.15) end
  function ui:done(code) local r=assert(child:wait(10)); H.equal(r.code,code or 0,self:output():sub(-1000)..r.stderr) end
  return ui
end
return H
