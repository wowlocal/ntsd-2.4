#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""INCOMPLETE ordinary catalog fopenNULL response on the own application CPU.
Pinned NTSD EXE/lib/VC80, original resources, Unicorn2.1.4 development tooling.
Recover the game's resource/open/error order after its own startup/menu/common
loading. Supply NULL for the declared data/data.txt fopen response, leaving
errno/globals and original files unchanged. Stop at the actual feof(NULL) entry
before that instruction executes by default. --continue-crt instead executes
the actual feof/errno/invalid-parameter selection to Watson entry or an unknown
boundary. No handler/encoded-pointer/protective-state edits, fault continuation,
Windows/device execution or native success claim. The nominal capture is independent.
"""
import argparse,json,os
from pathlib import Path
from unicorn.x86_const import UC_X86_REG_ESP
from oracle_application_catalog import ApplicationCatalog,BitmapSurface,OPEN,EOF,EXE_SHA256,DLL_SHA256,LIB_SHA256,trace_json,digest

class CatalogFileFailure(ApplicationCatalog):
 def __init__(self):
  self.failed_open=None;self.null_entry=None;self.continue_crt=False
  super().__init__()
 def code(self,u,pc,n,data):
  if self.catalog_active:
   sp=u.reg_read(UC_X86_REG_ESP)
   if pc==OPEN:
    path=self.cstr(self.u32(sp+4)).decode('latin1');mode=self.cstr(self.u32(sp+8)).decode('latin1')
    assert path=='data\\data.txt' and mode=='r' and self.failed_open is None
    assert self.u32(sp)==0x41255b
    self.failed_open=dict(path=path,mode=mode,sp=sp,returnPC=self.u32(sp),result=0,errnoChanged=False)
    self.catalog_event('openFileFailure',[0],path=path,mode=mode,result=0,errnoChanged=False)
    self.ret(0);return
   if self.failed_open is not None and pc==0x78138945:
    self.catalog_event('crtInvalidParameterBoundary',[self.u32(sp+4+4*i) for i in range(5)],returnPC=self.u32(sp),executed=False)
    self.dependency=dict(kind='crtInvalidParameterBoundary',pc=pc,sp=sp,returnPC=self.u32(sp),arguments=[self.u32(sp+4+4*i) for i in range(5)],instructionExecuted=False)
    u.emu_stop();return
   if self.null_entry is not None and pc==0x412564:
    self.dependency=dict(kind='nullFileCRTReturn',pc=pc,sp=sp,instructionExecuted=False)
    u.emu_stop();return
   if pc==EOF and self.failed_open is not None:
    assert self.u32(sp+4)==0 and self.u32(sp)==0x412564
    assert self.null_entry is None
    self.null_entry=dict(pc=pc,sp=sp,returnPC=self.u32(sp),arguments=[0])
    self.catalog_event('nullFileEOFEntry',[0],returnPC=self.u32(sp),executed=self.continue_crt)
    if self.continue_crt:
     self.resource_active=True
     try:return BitmapSurface.code(self,u,pc,n,data)
     finally:self.resource_active=False
    self.dependency=dict(kind='nullFileCRTEntry',pc=pc,sp=sp,returnPC=self.u32(sp),arguments=[0],instructionExecuted=False)
    u.emu_stop();return
  return super().code(u,pc,n,data)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--continue-crt',action='store_true');a=p.parse_args();assert not a.output.exists()
 vm=CatalogFileFailure();vm.continue_crt=a.continue_crt;vm.capture_path=a.output;vm.scan_limit=None;vm.decoder_limit=None;vm.object_limit=None;vm.compact_states=False;vm.max_chunks=2;vm.checkpoint_every=0
 parents,prefix,c=vm.run_catalog(0);assert c['dependency'] is not None and not vm.file_handles and not vm.objects
 c['failedOpen']=vm.failed_open;c['nullFileEntry']=vm.null_entry;c['continuedCRT']=vm.continue_crt
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,libSHA256=LIB_SHA256,parents=parents,prefix=prefix,case=c,blobs=vm.blobs,assets=vm.assets,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'),default=trace_json)+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output)
 print(dict(end=c['end'],dependency=c['dependency'],bytes=len(raw),sha256=digest(raw)),flush=True)
