local directory=debug.getinfo(1,"S").source:gsub("^@", ""):match("(.*/)")
local H=dofile(directory.."harness.lua")
for _,name in ipairs({"config","toggle","dismiss"}) do
  H.test("Lazygit "..name.." config contract",function()
    local file=H.root.."/"..(name=="dismiss" and "dismiss.lua" or "init.lua")
    for _,convention in ipairs(name=="config" and {"rex","lua"} or {"lua"}) do H.command({"luajit",directory..name.."-fixture.lua",file,convention}) end
  end)
end
local function fixture(t,location)
  local f=H.fixture(t,"lazygit"); local cwd
  if location=="umbrella" or location=="one-repository" then
    cwd=f.workspace; if location=="one-repository" then H.command({"mv",f.web,f.directory.."/other-web"}) end
  elseif location=="worktrees" then
    cwd=f.directory.."/worktrees"; H.command({"mkdir",cwd}); local linked=cwd.."/feature's worktree"
    f:git(f.core,{"worktree","move",f.linked,linked}); f.linked=linked
    f:git(f.core,{"worktree","add","-b","second-feature",cwd.."/second-feature"})
  elseif location=="main" then cwd=f.core
  elseif location=="linked" then cwd=f.linked.."/src"; H.command({"mkdir","-p",cwd})
  else
    cwd=(location=="nested" and f.core or f.web).."/src"
    if location=="nested" then local nested=f.core.."/embedded"; H.command({"mkdir",nested}); f:git(nested,{"init","-b","main"}) end
  end
  local before=f:view()
  local ui=H.terminal(t,f,{"/bin/sh",H.root.."/launch.sh",before.windows[1].window_id,f.env.REX_BLOCK,""},cwd)
  local function dismissed()
    local after=f:view(); H.equal(after.windows[1].layers,before.windows[1].layers); H.equal(after.windows[1].focused_block_id,f.env.REX_BLOCK); f:no_node()
  end
  return f,ui,cwd,dismissed
end
H.test("umbrella selection opens exactly the selected linked checkout without Node",function(t)
  local f,ui,_,dismissed=fixture(t,"umbrella")
  for _,text in ipairs({"Lazygit · Choose a worktree","core / main","core / feature/test","web / main","modified","clean"}) do ui:expect(text) end
  ui:press("feature/test"); ui:press(" "); assert(not ui:output():find("LG_STARTED:",1,true),"Selection launched without Enter")
  ui:press("\r","LG_STARTED:"); ui:done(); H.equal(H.read(f.lazygitLog),f.linked); dismissed()
end)
H.test("umbrella picker cancellation never launches Lazygit",function(t)
  local f,ui,_,dismissed=fixture(t,"umbrella"); ui:expect("Lazygit · Choose a worktree"); ui:press("\27"); ui:done()
  assert(not H.read(f.lazygitLog)); dismissed()
end)
for _,location in ipairs({"main","linked","nested","single","one-repository","worktrees"}) do
  H.test("direct launch without picker: "..location,function(t)
    local f,ui,cwd,dismissed=fixture(t,location)
    H.wait(function() local text=ui:output(); return text:find("LG_STARTED:",1,true) or text:find("Lazygit · Choose a worktree",1,true) end,"Neither Lazygit nor picker started")
    assert(not ui:output():find("Choose a worktree",1,true),"Single repository requires no picker")
    ui:expect("LG_STARTED:"); ui:done()
    local expected=location=="one-repository" and f.core or location=="worktrees" and f.linked or cwd
    H.equal(H.read(f.lazygitLog),expected); dismissed()
  end)
end
H.test("launch failure stays visible until acknowledged, then preserves exit status",function(t)
  local f=H.fixture(t,"lazygit"); H.write(f.bin.."/lazygit","#!/bin/sh\nprintf 'LG_FAILED\\n'\nexit 7\n")
  local before=f:view(); local ui=H.terminal(t,f,{"/bin/sh",H.root.."/launch.sh",before.windows[1].window_id,f.env.REX_BLOCK,""},f.web.."/src")
  ui:expect("LG_FAILED"); ui:expect("Press Enter to close this popup"); assert(ui.child:running(),"Error disappeared before acknowledgement")
  ui:press("\r"); ui:done(7); H.equal(f:view().windows[1].layers,before.windows[1].layers); f:no_node()
end)
H.test("configured floating action cancels and restores the invoking view without Node",function(t)
  local f=H.fixture(t,"lazygit"); local before=f:view()
  H.write(f.env.REX_CONFIG,H.read(f.env.REX_CONFIG)..'require("rex-lazygit").setup{bindings={open="alt+g"},bounds={0.1,0.2,0.7,0.6}}\n')
  f:call({"config","reload"})
  local found=0
  for _,binding in ipairs(f:json({"api","call","client.keymap","{}"}).bindings) do
    if binding.action=="lazygit_open" then H.equal(binding.keys,{"alt+g"}); found=found+1 end
  end
  H.equal(found,1,"The real keymap must contain only the configured Lazygit chord")
  local created=f:json({"split","-s",f.env.REX_SESSION,"-b",f.env.REX_BLOCK,"-c",f.workspace,"--shell=none","--json","--","/bin/sh","-c","while :; do sleep 60; done"})
  local origin=created.block_ids[1]; f:call({"do","lazygit_open","-s",f.env.REX_SESSION,"-b",origin})
  local popup=H.wait(function() for _,b in ipairs(f:blocks()) do if b.label=="Lazygit" then return b.block_id end end end,"No Lazygit popup")
  H.wait(function() return f:capture(popup):find("Lazygit · Choose a worktree",1,true) end,"Picker did not start")
  local geometry=false
  for _,layer in ipairs(f:view().windows[1].layers) do
    if layer.layout and layer.layout.block_id==popup then H.equal(layer.layout.rect,{0.1,0.2,0.7,0.6}); geometry=true end
  end
  assert(geometry,"The actual floating popup must use configured bounds")
  f:call({"send-key","-s",f.env.REX_SESSION,"-b",popup,"escape"})
  H.wait(function() for _,b in ipairs(f:blocks()) do if b.block_id==popup then return false end end; return true end,"Popup did not close")
  local after=f:view(); H.equal(after.windows[1].focused_block_id,origin); H.equal(#after.windows[1].layers,#before.windows[1].layers); f:no_node()
end)
dofile(directory.."discovery.lua")(H,"lazygit")
H.finish()
