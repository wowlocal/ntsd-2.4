-- NTSD post-schedule kind1 Opoint projection, retained OriginalMelee.spawn.
-- Pool owns actors at zero-based original slots; newly allocated states never
-- use L2DF object counters or source fixture after-state for identity/backing.
local Input=require 'compat.actor_input'
local Projectile=require 'compat.projectile'
local copy,trunc=Input.copy,Input.trunc
local M={}
function M.spawn(pool,parentSlot,frame,catalog,heldInputs)
 local result=copy(pool);local parent=assert(result[parentSlot],'Absent spawn parent');local pm=parent.motion
 local op=frame.opoint or {};local born={}
 if (op.kind or 0)<=0 or pm.wait~=0 or (pm.freeze~=0 and parentSlot<50) then return result,born end
 local id,action,facing=op.oid or 0,op.action or 0,op.facing or 0
 local definitions=assert(catalog[id],'Unsupported spawned object '..id)
 local child=assert(definitions[action],'Unsupported spawned frame '..action)
 assert(op.kind==1 and (facing==0 or facing==1 or facing==50),'Opoint outside retained kind1/facing0,1,50 projection')
 local count=facing>10 and trunc(facing/10) or 1;local orientation=facing>10 and facing%10 or facing
 local owner=parentSlot<2 and parentSlot or parent.owner;local team=parentSlot<2 and parentSlot+1 or parent.team
 local input=heldInputs[parentSlot<2 and parentSlot or owner] or {}
 for n=0,count-1 do
  local slot;for k=50,399 do if not result[k] then slot=k;break end end
  if slot then
   local m=Projectile.initial();m.frame=action
   m.ix=pm.ix+(pm.facing==0 and ((op.x or 0)-(frame.centerx or 0)) or ((frame.centerx or 0)-(op.x or 0)))
   m.iy=pm.iy-(frame.centery or 0)+(op.y or 0);m.x=m.ix;m.y=m.iy;m.z=pm.z+1;m.iz=trunc(m.z)
   m.facing=orientation==0 and pm.facing or 1-pm.facing
   m.vx=(op.dvx or 0)*(1-m.facing*2);m.vy=op.dvy or 0;m.vz=0
   m.hitVX=0.1;m.hitVY=0.1;m.hitVZ=0.1
   if (child.state==3000 or child.state==1002 or child.state==3006) and id~=223 and id~=224 then
    if input.up and not input.down then m.vz=-2.5 end
    if input.down and not input.up then m.vz=2.5 end
   end
   if count>1 then
    local spread=n*10/(count-1)-5;m.vz=m.vz+spread
    if (m.vx<0 and spread>0) or (m.vx>0 and spread<0) then m.vx=m.vx-spread else m.vx=m.vx+spread end
   end
   for _,actor in pairs(result) do actor.motion.vrest[slot]=0 end
   result[slot]={slot=slot,id=id,owner=owner,team=team,motion=m};born[#born+1]=slot
  end
 end
 if #born>1 then
  local middle=trunc(#born/2)
  for i,slot in ipairs(born) do local n=i-1;local m=result[slot].motion
   m.rest=n<middle and (middle-n-(#born%2==0 and 1 or 0))*2 or (n-middle)*2
   for _,other in ipairs(born) do if other~=slot then m.vrest[other]=40 end end
  end
 end
 return result,born
end
return M
