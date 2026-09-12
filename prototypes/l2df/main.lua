-- Candidate feasibility scene. L2DF remains the simulation engine.
-- NTSD DAT/BMP/WAV are unchanged inputs; candidate mechanics are not NTSD evidence.
local counts = {audioCalls=0, audioPlaying=0, damageEvents=0, spawned=0, missingOpoint=0, keyboardCallbacks=0}
local nativeAudioPlay=love.audio.play
love.audio.play=function(sources,...)
 local list=type(sources)=='table' and sources or {sources}
 counts.audioCalls=counts.audioCalls+#list
 local result=nativeAudioPlay(sources,...)
 for _,source in ipairs(list) do if source:isPlaying() then counts.audioPlaying=counts.audioPlaying+1 end end
 return result
end
l2df = require 'l2df'
data = { FPS = 60, players = {'Naruto','Sasuke'}, lf2_objects = {}, isplaying = true }
helper = l2df.import 'helper'
local catalog = require 'catalog'
local Parser = l2df.import 'class.parser.lffs2'
local Converter = require 'tools.lf2dat'
local Factory = l2df.import 'manager.factory'
local SceneManager = l2df.import 'manager.scene'
local Scene = l2df.import 'class.entity.scene'
local States = l2df.import 'manager.states'
local Kinds = l2df.import 'manager.kinds'
local Renderer = l2df.import 'manager.render'
local Resources = l2df.import 'manager.resource'
local Input = l2df.import 'manager.input'
local Controller = l2df.import 'class.component.controller'
local Sound = l2df.import 'class.component.sound'
local Storage = l2df.import 'class.storage'
local Sync = l2df.import 'manager.sync'
local Attributes, objects, room, world, objectAPI
local tick, smoke, paused, elapsed, screenshots = 0, false, false, 0, {}
local logdir = os.getenv('NTSD_L2DF_LOG_DIR')
local trace, events
local bgimages, imagecache = {}, {}
local minhp = {500,500}
local screenshotRequested=false
local seen, olddynamic, held = {{},{}}, {}, {}
local mappings = {
 {up='w',down='s',left='a',right='d',attack='f',jump='g',defend='h'},
 {up='up',down='down',left='left',right='right',attack='j',jump='k',defend='l'}
}
local function output(name, text)
 if logdir then local f=assert(io.open(logdir..'/'..name,'wb'));f:write(text);f:close() end
end
local function event(s)
 print('PROTOTYPE '..s)
 if events then events:write(tick..' '..s..'\n');events:flush() end
end
function data.random(a,b) if not b then a,b=1,a end return math.random(a,b) end
local function pngImage(path, key)
 local id=path..(key and '#black-key' or '#opaque')
 if imagecache[id] then return imagecache[id] end
 local pixels=love.image.newImageData(path)
 if key then pixels:mapPixel(function(x,y,r,g,b,a) if r==0 and g==0 and b==0 then return r,g,b,0 end return r,g,b,a end) end
 local img=love.graphics.newImage(pixels);img:setFilter('nearest','nearest');imagecache[id]=img
 return img
end
local function loadObject(entry)
 local raw=assert(love.filesystem.read(entry.file))
 local decoded=Converter.decrypt(raw)
 assert(love.data.encode('string','hex',love.data.hash('sha256',decoded))==entry.decodedSHA256,'DAT decoder differs from prepared input')
 local text=Converter.convert_text(decoded,{type=entry.type})
 local parsed=assert(Parser:parse(text))
 parsed._lf2,parsed._lf2_type,parsed.lf2id=true,entry.type,entry.id
 local count,unique=0,{};for _,f in ipairs(parsed.frames or {}) do count=count+1;unique[f[1]]=true end
 local n=0;for _ in pairs(unique) do n=n+1 end
 event(('import id=%d definitions=%d unique=%d sourceMarkers=%d'):format(entry.id,count,n,entry.frameMarkers))
 assert(count==entry.frameMarkers,'candidate dropped/nested source frames')
 for _,s in ipairs(parsed.sprites or {}) do Resources:addById(s[1],pngImage(s[1],true)) end
 if parsed.small then Resources:addById(parsed.small,pngImage(parsed.small,true)) end
 data.objectdata:addById(parsed,entry.id,true)
 return parsed
