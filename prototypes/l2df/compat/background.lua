-- Original nonloop bitmap-layer branch41a2b0..41a3ce, with owned counters.
-- District's120 retained lists are the current comparison domain. Loop/fill/
-- built-in99 use the separately recovered whole BackgroundDrawing contract.
local Background={};Background.__index=Background
local function trunc(n) return n<0 and math.ceil(n) or math.floor(n) end
local function i32(n) n=n%4294967296;return n>=2147483648 and n-4294967296 or n end
local function integer(n)
 n=tonumber(n or 0)
 assert(n and n==math.floor(n) and n>=-2147483648 and n<2147483648,'Invalid background Int32')
 return n
end
local function multiply(a,b)
 -- Low32 product via16-bit limbs; a*b could exceed exact Lua-double integers.
 a=a%4294967296;b=b%4294967296
 local al,bl=a%65536,b%65536
 return i32(al*bl+((math.floor(a/65536)*bl+math.floor(b/65536)*al)%65536)*65536)
end
function Background.new(width,layers)
 local self=setmetatable({width=integer(width),layers={},counters={}},Background)
 for i,input in ipairs(layers) do
  assert(integer(input.loop)==0 and integer(input.rect)==0,'Unsupported looping/fill background')
  local layer={}
  for _,key in ipairs({'width','x','y','cc','c1','c2','transparency'}) do layer[key]=integer(input[key]) end
  self.layers[i]=layer;self.counters[i]=0
 end
 return self
end
function Background:draw(camera,advance)
 camera=integer(camera);local counters,draws={},{}
 for i,layer in ipairs(self.layers) do
  local offset=0
  if self.width>794 then
   local numerator=multiply(i32(layer.width-794),camera)
   local denominator=i32(self.width-794)
   assert(denominator~=0 and not(numerator==-2147483648 and denominator==-1),'Original parallax division fault')
   offset=i32(-trunc(numerator/denominator))
  end
  local counter=self.counters[i]
  if advance and layer.cc>0 then
   local nextValue=i32(counter+1);counter=nextValue-trunc(nextValue/layer.cc)*layer.cc
  end
  counters[i]=counter
  if layer.cc<=0 or (counter>=layer.c1 and counter<=layer.c2) then
   draws[#draws+1]={layer=i-1,x=i32(layer.x+offset),y=layer.y,transparency=layer.transparency}
  end
 end
 if advance then self.counters=counters end
 return draws
end
return Background
