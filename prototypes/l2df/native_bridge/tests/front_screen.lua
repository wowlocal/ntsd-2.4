return function(ffi,lib,check,status,h,profile,before,snapshot,write)
 local C=ffi.C
 status('complete first-menu sequence rejects before commit',lib.ntsd_bridge_developer_screen_rollback(h,0),C.NTSD_BRIDGE_UNSUPPORTED)
 check('first-menu rollback entire owner',snapshot(h)==before)
 write('front-'..profile..'-rollback.json',snapshot(h))
 status('actual first-menu return',lib.ntsd_bridge_continue_front_screen(h,0),C.NTSD_BRIDGE_OK)
 local after,revision=snapshot(h);write('front-'..profile..'-returned.json',after)
 local phase,rev=ffi.new('uint32_t[1]'),ffi.new('uint64_t[1]')
 status('first-menu owner info',lib.ntsd_bridge_info(h,phase,rev),C.NTSD_BRIDGE_OK)
 check('first-menu lifecycle4 one additional commit',phase[0]==4 and rev[0]==2 and revision==2)
 status('repeat first-return rejects',lib.ntsd_bridge_continue_front_screen(h,0),C.NTSD_BRIDGE_UNSUPPORTED)
 check('repeat first-return preserves owner',snapshot(h)==after)
 -- Independent owner takes the valid path without the deliberate late failure.
 local root=assert(os.getenv('NTSD_BRIDGE_RESOURCE_ROOT'))
 local fresh=ffi.new('uint64_t[1]')
 status('fresh comparison owner',lib.ntsd_bridge_create_pristine(1,root,#root,profile,fresh),C.NTSD_BRIDGE_OK)
 status('fresh front-settings',lib.ntsd_bridge_load_front_settings(fresh[0]),C.NTSD_BRIDGE_OK)
 check('fresh independent ready state',snapshot(fresh[0])==before)
 status('fresh first-menu return',lib.ntsd_bridge_continue_front_screen(fresh[0],0),C.NTSD_BRIDGE_OK)
 local independent=snapshot(fresh[0]);write('front-'..profile..'-fresh.json',independent)
 check('rollback then continuation equals independent owner',independent==after)
 status('release independent comparison owner',lib.ntsd_bridge_destroy(fresh[0]),C.NTSD_BRIDGE_OK)
 if profile==0 then
  -- This separately declared input COPY is owned after its constructor request.
  check('remove copied background after completed request',os.remove(assert(os.getenv('NTSD_BRIDGE_OWNED_BACKGROUND'))))
  check('retained background bytes remain owned after file removal',snapshot(h)==after)
  write('front-0-after-resource-removal.json',snapshot(h))
 end
end
