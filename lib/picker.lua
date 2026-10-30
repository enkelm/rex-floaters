local U = dofile(debug.getinfo(1,"S").source:gsub("^@", ""):match("(.*/)") .. "util.lua")
local M = {}
function M.choose(title,choices,options)
  options=options or {}; if #choices==0 then return nil end
  local toggle=options.multiple and "toggle" or 'transform(if [ "$FZF_SELECT_COUNT" = 1 ] && [ {n} = {+n} ]; then printf deselect; else printf clear-multi+select; fi)'
  local args={"/bin/sh","-c",'exec "$@" 2>/dev/tty',"rex-fzf",os.getenv("REX_HUNK_FZF") or "fzf",
    "--read0","--print0","--delimiter=\t","--with-nth=2..","--tiebreak=index","--layout=reverse","--border","--prompt=Filter > ","--with-shell=/bin/sh -c",
    "--header="..U.display(title).."\nSpace/Tab toggle · Enter continue · Esc cancel · Ctrl+X clear","--no-mouse",options.multiple and "--multi" or "--multi=1",
    "--bind", "space:"..toggle..",tab:"..toggle.."+down,btab:"..toggle.."+up,ctrl-space:put( ),ctrl-x:clear-multi"}
  local temporary
  local ok,result=pcall(function()
    if options.preview then
      temporary=U.trim(U.command({"mktemp","-d",U.join(os.getenv("TMPDIR") or "/tmp","rex-hunk-preview.XXXXXXXX")}))
      local filename=U.join(temporary,"feedback.txt"); U.write(filename,options.preview:gsub("[%z\1-\8\11-\31\127]",""))
      args[#args+1]="--preview"; args[#args+1]="/bin/cat "..U.quote(filename); args[#args+1]="--preview-window=right:60%:wrap"
    end
    local rows={}; for i,choice in ipairs(choices) do rows[i]=(i-1).."\t"..U.display(choice.label)..(choice.description and " — "..U.display(choice.description) or "") end
    -- Only fzf's UI goes to the terminal; its NUL-delimited result stays in Lua. No pasted shell input.
    local r=U.checked(rex.exec(args,{stdin=table.concat(rows,"\0").."\0",env={FZF_DEFAULT_OPTS="",FZF_DEFAULT_OPTS_FILE=""}}))
    if r.code==1 or r.code==130 then return nil end
    if not r.ok then error("fzf failed; no selection was applied. Install fzf or set REX_HUNK_FZF. "..r.stderr,0) end
    local picked,seen={},{}
    for _,row in ipairs(U.split(r.stdout,"\0")) do if row~="" then
      local index=tonumber(row:match("^(%d+)\t")); index=index and index+1
      if not index or not choices[index] or rows[index]~=row or seen[index] then error("The picker returned an invalid selection.",0) end
      seen[index]=true; picked[#picked+1]=choices[index].value
    end end
    if #picked==0 then error("The picker returned an empty selection.",0) end
    return picked
  end)
  if temporary then U.remove(temporary,true) end
  if not ok then error(result,0) end; return result
end
function M.input(title,initial)
  io.write(title..(initial and initial~="" and " ["..U.display(initial).."]" or "")..": "); io.flush()
  local line=io.read("*l"); if not line then return nil end
  line=U.trim(line); return line~="" and line or initial or ""
end
function M.acknowledge(message)
  print(message)
  local tty=io.open("/dev/tty","r"); if tty then tty:close(); M.input("Press Enter to close this menu") end
end
return M
