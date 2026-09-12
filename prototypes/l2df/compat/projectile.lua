-- NTSD bounded type-3 motion/scheduling projection. See PROJECTILES.md.
-- Coordinates use original convention: negative y is above ground; facing0=right.
-- Functions return new owned state. The calling pipeline decides update order.
local Input=require 'compat.actor_input'
local M={};local copy,trunc=Input.copy,Input.trunc
local function current(frames,m) return assert(frames[m.frame],'Missing projectile frame '..tostring(m.frame)) end
local function field(f,k) return f[k] or 0 end
function M.friction(v)
 if v>0.0001 then v=v-1;if v<=0.0001 then v=0 end end
 if v< -0.0001 then v=v+1;if v> -0.0001 then v=0 end end
 return v
end
function M.initial()
 -- Explicit controlled projection used by retained OriginalMelee spawn trials.
 local m={phase=0,tap=0,ix=480,iy=0,iz=490,frame=0,previousFrame=0,wait=0,
 vx=0,vy=0,vz=0,x=480,y=0,z=490,facing=0,jumpBuffer=0,rightBuffer=0,leftBuffer=0,upBuffer=0,downBuffer=0,
 cameraX=0,cameraVelocity=0,renderFrame=0,renderFacing=0,renderX=480,renderY=0,renderZ=490,
 collisionFrame=0,fall=0,freeze=0,guardDamage=0,rest=0,hp=500,redHP=500,mp=500,hitCount=0,fallHurt=0,invulnerability=0,
 damageDealt=0,damageReceived=0,kills=0,attackBuffer=0,defendBuffer=0,defendCooldown=0,superPunch=0,hitVX=0,hitVY=0,hitVZ=0,
 sounds={},vrest={},combos={0,0,0,0,0,0,0,0,0}}
 for slot=0,399 do m.vrest[slot]=0 end
 return m
end
function M.control(state,frames)
 local m=copy(state);local f=current(frames,m);local direction=m.facing==0 and 1 or -1
 local x=field(f,'dvx')
 if x>500 then m.vx=x-550 elseif x>0 then m.vx=math.max(m.vx*direction,x)*direction elseif x<0 then m.vx=math.min(m.vx*direction,x)*direction end
 local y=field(f,'dvy');if y~=0 then m.vy=y>500 and y-550 or m.vy+y end
 local z=field(f,'dvz');if z>500 then m.vz=z-550 end
 return m
end
function M.physics(state,frames)
 local m=copy(state);local f=current(frames,m)
 if m.freeze~=0 then m.freeze=m.freeze+(m.freeze>0 and -1 or 1);return m end
 m.x=m.x+m.vx;m.z=m.z+m.vz
 if field(f,'hit_j')>0 then m.z=m.z+field(f,'hit_j')-50 end
 if m.iy>=0 then m.vx=M.friction(m.vx);m.vz=M.friction(m.vz) end
 m.y=m.y+m.vy;m.ix=trunc(m.x);m.iy=trunc(m.y);m.iz=trunc(m.z)
 return m
end
function M.bounds(state,width,zmin,zmax)
 local m=copy(state);m.z=math.min(zmax+1,math.max(zmin-1,m.z));m.iz=trunc(m.z)
 return m,m.x>=-300 and m.x<=width+300
end
function M.pending(state)
 local m=copy(state);if m.freeze~=0 then return m end
 if m.hitCount~=0 then
  local divisor=m.hitCount+1;m.vx=m.hitVX*2/divisor;m.vy=m.hitVY*2/divisor;m.vz=m.hitVZ*2/divisor;m.hitCount=0
 end
 m.hitVX=0;m.hitVY=0;m.hitVZ=0;return m
end
function M.schedule(state,frames)
 local m=copy(state);local sounds={};local f=current(frames,m)
 assert(field(f,'hit_a')==0,'Type-3 draining hit_a scheduler outside retained projectile slice')
 if m.rest>0 then m.rest=m.rest-1 end
 if m.invulnerability>0 then m.invulnerability=m.invulnerability-1 end
 if m.invulnerability<0 then m.invulnerability=m.invulnerability+1 end
 for _,k in ipairs({'fall','guardDamage','superPunch'}) do if m[k]>0 then m[k]=m[k]-1 end end
 if m.frame~=m.previousFrame then if f.sound then sounds[#sounds+1]=f.sound end;m.wait=0 end
 m.wait=m.wait+1
 if m.wait>field(f,'wait') then
  m.wait=0;local nextFrame=field(f,'next')
  if nextFrame~=0 then
   if nextFrame<0 then m.facing=1-m.facing;nextFrame=-nextFrame end
   if nextFrame==999 then nextFrame=0 end
   m.frame=nextFrame;if nextFrame>=400 then return m,false,sounds end
   f=current(frames,m);if f.sound then sounds[#sounds+1]=f.sound end
  end
 end
 m.previousFrame=m.frame;return m,true,sounds
end
function M.hitReaction(state,frames,guarded)
 local m=copy(state);if field(current(frames,m),'state')==3000 then
  m.frame=10;m.wait=0;m.vx=0
  if not guarded then m.vz=field(current(frames,m),'dvy') end
 end
 return m
end
return M
