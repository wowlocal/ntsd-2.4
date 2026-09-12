-- Bounded owned fighter component, from retained OriginalFighter contracts.
-- Generic ActorInput is the separately compared 14,624-case implementation.
local Input=require 'compat.actor_input'
local Projectile=require 'compat.projectile'
local copy,trunc=Input.copy,Input.trunc
local M={}
local bits={up=128,down=64,left=32,right=16,attack=8,jump=4,defend=2}
function M.buttons(mask) local r={} for k,v in pairs(bits) do r[k]=math.floor(mask/v)%2==1 end return r end
local function current(m,frames) return assert(frames[m.frame],'Unsupported fighter frame '..m.frame) end
local function fs(m,frames) return current(m,frames).state or 0 end
local function sound(m,frames) local s=current(m,frames).sound;if s then m.sounds[#m.sounds+1]=s end end
local function walk(m,p) local rate=tonumber(p.walking_frame_rate);m.phase=(m.phase+1)%(rate*6);m.frame=m.phase<rate*4 and trunc(m.phase/rate)+5 or 11-trunc(m.phase/rate) end
function M.control(state,inputState,mask,frames,p,random)
 local m,a=copy(state),copy(inputState);local held=M.buttons(mask);local prev=copy(a.previous)
 m.sounds={};a.frame=m.frame;a.facing=m.facing;a.hp=m.hp;a.mp=m.mp
 for k in pairs(bits) do a.current[k]=held[k] and 1 or 0;a.buffers[k]=m[k..'Buffer']%256 end
 a.buffers.defendCooldown=m.defendCooldown%256;a.progress=copy(m.combos)
 local oldCost=a.healthSpent;local events;a,events=Input.apply(a,frames,{costEnabled=true,flag458428=0})
 m.frame=a.frame;m.facing=a.facing;m.hp=a.hp;m.mp=a.mp;m.damageReceived=m.damageReceived+(a.healthSpent-oldCost)
 for k in pairs(bits) do local v=a.buffers[k];m[k..'Buffer']=v>=128 and v-256 or v end
 m.defendCooldown=a.buffers.defendCooldown;m.combos=copy(a.progress)
 local right,left,up,down,jump=held.right,held.left,held.up,held.down,held.jump
 local rightOnly,leftOnly=right and not left,left and not right
 local upOnly,downOnly=up and not down,down and not up
 local function param(k) return assert(tonumber(p[k]),'Missing movement parameter '..k) end
 if m.frame==110 then if right then m.facing=0 end;if left then m.facing=1 end end
 if fs(m,frames)==0 or fs(m,frames)==1 then
  if m.tap>0 then m.tap=m.tap-1 end;if m.tap<0 then m.tap=m.tap+1 end
  if rightOnly and m.iy==0 then
   if m.facing==1 then m.tap=0 end;m.facing=0;walk(m,p);m.vx=param('walking_speed')
   if prev.right==0 then m.tap=m.tap+10 end;if m.tap>=11 then m.frame=9;m.phase=0;m.tap=0 end
  end
  if leftOnly and m.iy==0 then
   if m.facing==0 then m.tap=0 end;m.facing=1;walk(m,p);m.vx=-param('walking_speed')
   if prev.left==0 then m.tap=m.tap-10 end;if m.tap<=-11 then m.frame=9;m.phase=0;m.tap=0 end
  end
  if (upOnly or downOnly) and m.iy==0 then
   if right==left then walk(m,p) end;m.vz=param('walking_speedz')*(upOnly and -1 or 1);m.vx=m.vx/1.4
  end
  if held.attack and m.attackBuffer>0 then m.tap=0;m.wait=0;m.frame=m.superPunch>0 and 70 or 60+5*random(2) end
  if jump and m.jumpBuffer>0 then m.tap=0;m.wait=0;m.frame=210 end
  if held.defend and m.defendCooldown==0 and m.defendBuffer>0 then m.tap=0;m.wait=0;m.frame=110 end
 end
 if fs(m,frames)==4 and m.iy<0 then
  if rightOnly then m.facing=0 end;if leftOnly then m.facing=1 end
  assert(not held.attack,'Unsupported jump attack')
 end
 if fs(m,frames)==2 then
  m.wait=0;local rate=param('running_frame_rate');m.phase=(m.phase+1)%(rate*4)
  m.frame=m.phase<rate*3 and trunc(m.phase/rate)+9 or 10;m.vx=param('running_speed')*(m.facing==0 and 1 or -1)
  if (m.facing==0 and left) or (m.facing==1 and right) then m.frame=218 end
  if (upOnly or downOnly) and m.iy==0 then m.vz=param('running_speedz')*(upOnly and -1 or 1);m.vx=m.vx/1.2 end
  if held.attack and m.attackBuffer>0 then m.frame=85 end
  assert(not (held.defend and m.defendBuffer>0),'Unsupported running defense')
  if jump and m.jumpBuffer>0 then
   m.sounds[#m.sounds+1]='builtin:7';m.tap=0;m.frame=213;m.vx=param('dash_distance')*(m.facing==0 and 1 or -1);m.vy=param('dash_height')
   if upOnly or downOnly then m.vz=param('dash_distancez')*(upOnly and -1 or 1) end
  end
 end
 if m.frame==215 then
  if jump and (right or m.vx>=0.001) and m.jumpBuffer>0 then m.sounds[#m.sounds+1]='builtin:7';m.frame=213+m.facing;m.tap=0;m.vx=param('dash_distance');m.vy=param('dash_height') end
  if jump and (left or m.vx< -0.001) and m.jumpBuffer>0 then m.sounds[#m.sounds+1]='builtin:7';m.frame=214-m.facing;m.tap=0;m.vx=-param('dash_distance');m.vy=param('dash_height') end
  if upOnly or downOnly then m.vz=param('dash_distancez')*(upOnly and -1 or 1) end
 end
 assert(not ((m.frame==182 or m.frame==188) and m.fallHurt>=0 and jump and m.jumpBuffer>0 and m.hp>0),'Unsupported fall recovery roll')
 if fs(m,frames)==5 then
  if rightOnly then m.facing=0 end
  if m.facing==0 then if m.frame~=217 and m.vx<0 then m.frame=214 end;if m.frame~=216 and m.vx>0 then m.frame=213 end end
  if leftOnly then m.facing=1 end
  if m.facing==1 then if m.frame~=217 and m.vx>0 then m.frame=214 end;if m.frame~=216 and m.vx<0 then m.frame=213 end end
  assert(not (held.attack and ((m.facing==0 and m.vx>=0) or (m.facing==1 and m.vx<0))),'Unsupported dash attack')
 end
 m=Projectile.control(m,frames)
 local z=current(m,frames).dvz or 0
 if z<=500 and z~=0 then if up and m.upBuffer>=m.downBuffer then m.vz=-z end;if down and m.upBuffer<=m.downBuffer then m.vz=z end end
 a.previous=copy(a.current)
 return m,a,events
end
function M.physics(state,frames)
 local m=copy(state)
 if m.freeze~=0 then m.freeze=m.freeze+(m.freeze>0 and -1 or 1);return m end
 m.x=m.x+m.vx;m.z=m.z+m.vz
 if m.iy>=0 then m.vx=Projectile.friction(m.vx);m.vz=Projectile.friction(m.vz) end
 m.y=m.y+m.vy
 if m.y< -0.0001 then
  m.vy=m.vy+1.7
  if fs(m,frames)==12 then local phase=m.vy< -8 and 0 or m.vy<1 and 1 or m.vy<8 and 2 or 3
   if m.frame<185 then m.frame=180+phase elseif m.frame>=186 and m.frame<191 then m.frame=186+phase end
  end
 elseif fs(m,frames)==12 and m.y>0 and m.vy>0 then
  m.sounds[#m.sounds+1]='builtin:6'
  if m.fallHurt~=0 then m.hp=m.hp-math.abs(m.fallHurt);m.redHP=m.redHP-math.abs(m.fallHurt);m.fallHurt=0 end
  m.y=0
  if m.vy<=11 and m.vx<=9 and m.vx>=-9 then m.vy=0;m.vx=m.vx/3;m.wait=0;m.frame=m.frame>=186 and 231 or 230
  else m.vy=-3.5;m.vx=math.min(7,math.max(-7,m.vx));m.frame=m.frame>=186 and 191 or 185 end
 elseif (m.y>0 and m.vy>0) or (m.frame==212 and m.vy==0) then
  m.y=0;m.vy=0;m.vx=m.vx/3;m.frame=(m.frame==212 or fs(m,frames)==6) and 215 or 219;m.wait=0
 end
 m.ix=trunc(m.x);m.iy=trunc(m.y);m.iz=trunc(m.z);return m
end
function M.bounds(state) local m=copy(state);m.z=math.min(525,math.max(450,m.z));m.iz=trunc(m.z);m.x=math.min(960,math.max(0,m.x));m.ix=trunc(m.x);return m end
function M.schedule(state,frames,p,mask)
 local m=copy(state);if m.freeze~=0 then return m end
 local held=M.buttons(mask)
 if m.rest>0 then m.rest=m.rest-1 end
 if m.invulnerability>0 then m.invulnerability=m.invulnerability-1 end;if m.invulnerability<0 then m.invulnerability=m.invulnerability+1 end
 for _,k in ipairs({'fall','guardDamage','superPunch'}) do if m[k]>0 then m[k]=m[k]-1 end end
 if m.frame~=m.previousFrame then sound(m,frames);m.wait=0 end;m.wait=m.wait+1
 if fs(m,frames)==0 and m.iy<0 then m.frame=212 end
 if fs(m,frames)==14 and m.hp<=0 then m.wait=0 end
 if m.wait>(current(m,frames).wait or 0) then
  m.wait=0;local nextFrame=current(m,frames).next or 0
  if nextFrame~=0 then
   if nextFrame<0 then m.facing=1-m.facing;nextFrame=-nextFrame end
   local airReturn=nextFrame==999 and m.iy~=0
   if nextFrame==999 then nextFrame=airReturn and 212 or 0 end
   assert(frames[nextFrame],'Unsupported fighter schedule frame '..nextFrame);m.frame=nextFrame
   if frames[m.previousFrame] and frames[m.previousFrame].state==14 and fs(m,frames)~=13 then m.invulnerability=15 end
   if m.frame==212 and not airReturn then
    m.vy=tonumber(p.jump_height)
    if held.right and not held.left then m.vx=tonumber(p.jump_distance) end
    if held.left and not held.right then m.vx=-tonumber(p.jump_distance) end
    if held.up and not held.down then m.vz=-tonumber(p.jump_distancez) end
    if held.down and not held.up then m.vz=tonumber(p.jump_distancez) end
   end
   sound(m,frames)
  end
 end
 if m.frame==110 or m.frame==114 then m.defendCooldown=3 end;m.previousFrame=m.frame;return m
end
function M.postSchedule(state)
 local m=copy(state)
 local dead=m.hp<=0 and (m.frame<12 or m.frame==110 or m.frame==111)
 local stuck=m.iy==0 and m.y==0 and m.vy==0 and m.hitVY==0 and ((m.frame>=180 and m.frame<=189 and m.frame~=184) or (m.frame>=212 and m.frame<=214))
 if dead or stuck then m.frame=186;m.vy=-3;m.hitVY=-3;m.y=-1;m.iy=-1 end;return m
end
return M
