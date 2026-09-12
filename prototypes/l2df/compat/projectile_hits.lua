-- Retained PROJECTILES normal kind0/effect0,1 contact and reaction domain.
-- Source order: 419380/4171c0 pairs ->42e100 normal/guard ->4196f0 pending.
local Input=require 'compat.actor_input'
local Projectile=require 'compat.projectile'
local copy,trunc,i32=Input.copy,Input.trunc,Input.i32
local M={}
local function slots(pool) local r={} for slot in pairs(pool) do r[#r+1]=slot end table.sort(r);return r end
local function record(catalog,a) return assert(catalog[a.id][a.motion.frame],'Missing contact frame') end
local function rect(box,m,f)
 local x,w=box.x or 0,box.w or 0;local center=f.centerx or 0
 return {x=m.ix+(m.facing==0 and x-center or center-x-w),y=m.iy+(box.y or 0)-(f.centery or 0),w=w,h=box.h or 0}
end
local function overlaps(a,b) return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h end
function M.collect(pool,catalog,random)
 local p=copy(pool);local active=slots(p);local frames,contacts,nearest={},{},{}
 for _,i in ipairs(active) do local a=p[i];frames[i]=record(catalog,a);a.motion.collisionFrame=a.motion.frame
  if #(frames[i].itrs or {})==0 then a.motion.rest=0 end;contacts[i]={};nearest[i]=1000
 end
 for pos,first in ipairs(active) do for n=pos+1,#active do local second=active[n]
  for _,pair in ipairs({{first,second},{second,first}}) do local a,b=pair[1],pair[2];local v=p[a].motion.vrest[b];if v>0 then p[a].motion.vrest[b]=v-1 end end
  for _,pair in ipairs({{first,second},{second,first}}) do
   local i,j=pair[1],pair[2];local a,b=p[i].motion,p[j].motion;local af,bf=frames[i],frames[j]
   if a.rest<=0 and b.vrest[i]<=0 and b.invulnerability==0 and #(bf.bodies or {})>0 then
    for index,itr in ipairs(af.itrs or {}) do
     local depth=(itr.zwidth or 0)==0 and 15 or itr.zwidth
     if math.abs(a.iz-b.iz)<depth and not (bf.state==12 and (itr.fall or 0)<=40) and itr.kind~=2 and p[i].team~=p[j].team then
      for _,body in ipairs(bf.bodies) do if overlaps(rect(itr,a,af),rect(body,b,bf)) then
       if (itr.vrest or 0)==0 then
        local distance=math.abs(a.ix-b.ix)
        if distance<nearest[i] or (distance==nearest[i] and assert(random,'A declared original RNG is required for contact ties')(2)==0) then nearest[i]=distance;contacts[i]={{target=j,interaction=index}} end
       elseif #contacts[i]<20 then contacts[i][#contacts[i]+1]={target=j,interaction=index} end
      end end
     end
    end
   end
  end
 end end
 return p,contacts,frames
end
function M.resolve(pool,i,j,hit,attackerFrame,targetFrame,catalog)
 local p=copy(pool);local a,b=p[i].motion,p[j].motion;local sounds={}
 assert(j<2 and (hit.kind or 0)==0 and ((hit.effect or 0)==0 or hit.effect==1),'Hit outside retained projectile/fighter normal domain')
 local injury,fall=hit.injury or 0,hit.fall or 0;local dvx,dvy=hit.dvx or 0,hit.dvy or 0
 local arest,vrest,bdef=hit.arest or 0,hit.vrest or 0,hit.bdefend or 0
 local blocked=targetFrame.state==7 and bdef<=60 and b.hp>0 and (a.facing~=b.facing or dvx<0)
 local damage=blocked and trunc(injury/10) or injury;local killed=b.hp>0 and damage>=b.hp
 if i<2 and killed then a.kills=i32(a.kills+1) end
 b.hp=i32(b.hp-damage);b.redHP=i32(b.redHP-trunc(damage/3));b.damageReceived=i32(b.damageReceived+damage)
 if i<2 then a.damageDealt=i32(a.damageDealt+damage) end
 b.hitCount=i32(b.hitCount+1);local direction=1-a.facing*2
 if blocked then
  if i<2 then sounds[#sounds+1]='builtin:1' end
  if i>=50 and attackerFrame.state==3000 then a=Projectile.hitReaction(a,catalog[p[i].id],true) end
  if b.hp<=0 then b.fall=80 end
  b.wait=0;b.guardDamage=i32(b.guardDamage+bdef);a.freeze=3;b.freeze=-5
  if b.iy==0 then
   if b.guardDamage>30 then b.frame=112 elseif b.frame==110 then b.frame=111 end
   b.hitVX=b.hitVX+direction*((b.fall==80 and math.abs(b.vx)<3 and dvx==0) and 3 or trunc(dvx/2))
  else b.hitVX=b.hitVX+direction*((b.fall==80 and math.abs(b.vx)<6 and dvx<6) and 6 or dvx) end
  a.rest=arest<4 and vrest==0 and 4 or math.min(arest,12)
  if vrest>0 then b.vrest[i]=math.min(12,math.max(4,vrest)) end
 else
  b.guardDamage=45;if b.hp<=0 then b.fall=80 end;b.fall=b.fall+(fall==0 and 20 or fall)
  if targetFrame.state==12 then b.fall=80 end
  if b.fall>60 then b.fall=80
  elseif b.fall>40 then b.frame=226;b.fall=b.iy<0 and 80 or 60
  elseif b.fall>20 then b.frame=222+(a.facing==b.facing and 2 or 0);b.fall=b.iy<0 and 80 or 40
  elseif b.fall>0 then b.frame=b.iy<0 and 222+(a.facing==b.facing and 2 or 0) or 220;b.fall=20 end
  if i>=50 and attackerFrame.state==3000 then a=Projectile.hitReaction(a,catalog[p[i].id],false) end
  if hit.effect==1 then sounds[#sounds+1]=b.fall==80 and 'builtin:12' or 'builtin:11' end
  sounds[#sounds+1]=b.fall==80 and 'builtin:2' or 'builtin:0'
  b.hitVX=b.hitVX+direction*((b.fall==80 and math.abs(b.vx)<5 and dvx==0) and 5 or dvx)
  if b.fall==80 then
   b.hitVY=b.hitVY+(dvy==0 and -7 or dvy)
   if dvy~=0 and trunc(b.iy+b.hitVY)>0 then b.hitVY=12 end
   b.frame=((b.facing==0 and b.hitVX<=0) or (b.facing==1 and b.hitVX>0)) and 180 or 186;b.fall=0
  end
  if a.freeze>=0 then a.freeze=3 end;b.freeze=-3
  a.rest=arest<4 and vrest==0 and 4 or arest;if vrest>0 then b.vrest[i]=vrest end
 end
 p[i].motion=a;p[j].motion=b
 if i>=50 then local owner=p[assert(p[i].owner,'Missing projectile owner')].motion;owner.damageDealt=i32(owner.damageDealt+damage);if killed then owner.kills=i32(owner.kills+1) end end
 return p,{guarded=blocked,damage=damage,killed=killed,attacker=i,target=j,sounds=sounds}
end
M.rectangle=rect;M.overlaps=overlaps
return M
