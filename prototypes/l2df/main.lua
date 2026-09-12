-- Native L2DF host with the retained NTSD bounded Practice components.
-- L2DF owns events, objects, input/controller, frame storage, rendering and audio.
-- compat.world owns input edges/history, motion, collision, spawn and scheduling.
local counts={audioCalls=0,audioPlaying=0,damageEvents=0,spawned=0,projectiles=0,keyboardCallbacks=0}
local nativeAudioPlay=love.audio.play
love.audio.play=function(sources,...)
 local list=type(sources)=='table' and sources or {sources};counts.audioCalls=counts.audioCalls+#list
 local result=nativeAudioPlay(sources,...)
 for _,source in ipairs(list) do if source:isPlaying() then counts.audioPlaying=counts.audioPlaying+1 end end
 return result
end
l2df=require 'l2df'
data={FPS=1000/33,players={'Naruto','Sasuke'},lf2_objects={},isplaying=true}
local catalog=require 'catalog'
local config=require 'compat-data'
local World=require 'compat.world'
local Background=require 'compat.background'
local Host=require 'compat.host_loop'
local copy=require('compat.actor_input').copy
local Parser=l2df.import 'class.parser.lffs2'
local Converter=require 'tools.lf2dat'
local SceneManager=l2df.import 'manager.scene'
local Scene=l2df.import 'class.entity.scene'
local Object=l2df.import 'class.entity.object'
local Component=l2df.import 'class.component'
local Frames=l2df.import 'class.component.frames'
local Render=l2df.import 'class.component.render'
local Transform=l2df.import 'class.component.transform'
local Renderer=l2df.import 'manager.render'
local Resources=l2df.import 'manager.resource'
local Input=l2df.import 'manager.input'
local Controller=l2df.import 'class.component.controller'
local SoundManager=l2df.import 'manager.sound'
local Storage=l2df.import 'class.storage'
local Sync=l2df.import 'manager.sync'
local json=require 'l2df.external.json'
local room,simulation,state,objects,caseInput
local tick,smoke,paused,elapsed=0,false,false,0
local logdir=os.getenv('NTSD_L2DF_LOG_DIR')
local trace,eventFile,fullTrace,inputTrace,presentationTrace
local background,backgroundDraws
local bgimages,imagecache,soundcache={},{},{}
local minhp,seen,screenshots={500,500},{{},{}},{}
local held={};local screenshotRequested=false;local boundary
local uiResetCheck,resetReady,resetReport=false,false,nil
local finished=false
local mappings={
 {up='w',down='s',left='a',right='d',attack='f',jump='g',defend='h'},
 {up='up',down='down',left='left',right='right',attack='j',jump='k',defend='l'}
}
local bits={up=128,down=64,left=32,right=16,attack=8,jump=4,defend=2}
local arrays={actors=true,sounds=true,projectiles=true,projectileDraws=true,mpSpent=true,vrest=true,combos=true,inputs=true,background=true,poses=true,counters=true}
local function precise(v,key)
 if type(v)=='number' then return json:asNumber(string.format('%.17g',v)) end
 if type(v)~='table' then return v end
 local r=arrays[key] and json:newArray({}) or {};for k,x in pairs(v) do r[k]=precise(x,k) end;return r
end
local function encode(v) return json:encode(precise(v)) end
local function output(name,text)
 if logdir then local f=assert(io.open(logdir..'/'..name,'wb'));f:write(text);f:close() end
end
local function event(s)
 print('PROTOTYPE '..s)
 if eventFile then eventFile:write(tick..' '..s..'\n');eventFile:flush() end
end
local function pngImage(path,key)
 local id=path..(key and '#black-key' or '#opaque');if imagecache[id] then return imagecache[id] end
 local pixels=love.image.newImageData(path)
 if key then pixels:mapPixel(function(x,y,r,g,b,a) if r==0 and g==0 and b==0 then return r,g,b,0 end return r,g,b,a end) end
 local img=love.graphics.newImage(pixels);img:setFilter('nearest','nearest');imagecache[id]=img;return img