end
local function reset()
 if world then room:detach(world);objectAPI.clearDynamic();world:destroy() end
 data.lf2_objects={};olddynamic={};objects={};math.randomseed(12564)
 world=Factory:create('map',{active=true,width=960,height=600,depth=600,layer='GAME',gravity=24.9,ground_friction=0.96,borders={x1=0,x2=960,y1=0,z1=450,z2=525}})
 room:attach(world)
 for i,id in ipairs({2,11}) do
  local def=data.objectdata:getById(id)
  local obj=Factory:create('object',def)
  obj.data.index,obj.data.player,obj.data.team=i,i,i
  obj.data.syncid='player:'..i
  obj.data.x,obj.data.y,obj.data.z,obj.data.facing= i==1 and 410 or 475,0,490,i==1 and 1 or -1
  obj:addComponent(Controller,i);obj:addComponent(Attributes,def);obj:addComponent(Sound,def)
  world:attach(obj);objects[i]=obj
 end
 Input:reset(0);Input.delay=0
 paused=false;event('reset controlled_spawn=410,475 z=490 candidate_rng_seed=12564')
end
local function desiredKeys(t)
 local k={}
 -- Deterministic callback stimulus. These are not OS or physical-key events.
 if t>=20 and t<30 then k.a=true end
 if t>=35 and t<45 then k.d=true end
 if t==65 or t==100 or t==140 then k.f=true end
 if t>=185 and t<193 then k.right=true end
 if t>=200 and t<208 then k.left=true end
 if t==235 then k.k=true end
 if t==330 then k.l=true;k.left=true;k.j=true end
 if t==430 or t==470 then k.j=true end
 return k
end
local function inject()
 local want=desiredKeys(tick)
 for k in pairs(held) do if not want[k] then love.keyreleased(k,k);held[k]=nil end end
 for k in pairs(want) do if not held[k] then love.keypressed(k,k,false);held[k]=true end end
end
local function observe()
 for i,o in ipairs(objects) do
  local d,a=o.data,o.C.attr.data();seen[i][d.frame.id or -1]=true
  if a.hp<minhp[i] then counts.damageEvents=counts.damageEvents+1;event(('damage player=%d hp=%.3f frame=%s'):format(i,a.hp,tostring(d.frame.id)));minhp[i]=a.hp end
  if trace then trace:write(('%d,%d,%.9f,%.9f,%.9f,%s,%.6f,%.6f,%d\n'):format(tick,i,d.x,d.y,d.z,tostring(d.frame.id),a.hp,a.mp,d.facing)) end
 end
 for _,o in ipairs(data.lf2_objects) do if not olddynamic[o] then olddynamic[o]=true;counts.spawned=counts.spawned+1;if o.data.lf2id==440 or o.data.lf2id==224 then counts.projectiles=(counts.projectiles or 0)+1 end;event('spawn id='..tostring(o.data.lf2id)..' frame='..tostring(o.data.frame.id)) end end
end
local function drawBackground()
 love.graphics.push();love.graphics.scale(love.graphics.getWidth()/960,love.graphics.getHeight()/600)
 love.graphics.clear(0.08,0.10,0.14,1);love.graphics.setColor(1,1,1,1)
 for i,l in ipairs(catalog.district.layers) do
  local phase=l.cc and math.floor(tick/2)%l.cc
  if not phase or (phase>=l.c1 and phase<=l.c2) then love.graphics.draw(bgimages[i],l.x,l.y) end
 end
 love.graphics.pop()
end
local function drawHUD()
 local g=love.graphics;g.push();g.origin();g.scale(g.getWidth()/960,g.getHeight()/600)
 g.setColor(.04,.06,.10,1);g.rectangle('fill',0,0,960,100)
 for i,o in ipairs(objects) do
  local x=i==1 and 24 or 520;local a=o.C.attr.data()
  g.setColor(1,1,1,1);g.print(i==1 and 'NARUTO / P1' or 'SASUKE / P2',x,12)
  g.setColor(.20,.24,.30,1);g.rectangle('fill',x,37,390,10)
  g.setColor(i==1 and .96 or .42,i==1 and .50 or .62,i==1 and .17 or 1,1);g.rectangle('fill',x,37,390*a.hp/500,10)
  g.setColor(.3,.7,1,1);g.rectangle('fill',x,53,390*a.mp/1000,5)
  g.setColor(.8,.85,.9,1);g.print(('HP %.0f  CHAKRA %.0f'):format(a.hp,a.mp),x,68)
 end
 g.setColor(.04,.06,.10,.94);g.rectangle('fill',0,553,960,47)
 g.setColor(.88,.91,.95,1);g.print('P1 WASD · F attack · G jump · H defend     P2 arrows · J attack · K jump · L defend',14,560)
 g.setColor(.65,.74,.83,1);g.print('Sasuke needles: J + L + facing direction together.    R restart · M mute · Esc pause · Q quit',14,580)
 g.setColor(.95,.85,.5,1);g.print('L2DF experimental rules | District | native macOS',310,109)
 if paused then g.setColor(0,0,0,.7);g.rectangle('fill',310,235,340,85);g.setColor(1,1,1,1);g.printf('PAUSED — Esc to resume',310,270,340,'center') end
 local a,b=objects[1].C.attr.data(),objects[2].C.attr.data()
 if a.hp<=0 or b.hp<=0 then g.setColor(1,.9,.5,1);g.printf((a.hp<=0 and 'SASUKE' or 'NARUTO')..' WINS — R to restart',260,220,440,'center') end
 g.pop()
