-- Owned numeric projection of NTSD 413080..4132ef, 40e170/40e2d0/40e450.
-- Source contract: docs/research/ACTOR_INPUT.md and retained OriginalActorInput.
-- No expected after-state, memory addresses, host clock or candidate RNG input.
local M={}
local function copy(v) if type(v)~='table' then return v end local r={} for k,x in pairs(v) do r[k]=copy(x) end return r end
local function i32(x) x=x%4294967296;return x>=2147483648 and x-4294967296 or x end
local function signed(x) return x>=128 and x-256 or x end
local function trunc(x) return x<0 and math.ceil(x) or math.floor(x) end
local buffers={'attack','jump','defend','left','up','down','right'}
local edges={{'right',6},{'left',4},{'up',8},{'down',2},{'defend',9},{'jump',0},{'attack',5}}
local keyNames={U='up',D='down',L='left',R='right',d='defend',j='jump',a='attack'}
local routes={
 {'right','R','attack','a','hit_Fa',0},{'left','L','attack','a','hit_Fa',1},
 {'up','U','attack','a','hit_Ua'},{'down','D','attack','a','hit_Da'},
 {'right','R','jump','j','hit_Fj',0},{'left','L','jump','j','hit_Fj',1},
 {'up','U','jump','j','hit_Uj'},{'down','D','jump','j','hit_Dj'},
 {'jump','j','attack','a','hit_ja'}
}
local function frame(frames,id)
 assert(id>=0 and id<400 and id==math.floor(id),'Actor input frame outside Object: '..tostring(id))
 return frames[id] or {present=false}
end
local function capture(a)
 for _,k in ipairs({'right','left','up','down','jump','attack','defend','defendCooldown'}) do
  local v=assert(a.buffers[k],k);if signed(v)>0 then a.buffers[k]=(v-1)%256 end
 end
 for _,edge in ipairs(edges) do local k=edge[1]
  if a.previous[k]==0 and a.current[k]==1 then
   a.buffers[k]=5;for n=1,4 do a.history[n]=a.history[n+1] end;a.history[5]=edge[2]
  end
 end
end
function M.invalidates(a,key,advanced)
 if type(key)=='number' then key=string.char(key%256) end
 local excluded
 if advanced==1 then excluded=keyNames[key];if not excluded then return false end
 elseif advanced~=0 then return false end
 for _,k in ipairs(buffers) do if k~=excluded and a.buffers[k]==5 then return true end end
 return false
end
local function transfer(a,target,frames,g,events)
 local destination=target<0 and i32(-target) or target
 if destination==999 then destination=0 end
 local f=frame(frames,destination)
 if f.present==false or f.present==0 then events[#events+1]={kind='absent',target=destination};return false end
 if g.costEnabled~=false and g.costEnabled~=0 then
  local cost=f.mp or 0;local hpCost=i32(trunc(cost/1000)*10);local mpCost=cost-trunc(cost/1000)*1000
  if a.mp<mpCost then events[#events+1]={kind='insufficientMP',target=destination};return false end
  if a.hp<=hpCost then events[#events+1]={kind='insufficientHP',target=destination};return false end
  a.hp=i32(a.hp-hpCost);a.mp=i32(a.mp-mpCost)
  a.healthSpent=i32(a.healthSpent+hpCost);a.chakraSpent=i32(a.chakraSpent+mpCost)
  a.frame=destination;if target<0 then a.facing=(1-a.facing)%256 end
 else a.frame=destination end
 for _,k in ipairs(buffers) do a.buffers[k]=0 end
 events[#events+1]={kind='transfer',target=destination}
 return true
end
local function recognize(a,frames,g,events)
 for n,r in ipairs(routes) do
  local advanced=0
  if a.progress[n]==0 and a.buffers.defend==5 then a.progress[n]=1;advanced=1 end
  if a.progress[n]==1 then
   if a.buffers[r[1]]==5 then a.progress[n]=2;advanced=1
   elseif M.invalidates(a,'d',advanced) then a.progress[n]=0 end
  end
  if a.progress[n]==2 then
   if a.buffers[r[3]]==5 then a.progress[n]=3;advanced=1
   elseif M.invalidates(a,r[2],advanced) then a.progress[n]=0 end
  end
  if a.progress[n]==3 then
   local target=frame(frames,a.frame)[r[5]] or 0
   if n==9 and a.sourceID==6 and target==300 and a.hp>177 and g.flag458428==0 then
    -- Source-ID6 exception leaves stage3 intact, before transfer/invalidation.
   elseif target~=0 and (n~=9 or a.field324==-1) and a.status98~=2 then
    transfer(a,target,frames,g,events)
    if r[6]~=nil then a.facing=r[6] end
    a.progress[n]=0
   elseif n==9 and a.field328==1 then a.field338=0
   elseif M.invalidates(a,r[4],advanced) then a.progress[n]=0 end
  end
 end
end
local function frameInput(a,frames,g,events)
 local f=frame(frames,a.frame)
 for _,r in ipairs({{'hit_a','attack','defend','jump'},{'hit_d','defend','attack','jump'},{'hit_j','jump','attack','defend'}}) do
  local target=f[r[1]] or 0;local v=signed(a.buffers[r[2]])
  if target~=0 and v>signed(a.buffers[r[3]]) and v>signed(a.buffers[r[4]]) then
   transfer(a,target,frames,g,events);a.buffers[r[2]]=0;return
  end
 end
end
function M.captureEdges(actor) local a=copy(actor);capture(a);return a end
function M.transfer(actor,target,frames,globals) local a,e=copy(actor),{};transfer(a,target,frames,globals,e);return a,e end
function M.recognizeCombos(actor,frames,globals) local a,e=copy(actor),{};recognize(a,frames,globals,e);return a,e end
function M.applyFrameInput(actor,frames,globals) local a,e=copy(actor),{};frameInput(a,frames,globals,e);return a,e end
function M.apply(actor,frames,globals)
 local a,e=copy(actor),{};capture(a);recognize(a,frames,globals,e);frameInput(a,frames,globals,e);return a,e
end
-- Explicit controlled practice initialization; not an import of raw Actor storage.
function M.practice(sourceID,frameID,facing,hp,mp)
 local a={sourceID=sourceID,frame=frameID,facing=facing,hp=hp,mp=mp,healthSpent=0,chakraSpent=0,status98=0,field324=-1,field328=0,field338=0,buffers={},previous={},current={},history={0,0,0,0,0},progress={0,0,0,0,0,0,0,0,0}}
 for _,k in ipairs(buffers) do a.buffers[k]=0;a.previous[k]=0;a.current[k]=0 end;a.buffers.defendCooldown=0
 return a
end
M.copy=copy;M.i32=i32;M.trunc=trunc
return M