end
local function loadObject(entry)
 local raw=assert(love.filesystem.read(entry.file));local decoded=Converter.decrypt(raw)
 assert(love.data.encode('string','hex',love.data.hash('sha256',decoded))==entry.decodedSHA256,'DAT decoder differs from prepared input')
 local parsed=assert(Parser:parse(Converter.convert_text(decoded,{type=entry.type})))
 parsed._lf2,parsed._lf2_type,parsed.lf2id=true,entry.type,entry.id
 local count,unique=0,{};for _,f in ipairs(parsed.frames or {}) do count=count+1;unique[f[1]]=true end
 local n=0;for _ in pairs(unique) do n=n+1 end
 event(('import id=%d definitions=%d unique=%d sourceMarkers=%d'):format(entry.id,count,n,entry.frameMarkers))
 assert(count==entry.frameMarkers,'candidate dropped/nested source frames')
 for _,s in ipairs(parsed.sprites or {}) do Resources:addById(s[1],pngImage(s[1],true)) end
 data.objectdata:addById(parsed,entry.id,true)
end
-- Keep L2DF Frames:add/set and Render intact. SourceWorld selects the already
-- captured render pose; candidate auto-animation/physics/collision cannot run.
local PoseFrames=Frames:extend({unique=true})
function PoseFrames:preupdate() end
function PoseFrames:removed(obj)
 -- Upstream Frames uses self.super, which resolves back to Frames on this
 -- subclass. Invoke the base component cleanup directly when a pose expires.
 Component.removed(self,obj);obj.C.frames=nil
end
local PresentationObject=Object:extend({name='source-presentation'})
function PresentationObject:init(def)
 self:addComponent(Transform);self:addComponent(PoseFrames,def);self:addComponent(Render,def)
end
local function entity(slot,id)
 local def=data.objectdata:getById(id);local obj=PresentationObject(def)
 obj.data.layer='GAME';obj.data.lf2id=id;obj.data.syncid='source-slot:'..slot
 if slot<2 then obj:addComponent(Controller,slot+1) end
 room:attach(obj);objects[slot]=obj;return obj
end
local function pose(slot,id,frame,facing,x,y,z)
 local obj=objects[slot]
 if obj and obj.data.lf2id~=id then room:detach(obj);obj:destroy();objects[slot]=nil;obj=nil end
 obj=obj or entity(slot,id)
 assert(obj.C.frames.data().list[frame],'Missing original display frame '..id..':'..frame)
 obj.C.frames.set(frame)
 local f=assert(simulation.catalog[id][frame]);local d=obj.data
 d.pic=f.pic+1;d.centerx=f.centerx;d.centery=f.centery;d.x=x-state.cameraX;d.y=-y;d.z=z;d.facing=1-facing*2;d.hidden=false
 -- Shared L2DF sprite/shadow placement receives original camera-relative X.
