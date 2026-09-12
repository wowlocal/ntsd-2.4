return function(ffi,lib,check,status)
 local C=ffi.C
 check('exact implemented capabilities',lib.ntsd_bridge_capabilities()==7)
 local root=assert(os.getenv('NTSD_BRIDGE_RESOURCE_ROOT'))
 local owned=assert(os.getenv('NTSD_BRIDGE_OWNED_INPUT'))
 local bad=assert(os.getenv('NTSD_BRIDGE_BAD_INPUT'))
 local function snapshot(h)
  local size,revision=ffi.new('uint32_t[1]'),ffi.new('uint64_t[1]')
  status('loaded snapshot query',lib.ntsd_bridge_loaded_snapshot(h,nil,0,size,revision),C.NTSD_BRIDGE_OK)
  local bytes=ffi.new('uint8_t[?]',tonumber(size[0]))
  status('loaded snapshot copy',lib.ntsd_bridge_loaded_snapshot(h,bytes,size[0],size,revision),C.NTSD_BRIDGE_OK)
  return ffi.string(bytes,tonumber(size[0])),tonumber(revision[0])
 end
 local function write(name,data)
  local f=assert(io.open(love.filesystem.getSource()..'/'..name,'wb'));f:write(data);f:close()
 end
 local output=ffi.new('uint64_t[1]',0x112233)
 status('pristine ABI mismatch',lib.ntsd_bridge_create_pristine(2,root,#root,0,output),C.NTSD_BRIDGE_ABI_MISMATCH)
 status('pristine invalid profile',lib.ntsd_bridge_create_pristine(1,root,#root,2,output),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 status('pristine empty root',lib.ntsd_bridge_create_pristine(1,root,0,0,output),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 status('pristine null root',lib.ntsd_bridge_create_pristine(1,nil,#root,0,output),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 status('independent PE hash rejects manifest forgery',lib.ntsd_bridge_create_pristine(1,bad,#bad,0,output),C.NTSD_BRIDGE_INVALID_ARGUMENT)
 check('pristine failed creates preserve registry and output',lib.ntsd_bridge_live_sessions()==0 and output[0]==0x112233)
 local actor=ffi.new('uint64_t[1]')
 status('parallel Actor owner',lib.ntsd_bridge_create(1,ffi.new('uint8_t[1056]'),1056,actor),C.NTSD_BRIDGE_OK)
 status('Actor rejects front loading',lib.ntsd_bridge_load_front_settings(actor[0]),C.NTSD_BRIDGE_UNSUPPORTED)
 status('Actor rejects first-menu call',lib.ntsd_bridge_continue_front_screen(actor[0],0),C.NTSD_BRIDGE_UNSUPPORTED)
 status('Actor rejects loaded export',lib.ntsd_bridge_loaded_snapshot(actor[0],nil,0,ffi.new('uint32_t[1]'),ffi.new('uint64_t[1]')),C.NTSD_BRIDGE_UNSUPPORTED)
 local handles={}
 for profile=0,1 do
  local path=profile==0 and owned or root
  local pathBuffer=ffi.new('uint8_t[?]',#path);ffi.copy(pathBuffer,path,#path)
  status('create pristine owner',lib.ntsd_bridge_create_pristine(1,pathBuffer,#path,profile,output),C.NTSD_BRIDGE_OK)
  local h=output[0];handles[#handles+1]=h
  ffi.fill(pathBuffer,#path,0)
  local before,revision=snapshot(h);write('loaded-'..profile..'-boot.json',before)
  local phase,rev=ffi.new('uint32_t[1]'),ffi.new('uint64_t[1]')
  status('pristine info',lib.ntsd_bridge_info(h,phase,rev),C.NTSD_BRIDGE_OK)
  check('pristine phase and revision',phase[0]==2 and rev[0]==0 and revision==0)
  status('boot cannot skip front-settings',lib.ntsd_bridge_continue_front_screen(h,0),C.NTSD_BRIDGE_UNSUPPORTED)
  check('rejected skipped lifecycle preserves owner',snapshot(h)==before)
  status('pristine rejects Actor edits',lib.ntsd_bridge_setup_apply_i32(h,ffi.new('uint32_t[1]',0),ffi.new('int32_t[1]',1),1),C.NTSD_BRIDGE_UNSUPPORTED)
  status('pristine rejects Actor read',lib.ntsd_bridge_read_i32(h,0,ffi.new('int32_t[1]')),C.NTSD_BRIDGE_UNSUPPORTED)
  if profile==0 then
   -- Only this run's copied input. Immutable original/resource pack is untouched.
   local f=assert(io.open(owned..'/original/data/control.txt','wb'));f:write('changed after create');f:close()
   check('removed copied DIB after create',os.remove(assert(os.getenv('NTSD_BRIDGE_OWNED_DIB'))))
  end
  status('late completed-helper rollback',lib.ntsd_bridge_developer_front_rollback(h),C.NTSD_BRIDGE_UNSUPPORTED)
  check('late rollback whole owner bytes masks events revision',snapshot(h)==before)
  write('loaded-'..profile..'-rollback.json',snapshot(h))
  status('front settings actual continuation',lib.ntsd_bridge_load_front_settings(h),C.NTSD_BRIDGE_OK)
  local after,afterRevision=snapshot(h);write('loaded-'..profile..'-ready.json',after)
  status('ready info',lib.ntsd_bridge_info(h,phase,rev),C.NTSD_BRIDGE_OK)
  check('front ready phase single revision',phase[0]==3 and rev[0]==1 and afterRevision==1)
  local small=ffi.new('uint8_t[1]',0xa5);local n=ffi.new('uint32_t[1]',123);rev[0]=456
  status('loaded short snapshot',lib.ntsd_bridge_loaded_snapshot(h,small,1,n,rev),C.NTSD_BRIDGE_OUT_OF_BOUNDS)
  check('loaded short outputs preserved',small[0]==0xa5 and n[0]==123 and rev[0]==456)
  status('second front load rejected',lib.ntsd_bridge_load_front_settings(h),C.NTSD_BRIDGE_UNSUPPORTED)
  check('wrong lifecycle whole owner preserved',snapshot(h)==after)
  require('front_screen')(ffi,lib,check,status,h,profile,after,snapshot,write)
 end
 check('simultaneous distinct loaded handles',handles[1]~=handles[2] and lib.ntsd_bridge_live_sessions()==3)
 for _,h in ipairs(handles) do
  status('destroy loaded owner',lib.ntsd_bridge_destroy(h),C.NTSD_BRIDGE_OK)
  status('stale loaded call',lib.ntsd_bridge_load_front_settings(h),C.NTSD_BRIDGE_INVALID_HANDLE)
  status('stale first-menu call',lib.ntsd_bridge_continue_front_screen(h,0),C.NTSD_BRIDGE_INVALID_HANDLE)
  status('double destroy loaded',lib.ntsd_bridge_destroy(h),C.NTSD_BRIDGE_INVALID_HANDLE)
 end
 status('destroy parallel Actor',lib.ntsd_bridge_destroy(actor[0]),C.NTSD_BRIDGE_OK)
 check('complete loaded ownership release',lib.ntsd_bridge_live_sessions()==0)
end
