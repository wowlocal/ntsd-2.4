-- Numeric projection of complete, well-formed retained Frame sections.
-- This is not the full original stream/overflow/aliasing loader. In particular,
-- malformed nested sections (including weapon4.dat) are outside this adapter.
local copy=require('compat.actor_input').copy
local M={}
local scalar={pic=true,state=true,wait=true,next=true,dvx=true,dvy=true,dvz=true,
 hit_a=true,hit_d=true,hit_j=true,hit_Fa=true,hit_Ua=true,hit_Da=true,
 hit_Fj=true,hit_Uj=true,hit_Dj=true,hit_ja=true,mp=true,centerx=true,centery=true}
local function numbers(text,result)
 result=result or {}
 for key,value in text:gmatch('([%w_]+):%s*([+-]?%d+)') do result[key]=tonumber(value) end
 return result
end
function M.frames(sections)
 local frames={}
 for _,source in ipairs(sections) do
  local id,name=source:match('^%s*<frame>%s+([+-]?%d+)%s+(%S+)')
  id=assert(tonumber(id),'Expected complete frame section')
  assert(id>=0 and id<400 and source:match('<frame_end>%s*$'),'Frame outside projection domain')
  assert(#name<28,'Frame name overlaps storage outside this projection')
  local f=copy(frames[id] or {});f.present=true;f.name=name;f.itrs={};f.bodies={}
  for key in pairs(scalar) do if f[key]==nil then f[key]=0 end end
  local text=source
  for _,block in ipairs({'itr','bdy','opoint','wpoint','cpoint','bpoint'}) do
   text=text:gsub(block..':%s*(.-)'..block..'_end:',function(content)
    assert(not content:find('<frame>') and not content:find('<frame_end>'),'Nested malformed frame section')
    if block=='itr' then f.itrs[#f.itrs+1]=numbers(content)
    elseif block=='bdy' then f.bodies[#f.bodies+1]=numbers(content)
    elseif block=='opoint' then f.opoint=numbers(content,f.opoint or {}) end
    return ' '
   end)
   assert(not text:find(block..':',1,true),'Unclosed '..block..' block')
  end
  assert(#f.itrs<=5 and #f.bodies<=5,'Box count outside retained allocation')
  for key,value in pairs(numbers(text)) do if scalar[key] then f[key]=value end end
  local sound=text:match('sound:%s*(%S+)');if sound then f.sound=sound end
  frames[id]=f
 end
 return frames
end
return M
