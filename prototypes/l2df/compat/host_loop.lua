-- Native LÖVE host for the recovered no-message timer. L2DF still owns each
-- update's input/components/render traversal; its accumulator is not invoked.
-- Event polling, pause/reset and the monotonic clock binding are native host
-- adapters, not original Windows message/device behavior.
local Timer=require('compat.application_timer')
local Host={generation=0}
function Host.resetClock() Host.generation=Host.generation+1 end
function Host.run()
 if love.load then love.load(love.arg.parseGameArguments(arg),arg) end
 love.timer.step()
 local function now() return math.floor(love.timer.getTime()*1000)%4294967296 end
 local timer,generation=Timer.new(now()),Host.generation
 local logdir=os.getenv('NTSD_L2DF_LOG_DIR');local log=logdir and assert(io.open(logdir..'/timer.jsonl','wb'))
 local iteration=0
 return function()
  love.event.pump()
  for name,a,b,c,d,e,f in love.event.poll() do
   if name=='quit' and (not love.quit or not love.quit()) then if log then log:close() end;return a or 0 end
   love.handlers[name](a,b,c,d,e,f)
  end
  if generation~=Host.generation then timer=Timer.new(now());generation=Host.generation end
  local before=timer.baseline;local clocks,sleeps={},{};local dispatches=0
  timer:iterate(1,{
   time=function() local value=now();clocks[#clocks+1]=value;return value end,
   target=function() return 0 end, -- symbolic native renderer target, no COM pointer
   dispatch=function()
    dispatches=dispatches+1
    if love.update then love.update(.033,true) end
    if love.graphics.isActive() then
     love.graphics.origin();love.graphics.clear(love.graphics.getBackgroundColor())
     if love.draw then love.draw() end
     love.graphics.present()
    end
    return 0 -- native exceptions propagate; there is no submitted HRESULT here
   end,
   recoverSurface=function() error('Unexpected native renderer HRESULT recovery') end,
   sleep=function(ms) sleeps[#sleeps+1]=ms;love.timer.sleep(ms/1000) end})
  if log then
   log:write(('{"iteration":%d,"baselineBefore":%.0f,"baselineAfter":%.0f,"clock":[%s],"dispatches":%d,"sleep":[%s]}\n'):format(iteration,before,timer.baseline,table.concat(clocks,','),dispatches,table.concat(sleeps,',')));log:flush()
  end
  iteration=iteration+1
 end
end
return Host