end
local function project()
 local keep={[0]=true,[1]=true}
 for i,m in ipairs(state.actors) do pose(i-1,i==1 and 2 or 11,m.renderFrame,m.renderFacing,m.renderX,m.renderY,m.renderZ) end
 for _,p in ipairs(state.projectileDraws) do keep[p.slot]=true;pose(p.slot,p.id,p.frame,p.facing,p.x,p.y,p.z) end
 local remove={};for slot in pairs(objects) do if not keep[slot] then remove[#remove+1]=slot end end
 for _,slot in ipairs(remove) do local obj=objects[slot];room:detach(obj);obj:destroy();objects[slot]=nil end
end
local builtins={['builtin:0']='001.wav',['builtin:1']='002.wav',['builtin:2']='006.wav',['builtin:6']='016.wav',['builtin:7']='017.wav',['builtin:11']='032.wav',['builtin:12']='033.wav'}
local function playSounds(sounds)
 for _,name in ipairs(sounds) do
  local file=builtins[name] or name:gsub('\\','/'):match('([^/]+)$');local path='data/sounds/'..file
  if not soundcache[path] then soundcache[path]=love.audio.newSource(path,'static');Resources:addById(path,soundcache[path]) end
  SoundManager:play(soundcache[path],true)
 end
end
local function reset()
 if objects then for _,obj in pairs(objects) do room:detach(obj);obj:destroy() end end
 objects={};local cfg=copy(config)
 cfg.initial=caseInput and caseInput.initial or {{x=410},{x=475}};cfg.localPlayer=caseInput and caseInput.localPlayer or 0
 simulation=World.new(cfg);state=simulation:snapshot();tick=0;boundary=nil;paused=false;held={}
 background=Background.new(catalog.district.width,catalog.district.layers);backgroundDraws=background:draw(state.cameraX,false)
 Host.resetClock()
 Input:reset(0);Input.delay=0;project();event('reset owned_world=retained-Practice no_regeneration=true')
end
local function desiredKeys(t)
 local k={}
 if resetReport then return k end
 if caseInput then
  for i,mask in ipairs(caseInput.inputs[t] or {0,0}) do for button,bit in pairs(bits) do if math.floor(mask/bit)%2==1 then k[mappings[i][button]]=true end end end
  return k
 end
 if t>=10 and t<17 then k.a=true end
 if t>=22 and t<29 then k.d=true end
 if t==40 or t==70 then k.f=true end
 if t>=95 and t<101 then k.right=true end
 if t>=110 and t<116 then k.left=true end
 if t==140 then k.k=true end
 -- Three separate rising edges: defense, direction, attack.
 if t==190 then k.l=true elseif t==191 then k.left=true elseif t==192 then k.j=true end
 return k
end
local function inject()
 local want=desiredKeys(tick+1)
 for k in pairs(held) do if not want[k] then love.keyreleased(k,k);held[k]=nil end end
 for k in pairs(want) do if not held[k] then love.keypressed(k,k,false);held[k]=true end end
end
local function observe(masks)
 for i,m in ipairs(state.actors) do
  seen[i][m.frame]=true
  if m.hp<minhp[i] then counts.damageEvents=counts.damageEvents+1;minhp[i]=m.hp end
  if trace then trace:write(('%d,%d,%.17g,%.17g,%.17g,%d,%d,%d,%d\n'):format(tick-1,i,m.x,m.y,m.z,m.frame,m.hp,m.mp,m.facing)) end
 end
 for _,e in ipairs(simulation.events) do
  if e.kind=='spawn' then counts.spawned=counts.spawned+1;if e.id==440 or e.id==224 then counts.projectiles=counts.projectiles+1 end end
  event(encode(e))
 end
 if fullTrace then fullTrace:write(encode({tick=tick-1,state=state})..'\n');fullTrace:flush();inputTrace:write(encode({tick=tick-1,inputs=masks})..'\n');inputTrace:flush() end
 if presentationTrace then
  local slots={};for slot in pairs(objects) do slots[#slots+1]=slot end;table.sort(slots)
  local poses={};for _,slot in ipairs(slots) do local d=objects[slot].data;poses[#poses+1]={slot=slot,id=d.lf2id,x=d.x,y=d.y,z=d.z,pic=d.pic,facing=d.facing,centerx=d.centerx,centery=d.centery} end
  presentationTrace:write(encode({tick=tick-1,cameraX=state.cameraX,viewport={width=794,height=550},background=backgroundDraws,counters=background.counters,poses=poses})..'\n');presentationTrace:flush()
 end
end
local SourceHost=Component:extend({unique=true})
function SourceHost:preupdate()
 local masks={0,0}
 for i=1,2 do for button,bit in pairs(bits) do if objects[i-1].C.controller.pressed(button) then masks[i]=masks[i]+bit end end end
 local ok,result=pcall(simulation.tick,simulation,masks)
 if not ok then
  local message=tostring(result)
  if not message:find('Unsupported',1,true) and not message:find('outside retained',1,true) then error(result) end
  boundary=message;paused=true;screenshotRequested=true;event('unsupported_tick rolled_back=true '..boundary);output('boundary.txt',boundary)
  output('boundary-state.json',encode({before=state,after=simulation:snapshot(),attemptedInputs=masks,unchanged=encode(state)==encode(simulation:snapshot())}))
  return
 end
 state=result;tick=tick+1;backgroundDraws=background:draw(state.cameraX,true);project();playSounds(state.sounds);observe(masks)
end
local function drawBackground()
 local g=love.graphics;local sx,sy,ox,oy=Renderer:getScaleInfo()
 g.push('all');g.origin();g.translate(ox,oy);g.scale(sx,sy)
 g.setScissor(ox,oy,794*sx,550*sy);g.setColor(1,1,1,1)
 for _,draw in ipairs(backgroundDraws) do g.draw(bgimages[draw.layer+1],draw.x,draw.y) end
 love.graphics.pop()
end
local function drawHUD()
 local g=love.graphics;local sx,sy,ox,oy=Renderer:getScaleInfo();g.push('all');g.origin();g.translate(ox,oy);g.scale(sx,sy)
 g.setColor(.04,.06,.10,1);g.rectangle('fill',0,0,794,100)
 for i,m in ipairs(state.actors) do local x=i==1 and 18 or 424
  g.setColor(1,1,1,1);g.print(i==1 and 'NARUTO / P1' or 'SASUKE / P2',x,12)
  g.setColor(.20,.24,.30,1);g.rectangle('fill',x,37,350,10)
  g.setColor(i==1 and .96 or .42,i==1 and .50 or .62,i==1 and .17 or 1,1);g.rectangle('fill',x,37,350*math.max(0,m.hp)/500,10)
  g.setColor(.3,.7,1,1);g.rectangle('fill',x,53,350*math.max(0,m.mp)/500,5)
  g.setColor(.8,.85,.9,1);g.print(('HP %d  CHAKRA %d'):format(m.hp,m.mp),x,68)
 end
 g.setColor(.04,.06,.10,.94);g.rectangle('fill',0,550,794,54)
 g.setColor(.88,.91,.95,1);g.print('P1 WASD / F attack / G jump / H defend     P2 arrows / J attack / K jump / L defend',14,560)
 g.setColor(.65,.74,.83,1);g.print('Needles: L, then left/right, then J.  Cost: 100 chakra.   R restart / M mute / Esc pause / Q quit',14,580)
 g.setColor(.95,.85,.5,1);g.print('NTSD · Training',310,109)
 if paused then
  g.setColor(0,0,0,.85);g.rectangle('fill',142,210,510,140);g.setColor(1,1,1,1)
  g.printf(boundary and 'This move is not supported yet.\nPress R to restart.' or 'PAUSED / Esc to resume',147,255,500,'center')
 end
 if state.actors[1].hp<=0 or state.actors[2].hp<=0 then g.setColor(1,.9,.5,1);g.printf('Practice knockout / R to restart',260,190,440,'center') end
 g.pop()
end
function love.keypressed(key)
 counts.keyboardCallbacks=counts.keyboardCallbacks+1
 if key=='f12' then screenshotRequested=true elseif key=='q' then love.event.quit() elseif key=='escape' then if not boundary then paused=not paused;Host.resetClock() end elseif key=='r' then reset() elseif key=='m' then love.audio.setVolume(love.audio.getVolume()>0 and 0 or .7) end
end
function love.focus(focus) if not smoke then Host.resetClock();if not focus then Input:reset(0);paused=true end end end
function love.load(args)
 love.window.setTitle('NTSD · Training')
 for _,v in ipairs(args) do if v=='--smoke' then smoke=true elseif v=='--ui-reset-check' then uiResetCheck=true end end
 assert(not uiResetCheck or smoke,'Reset diagnostic requires smoke mode')
 local casePath=os.getenv('NTSD_L2DF_CASE_INPUT')
 if casePath then assert(smoke);local f=assert(io.open(casePath,'rb'));caseInput=json:decode(f:read('*a'));f:close();assert(not caseInput.states and caseInput.inputs,'Expected input-only smoke case') end
 if logdir then
  trace=assert(io.open(logdir..'/trace.csv','wb'));trace:write('tick,player,x,y,z,frame,hp,mp,facing\n')
  eventFile=assert(io.open(logdir..'/events.log','wb'));fullTrace=assert(io.open(logdir..'/world.jsonl','wb'));inputTrace=assert(io.open(logdir..'/inputs.jsonl','wb'))
  presentationTrace=assert(io.open(logdir..'/presentation.jsonl','wb'))
 end
 l2df:init{fps=1000/33,datafps=1000/33};Sync{size=60}
 Renderer{width=794,height=604,depth=600,vsync=true,ratio=true,filter='nearest',shadows=1,cellsize=1,background={0,0,0,0}}
 Renderer:addLayer('GAME',{index=1,width=794,height=550,background={0,0,0,0}})
 Input{keys={'up','down','left','right','attack','jump','defend'},mappings=mappings};Input.delay=0
 data.objectdata=Storage()
 for _,entry in ipairs(catalog.objects) do loadObject(entry) end
 for i,l in ipairs(catalog.district.layers) do bgimages[i]=pngImage(l.file,l.transparency~=0) end
 room=Scene{active=true};room:addComponent(SourceHost);SceneManager:add(room,'prototype');SceneManager:set('prototype');reset()
 local engineUpdate,engineDraw=love.update,love.draw
 love.update=function(dt,islast)
  if finished then return end -- L2DF may schedule another catch-up update before polling quit.
  elapsed=elapsed+dt
  if uiResetCheck and resetReady then
   resetReady=false
   local rejectedTick=tick;local unchanged=encode(state)==encode(simulation:snapshot())
   love.keypressed('r','r',false)
   local entityCount=0;for _ in pairs(objects) do entityCount=entityCount+1 end
   local inputClear=true
   for i=0,1 do
    local a=simulation.input[i]
    for _,fields in ipairs({a.buffers,a.previous,a.current,a.history,a.progress}) do for _,v in pairs(fields) do if v~=0 then inputClear=false end end end
   end
   resetReport={rejectedTick=rejectedTick,boundaryRolledBack=unchanged,resetTick=tick,entities=entityCount,
    projectileCount=#state.projectiles,inputClear=inputClear,mpSpent=copy(state.mpSpent),
    randomRestored=simulation.random.index==config.random.index and simulation.random.counter==config.random.counter,
    resetCallback='love.keypressed r',paused=paused,boundaryCleared=boundary==nil}
   output('reset-state.json',encode({report=resetReport,state=state}))
  end
  if not paused then if smoke then inject() end;engineUpdate(dt,islast) end
  if uiResetCheck and boundary then return end -- retain notice until its PNG callback completes
  if uiResetCheck and resetReport then
   resetReport.continuationTicks=tick
   local r=resetReport;local passed=r.boundaryRolledBack and r.resetTick==0 and r.entities==2 and r.projectileCount==0 and r.inputClear and r.randomRestored and not r.paused and r.boundaryCleared and tick==1
   output('summary.json',encode({uiResetCheck=r,passed=passed,counts=counts,love={love.getVersion()},originalExecuted=false}));event('reset_check_complete pass='..tostring(passed));finished=true;love.event.quit(passed and 0 or 2);return
  end
  if smoke and (boundary or tick>=(caseInput and #caseInput.inputs or 330)) then
   output('summary.json',encode({ticks=tick,counts=counts,minHP=minhp,framesSeen=seen,screenshots=screenshots,mpSpent=state.mpSpent,
    originalExecuted=false,domain='retained two-fighter Practice',input='synthetic love callbacks through L2DF Input/Controller',
    backend=l2df.api.BACKEND,love={love.getVersion()},case=caseInput and caseInput.label,boundary=boundary,
    cadenceSeconds=l2df.tickrate,timerContract='OriginalApplicationTimer no-message decision; native LÖVE clock/event/render bindings',elapsed=elapsed}))
   local passed=not boundary and counts.damageEvents>0 and counts.projectiles>=5 and counts.audioPlaying>0
   event('smoke_complete pass='..tostring(passed));finished=true;love.event.quit(passed and 0 or 2)
  end
 end
 love.draw=function()
  drawBackground();engineDraw();drawHUD()
  if screenshotRequested then
   screenshotRequested=false
   love.graphics.captureScreenshot(function(img)
    output('interactive-'..tick..'.png',img:encode('png'):getString())
    if uiResetCheck and boundary then resetReady=true end
   end)
  end
  if smoke then
   local name
   if tick>=2 and not screenshots.idle then name='idle'
   elseif #state.projectileDraws>=5 and not screenshots.projectile then name='projectile'
   elseif #state.projectileDraws>=5 and screenshots.projectile and tick>=screenshots.projectile+3 and not screenshots.fan then name='fan'
   elseif counts.damageEvents>0 and not screenshots.hit then name='hit' end
   if name then screenshots[name]=tick;love.graphics.captureScreenshot(function(img) output(name..'.png',img:encode('png'):getString()) end) end
  end
 end
 love.audio.setVolume(.7)
 event('ready backend='..l2df.api.BACKEND..' native_window='..love.graphics.getWidth()..'x'..love.graphics.getHeight()..' networking=unregistered cadence=33ms')
end
love.run=Host.run
function love.quit() for _,f in ipairs({trace,eventFile,fullTrace,inputTrace,presentationTrace}) do if f then f:close() end end end
function love.errorhandler(msg) local err=debug.traceback(tostring(msg),2);print(err);output('error.txt',err);return function() return 1 end end
