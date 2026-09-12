-- Owned, transactional, bounded two-fighter Practice composition.
-- Inputs: original DAT/header sections, declared replay RNG and input masks.
-- No expected snapshots, source memory backing or host timing enter this module.
local Input=require 'compat.actor_input'
local Fighter=require 'compat.fighter'
local Projectile=require 'compat.projectile'
local Spawn=require 'compat.spawn'
local Hits=require 'compat.projectile_hits'
local Projector=require 'compat.frame_projector'
local copy,trunc=Input.copy,Input.trunc
local World={};World.__index=World
local function slots(pool) local r={} for i in pairs(pool) do r[#r+1]=i end table.sort(r);return r end
local function append(to,values) for _,v in ipairs(values) do to[#to+1]=v end end
local function record(w,i) local a=w.pool[i];return assert(w.catalog[a.id][a.motion.frame],'Unsupported current frame '..a.motion.frame) end
local function random(w,range)
 if range<=0 then return 0 end
 local r=w.random;r.counter=(r.counter+1)%1234;r.index=(r.index+1)%3000
 return (r.table[r.index+1]+r.counter)%range
end
function World.new(config)
 assert(#config.headers==2 and #config.definitions==2,'Practice requires two fighters')
 local self=setmetatable({headers=copy(config.headers),catalog={},inputCatalog={},pool={},input={},random=copy(config.random),
  cameraX=0,cameraVelocity=0,sounds={},draws={},localPlayer=config.localPlayer or 0,events={}},World)
 assert(self.localPlayer==0 or self.localPlayer==1,'Local player outside two-fighter domain')
 assert(#self.random.table==3000 and self.random.index>=0 and self.random.index<3000 and self.random.counter>=0 and self.random.counter<1234,'Invalid declared RNG')
 for _,byte in ipairs(self.random.table) do assert(byte>0 and byte<=255 and byte==trunc(byte),'Invalid RNG byte') end
 for i=0,1 do
  local name=self.headers[i+1].name;assert(name==(i==0 and 'Naruto' or 'Sasuke'),'Practice catalog/order requires Naruto and Sasuke')
  local id=i==0 and 2 or 11;self.catalog[id]=Projector.frames(config.definitions[i+1])
  self.inputCatalog[id]=config.inputDefinitions and Projector.frames(config.inputDefinitions[i+1]) or self.catalog[id]
  local m=Projectile.initial();m.x=450+i*35;m.facing=i;m.renderFacing=i
  for k,v in pairs((config.initial or {})[i+1] or {}) do assert(m[k]~=nil,'Unknown initial projection '..k);m[k]=copy(v) end
  m.ix=trunc(m.x);m.iy=trunc(m.y);m.iz=trunc(m.z);m.renderFrame=m.frame;m.renderX=m.ix;m.renderY=m.iy;m.renderZ=m.iz
  self.pool[i]={slot=i,id=id,owner=i,team=i+1,motion=m}
  self.input[i]=Input.practice(id,m.frame,m.facing,m.hp,m.mp)
  assert(self.catalog[id][m.frame],'Unsupported initial fighter frame')
 end
 self.catalog[203]=Projector.frames(config.voiceDefinitions)
 for _,def in ipairs(config.projectileDefinitions) do
  assert((def.id==224 or def.id==440) and not self.catalog[def.id],'Unsupported or duplicate projectile catalog')
  self.catalog[def.id]=Projector.frames(def.definitions)
 end
 return self
end
local function exportMotion(m)
 local r=copy(m);r.vrest={};for slot=0,399 do r.vrest[slot+1]=m.vrest[slot] end;return r
end
function World:snapshot()
 local r={actors={exportMotion(self.pool[0].motion),exportMotion(self.pool[1].motion)},sounds=copy(self.sounds),
  randomIndex=self.random.index,randomCounter=self.random.counter,cameraX=self.cameraX,cameraVelocity=self.cameraVelocity,
  projectiles={},projectileDraws=copy(self.draws),mpSpent={self.input[0].chakraSpent,self.input[1].chakraSpent}}
 for _,i in ipairs(slots(self.pool)) do if i>=50 then local a=copy(self.pool[i]);a.motion=exportMotion(a.motion);r.projectiles[#r.projectiles+1]=a end end
 return r
end
function World:advance(masks)
 assert(#masks==2,'Two input masks required');self.sounds={};self.events={}
 local held={[0]=Fighter.buttons(masks[1]),[1]=Fighter.buttons(masks[2])}
 for i=0,1 do
  local a=self.pool[i];local events
  a.motion,self.input[i],events=Fighter.control(a.motion,self.input[i],masks[i+1],self.catalog[a.id],self.headers[i+1],function(n)return random(self,n)end,self.inputCatalog[a.id])
  for _,event in ipairs(events) do event.actor=i;self.events[#self.events+1]=event end
 end
 for _,i in ipairs(slots(self.pool)) do if i>=50 then local a=self.pool[i];a.motion=Projectile.control(a.motion,self.catalog[a.id]) end end
 for i=0,1 do local a=self.pool[i];a.motion=Fighter.physics(a.motion,self.catalog[a.id]);local m=a.motion
  m.z=math.min(525,math.max(450,m.z));m.iz=trunc(m.z);append(self.sounds,m.sounds);m.sounds={}
 end
 for _,i in ipairs(slots(self.pool)) do if i>=50 then local a=self.pool[i];a.motion=Projectile.physics(a.motion,self.catalog[a.id]) end end
 local contacts,frames;self.pool,contacts,frames=Hits.collect(self.pool,self.catalog,function(n)return random(self,n)end)
 for _,i in ipairs(slots(self.pool)) do for _,c in ipairs(contacts[i]) do
  local j=c.target
  if self.pool[j].motion.vrest[i]<=0 then
   local hit=frames[i].itrs[c.interaction];local kind=hit.kind or 0
   if kind==0 then local event
    -- Source resolve reads the attacker's live frame after preceding contacts.
    self.pool,event=Hits.resolve(self.pool,i,j,hit,record(self,i),frames[j],self.catalog)
    append(self.sounds,event.sounds);event.kind='hit';self.events[#self.events+1]=event
   elseif kind==6 then self.pool[j].motion.superPunch=3
   elseif kind==4 then assert(self.pool[i].motion.fallHurt==0,'Unsupported thrown-body damage')
   else error('Unsupported interaction kind '..kind) end
  end
 end end
 for i=0,1 do self.pool[i].motion=Fighter.bounds(self.pool[i].motion) end
 for _,i in ipairs(slots(self.pool)) do if i>=50 then local a=self.pool[i];local alive
  a.motion,alive=Projectile.bounds(a.motion,960,450,525);if not alive then self.pool[i]=nil end
 end end
 local player=self.pool[self.localPlayer].motion;local center
 if player.hp>0 then center=player.ix+(record(self,self.localPlayer).state==14 and 0 or 130-player.facing*260)
 else local sum,count=0,0;for i=0,1 do local m=self.pool[i].motion;if m.hp>0 then sum=sum+m.ix;count=count+1 end end;center=count==0 and 800 or trunc(sum/count) end
 local target=math.min(166,math.max(0,center-397))
 self.cameraVelocity=trunc((trunc((target-self.cameraX)/14)+self.cameraVelocity*6)/7)
 if self.cameraVelocity==0 and target~=self.cameraX then self.cameraVelocity=target>self.cameraX and 1 or -1 end
 self.cameraX=math.min(166,math.max(0,self.cameraX+self.cameraVelocity))
 for i=0,1 do local a=self.pool[i];local m=a.motion;m.renderFrame=m.frame;m.renderFacing=m.facing;m.renderX=m.ix;m.renderY=m.iy;m.renderZ=m.iz;a.motion=Projectile.pending(m) end
 self.draws={}
 for _,i in ipairs(slots(self.pool)) do if i>=50 then local a=self.pool[i];local m=a.motion
  self.draws[#self.draws+1]={slot=i,id=a.id,frame=m.frame,facing=m.facing,x=m.ix,y=m.iy,z=m.iz};a.motion=Projectile.pending(m)
 end end
 -- Dynamic original slot walk, including children born into later slots.
 for i=0,399 do
  local a=self.pool[i]
  if a then
   if i<2 then a.motion=Fighter.postSchedule(Fighter.schedule(a.motion,self.catalog[a.id],self.headers[i+1],masks[i+1]));append(self.sounds,a.motion.sounds);a.motion.sounds={}
   else local alive,sounds;a.motion,alive,sounds=Projectile.schedule(a.motion,self.catalog[a.id]);append(self.sounds,sounds);if not alive then self.pool[i]=nil end end
   if self.pool[i] then local born;self.pool,born=Spawn.spawn(self.pool,i,record(self,i),self.catalog,held)
    for _,slot in ipairs(born) do self.events[#self.events+1]={kind='spawn',parent=i,slot=slot,id=self.pool[slot].id} end
   end
  end
 end
end
function World:tick(masks)
 -- Keep immutable catalog/header inputs shared; all live state is owned copy.
 local nextWorld=setmetatable({catalog=self.catalog,inputCatalog=self.inputCatalog,headers=self.headers,pool=copy(self.pool),input=copy(self.input),
  random=copy(self.random),cameraX=self.cameraX,cameraVelocity=self.cameraVelocity,sounds=copy(self.sounds),
  draws=copy(self.draws),localPlayer=self.localPlayer,events=copy(self.events)},World)
 nextWorld:advance(masks)
 for k,v in pairs(nextWorld) do self[k]=v end
 return self:snapshot()
end
return World
