local ffi=require('ffi')
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local header=read(love.filesystem.getSource()..'/ntsd_bridge.h')
local declarations={}
for line in header:gmatch('[^\n]+') do
 if not line:match('^#') and line~='extern "C" {' and line~='}' then declarations[#declarations+1]=line end
end
ffi.cdef(table.concat(declarations,'\n'))
local lib=ffi.load(assert(os.getenv('NTSD_BRIDGE_LIBRARY')))
local C=ffi.C
local checks={}
local function check(label,condition)
 assert(condition,label);checks[#checks+1]=label
end
local function status(label,actual,expected) check(label,actual==expected) end
local function backing(seed)
 local b=ffi.new('uint8_t[1056]');for i=0,1055 do b[i]=(i*37+seed)%256 end;return b
end
local function create(b)
 local h=ffi.new('uint64_t[1]');status('create',lib.ntsd_bridge_create(1,b,1056,h),C.NTSD_BRIDGE_OK);return h[0]
end
local function snapshot(h)
 local b,m,r=ffi.new('uint8_t[1056]'),ffi.new('uint8_t[1056]'),ffi.new('uint64_t[1]')
 status('snapshot',lib.ntsd_bridge_snapshot(h,b,m,1056,r),C.NTSD_BRIDGE_OK)
 return {bytes=ffi.string(b,1056),mask=ffi.string(m,1056),revision=tostring(r[0])}
end
local function equal(a,b) return a.bytes==b.bytes and a.mask==b.mask and a.revision==b.revision end
local function publish(name,state)
 for _,field in ipairs({'bytes','mask'}) do
  local f=assert(io.open(love.filesystem.getSource()..'/'..name..'.'..field,'wb'))
  f:write(state[field]);f:close()
 end
end
local function edits(h,offsets,values)
 return lib.ntsd_bridge_setup_apply_i32(h,ffi.new('uint32_t[?]',#offsets,offsets),ffi.new('int32_t[?]',#values,values),#offsets)
end
function love.errorhandler(message)
 io.stderr:write(tostring(message)..'\n'..debug.traceback()..'\n');io.stderr:flush()
 return function() return 1 end
end
function love.load()
 check('ABI version',lib.ntsd_bridge_abi_version()==1)
 check('declared capabilities without gameplay',lib.ntsd_bridge_capabilities()==1 or lib.ntsd_bridge_capabilities()==3 or lib.ntsd_bridge_capabilities()==7)
 check('initial registry empty',lib.ntsd_bridge_live_sessions()==0)
 local b=backing(0xa5);local original=ffi.string(b,1056)
 local sentinel=ffi.new('uint64_t[1]',0x112233)
 status('wrong version',lib.ntsd_bridge_create(2,b,1056,sentinel),C.NTSD_BRIDGE_ABI_MISMATCH)
 check('failed create preserves output',tonumber(sentinel[0])==0x112233)
 status('wrong count',lib.ntsd_bridge_create(1,b,1055,sentinel),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 status('null backing',lib.ntsd_bridge_create(1,nil,1056,sentinel),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 status('null output',lib.ntsd_bridge_create(1,b,1056,nil),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 check('failed creates allocate nothing',lib.ntsd_bridge_live_sessions()==0)
 local a=create(b);local second=create(backing(0x51))
 check('distinct handles',a~=second)
 local before=snapshot(a);local secondBefore=snapshot(second)
 -- Expected constructor bytes/masks stay in the external Python comparator.
 publish('constructor-a',before);publish('constructor-b',secondBefore)
 check('constructor unknown offset preserved',before.bytes:byte(0x31c+1)==original:byte(0x31c+1) and before.mask:byte(0x31c+1)==0)
 for i=1,1056 do if before.mask:byte(i)==0 then assert(before.bytes:byte(i)==original:byte(i),'unknown backing changed') end end
 checks[#checks+1]='all unknown backing bytes preserved'
 ffi.fill(b,1056,0)
 check('input buffer copied',equal(before,snapshot(a)))
 local lifecycle,revision=ffi.new('uint32_t[1]'),ffi.new('uint64_t[1]')
 status('session info',lib.ntsd_bridge_info(a,lifecycle,revision),C.NTSD_BRIDGE_OK)
 check('unbound lifecycle',lifecycle[0]==1 and revision[0]==0)
 local value=ffi.new('int32_t[1]',-123)
 status('constructor HP read',lib.ntsd_bridge_read_i32(a,0x2fc,value),C.NTSD_BRIDGE_OK)
 check('constructor HP',value[0]==500)
 value[0]=-123
 status('undefined read',lib.ntsd_bridge_read_i32(a,0x31c,value),C.NTSD_BRIDGE_UNDEFINED)
 check('failed read output unchanged',value[0]==-123)
 status('partly defined word rejected',lib.ntsd_bridge_read_i32(a,0x80,value),C.NTSD_BRIDGE_UNDEFINED)
 status('bounds read',lib.ntsd_bridge_read_i32(a,1056,value),C.NTSD_BRIDGE_OUT_OF_BOUNDS)
 status('unaligned read',lib.ntsd_bridge_read_i32(a,1,value),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 status('null read',lib.ntsd_bridge_read_i32(a,0,nil),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 status('setup transaction',edits(a,{0x2fc,0x300},{321,456}),C.NTSD_BRIDGE_OK)
 status('persisted value read',lib.ntsd_bridge_read_i32(a,0x2fc,value),C.NTSD_BRIDGE_OK)
 check('persisted value',value[0]==321)
 status('second edit read',lib.ntsd_bridge_read_i32(a,0x300,value),C.NTSD_BRIDGE_OK)
 check('second edit persists',value[0]==456)
 local committed=snapshot(a)
 check('revision increments once',committed.revision=='1ULL')
 check('other session unchanged',equal(secondBefore,snapshot(second)))
 status('rollback undefined second write',edits(a,{0x2fc,0x368},{1,2}),C.NTSD_BRIDGE_UNDEFINED)
 check('whole bytes/masks/revision rollback',equal(committed,snapshot(a)))
 status('rollback bounds second write',edits(a,{0x2fc,1056},{3,4}),C.NTSD_BRIDGE_OUT_OF_BOUNDS)
 check('whole rollback after bounds',equal(committed,snapshot(a)))
 status('rollback alignment second write',edits(a,{0x2fc,1},{3,4}),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 check('whole rollback after alignment',equal(committed,snapshot(a)))
 status('rollback partly defined word',edits(a,{0x2fc,0x80},{3,4}),C.NTSD_BRIDGE_UNDEFINED)
 check('whole rollback after partial definition',equal(committed,snapshot(a)))
 for _,signed in ipairs({-1,-2147483648,2147483647}) do
  status('signed setup',edits(a,{0x2fc},{signed}),C.NTSD_BRIDGE_OK)
  status('signed read',lib.ntsd_bridge_read_i32(a,0x2fc,value),C.NTSD_BRIDGE_OK)
  check('signed value exact',value[0]==signed)
 end
 status('empty batch',lib.ntsd_bridge_setup_apply_i32(a,nil,nil,0),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 local shortBytes,shortMask=ffi.new('uint8_t[1056]'),ffi.new('uint8_t[1056]')
 ffi.fill(shortBytes,1056,0x55);ffi.fill(shortMask,1056,0x66);revision[0]=123
 status('short output',lib.ntsd_bridge_snapshot(a,shortBytes,shortMask,1055,revision),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 check('short output untouched',ffi.string(shortBytes,1056)==string.rep(string.char(0x55),1056) and ffi.string(shortMask,1056)==string.rep(string.char(0x66),1056) and revision[0]==123)
 status('destroy first owner',lib.ntsd_bridge_destroy(a),C.NTSD_BRIDGE_OK)
 status('double destroy rejected',lib.ntsd_bridge_destroy(a),C.NTSD_BRIDGE_INVALID_HANDLE)
 status('stale read rejected',lib.ntsd_bridge_read_i32(a,0,value),C.NTSD_BRIDGE_INVALID_HANDLE)
 status('stale write rejected',edits(a,{0},{1}),C.NTSD_BRIDGE_INVALID_HANDLE)
 status('stale info rejected',lib.ntsd_bridge_info(a,lifecycle,revision),C.NTSD_BRIDGE_INVALID_HANDLE)
 check('remaining owner preserved',equal(secondBefore,snapshot(second)))
 local fresh=create(b)
 check('handle never reused',fresh~=a and fresh~=second)
 status('destroy fresh',lib.ntsd_bridge_destroy(fresh),C.NTSD_BRIDGE_OK)
 local owners={second};for i=2,64 do owners[i]=create(b) end
 status('live session limit',lib.ntsd_bridge_create(1,b,1056,sentinel),C.NTSD_BRIDGE_LIMIT)
 check('limit does not allocate',lib.ntsd_bridge_live_sessions()==64)
 for _,h in ipairs(owners) do status('destroy owner',lib.ntsd_bridge_destroy(h),C.NTSD_BRIDGE_OK) end
 check('registry empty after release',lib.ntsd_bridge_live_sessions()==0)
 if os.getenv('NTSD_BRIDGE_RESOURCE_ROOT') then
  dofile(love.filesystem.getSource()..'/loaded.lua')(ffi,lib,check,status)
 end
 local out=assert(io.open(love.filesystem.getSource()..'/result.json','w'))
 local major,minor,revisionVersion,codename=love.getVersion()
 out:write('{"pass":true,"abi":1,"lifecycle":"ACTOR_STORAGE","gameplayCapability":false,"checks":'..#checks..',"love":['..major..','..minor..','..revisionVersion..'],"jitArch":"'..jit.arch..'","labels":[')
 for i,label in ipairs(checks) do if i>1 then out:write(',') end;out:write('"'..label..'"') end
 out:write(']}\n');out:close()
 print('Native bridge FFI PASS '..#checks..' checks; no gameplay capability')
 love.event.quit(0)
end
