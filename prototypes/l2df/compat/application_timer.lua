-- Whole original no-message decision43d157..43d1ef. The retained reference
-- supplies external clock/dispatcher/recovery/Sleep responses, not OS behavior.
-- Only the timer baseline commits here; callbacks own their external effects.
local Timer={};Timer.__index=Timer
local modulus=4294967296
local function unsigned(n)
 assert(type(n)=='number' and n==math.floor(n) and n>=0 and n<modulus,'Expected UInt32 timer input')
 return n
end
local function signed(n)
 assert(type(n)=='number' and n==math.floor(n) and n>=-2147483648 and n<2147483648,'Expected Int32 timer input')
 return n
end
function Timer.new(baseline) return setmetatable({baseline=unsigned(baseline)},Timer) end
function Timer:iterate(speedFlag,callbacks)
 local nextBaseline=self.baseline
 local interval=signed(speedFlag)==0 and 3 or 33
 local function time() return unsigned(callbacks.time()) end
 if (time()-nextBaseline)%modulus>interval then
  if (time()-nextBaseline)%modulus>100 then nextBaseline=(time()-100)%modulus end
  local surface=unsigned(callbacks.target())
  nextBaseline=(nextBaseline+interval)%modulus
  if signed(callbacks.dispatch(surface))<0 then callbacks.recoverSurface() end
 end
 local remainder=(nextBaseline-time()+interval)%modulus
 if remainder>=2147483648 then remainder=remainder-modulus end
 if remainder>0 then callbacks.sleep(math.min(remainder,5)) end
 self.baseline=nextBaseline
end
return Timer