end
function love.keypressed(key)
 counts.keyboardCallbacks=counts.keyboardCallbacks+1
 if key=='f12' then screenshotRequested=true elseif key=='q' then love.event.quit() elseif key=='escape' then paused=not paused elseif key=='r' then reset() elseif key=='m' then love.audio.setVolume(love.audio.getVolume()>0 and 0 or .7) end
end
function love.focus(focus) if not focus and not smoke then Input:reset(0);paused=true end end
function love.load(args)
 for _,v in ipairs(args) do if v=='--smoke' then smoke=true end end
 if logdir then trace=assert(io.open(logdir..'/trace.csv','wb'));trace:write('tick,player,x,y,z,frame,hp,mp,facing\n');events=assert(io.open(logdir..'/events.log','wb')) end
 l2df:init{fps=60,datafps=30}
 Sync{size=60}
 Renderer{width=960,height=600,depth=600,vsync=true,ratio=true,filter='nearest',shadows=1,cellsize=1,background={0,0,0,0}}
 Renderer:addLayer('GAME',{index=1,width=960,height=600,background={0,0,0,0}})
 Input{keys={'up','down','left','right','attack','jump','defend'},mappings=mappings}
 Input.delay=0
 data.objectdata=Storage()
 States:load('data/states');Kinds:load('data/kinds')
 Attributes=require 'data.scripts.component.attributes';objectAPI=require 'data.scripts.object'
 local actualSpawn=objectAPI.processOpoint
 objectAPI.processOpoint=function(o,d,...)
  local p=d.opoint
  if p and p.oid and not data.objectdata:getById(tonumber(p.oid)) then
   counts.missingOpoint=counts.missingOpoint+1
   if counts.missingOpoint<20 then event('unsupported_opoint id='..tostring(p.oid)) end
  end
  return actualSpawn(o,d,...)
 end
 for _,entry in ipairs(catalog.objects) do loadObject(entry) end
 for i,l in ipairs(catalog.district.layers) do bgimages[i]=pngImage(l.file,l.transparency~=0) end
 room=Scene{active=true};SceneManager:add(room,'prototype');SceneManager:set('prototype');reset()
 local engineUpdate,engineDraw=love.update,love.draw
 love.update=function(dt,islast)
  elapsed=elapsed+dt
  if not paused then
   tick=tick+1;if smoke then inject() end
   engineUpdate(dt,islast);observe()
  end
  if smoke and tick>=600 then
   local json=l2df.import 'class.parser.json'
   local summary={ticks=tick,counts=counts,minHP=minhp,framesSeen=seen,originalExecuted=false,nativeNTSDCompared=false,smokeInput='synthetic love keyboard callbacks',backend=l2df.api.BACKEND,love={love.getVersion()},screenshots=screenshots}
   output('summary.json',json:dump(summary,true));event('smoke_complete');love.event.quit(counts.damageEvents>0 and counts.projectiles and counts.projectiles>0 and counts.audioPlaying>0 and 0 or 2)
  end
 end
 love.draw=function()
  drawBackground();engineDraw();drawHUD()
  if screenshotRequested then
   screenshotRequested=false
   love.graphics.captureScreenshot(function(img) output('interactive-'..tick..'.png',img:encode('png'):getString()) end)
  end
  if smoke and (tick>=5 and not screenshots.idle or tick>=80 and not screenshots.melee or (counts.projectiles or 0)>0 and not screenshots.projectile) then
   local name=not screenshots.idle and 'idle' or not screenshots.melee and 'melee' or 'projectile'
   screenshots[name]=tick
   love.graphics.captureScreenshot(function(img) local bytes=img:encode('png');output(name..'.png',bytes:getString()) end)
  end
 end
 love.audio.setVolume(.7)
 event('ready backend='..l2df.api.BACKEND..' native_window='..love.graphics.getWidth()..'x'..love.graphics.getHeight()..' networking=unregistered')
end
love.run=l2df.gameloop
function love.quit() if trace then trace:close() end;if events then events:close() end end
function love.errorhandler(msg)
 local err=debug.traceback(tostring(msg),2);print(err);output('error.txt',err);return function() return 1 end
end
