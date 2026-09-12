#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""INCOMPLETE ordinary file-close response control for the first own Object.
Pinned NTSD EXE/lib/VC80 and original resources on Unicorn2.1.4, development only.
Recover whether DAT/Object callers preserve loading and cleanup after declared
read-file fclose and output-descriptor _close return -1. Read fclose is an
existing API boundary; output fclose executes actual VC80. Successful opens,
translated reads and writes remain unchanged. Responses change no errno/global
or protective state; retain actual CRT writes/returns and stop on the first
Object ret16, unknown boundary or failure. No TLS response, pointer/protection
edit, fault continuation, host file write, Windows/device or native-match claim.
The three nominal captures are independent and must not be restarted.
"""
import argparse,json,os
from pathlib import Path
from unicorn.x86_const import UC_X86_REG_ESP
from oracle_application_catalog import ApplicationCatalog,CLOSE,CLOSE_FILE,EXE_SHA256,DLL_SHA256,LIB_SHA256,trace_json,digest

class CatalogCloseFailure(ApplicationCatalog):
 def __init__(self):
  self.close_responses=[]
  super().__init__()
 def code(self,u,pc,n,data):
  if self.catalog_active:
   sp=u.reg_read(UC_X86_REG_ESP)
   if pc==CLOSE:
    token=self.u32(sp+4);h=self.file_handles[token]
    if h['mode']=='r':
     assert not h['closed'] and self.u32(sp) in (0x414a03,0x41229a)
     q=dict(kind='readFileClose',file=token,path=h['path'],sp=sp,returnPC=self.u32(sp),result=-1,errnoChangedByResponse=False)
     self.close_responses.append(q);h['closed']=True
     self.catalog_event('closeReadFile',[token],result=-1,errnoChangedByResponse=False)
     self.ret(0xffffffff);return
   if pc==CLOSE_FILE:
    assert self.u32(sp+4)==0xffffffff and self.output_pending['kind']=='close'
    token=self.output_pending['file'];h=self.file_handles[token]
    assert h['mode']=='w' and not h['closed']
    q=dict(kind='outputDescriptorClose',file=token,path=h['path'],sp=sp,returnPC=self.u32(sp),result=-1,errnoChangedByResponse=False)
    self.close_responses.append(q)
    self.catalog_event('closeOutputDescriptor',[0xffffffff,token],result=-1,errnoChangedByResponse=False)
    self.ret(0xffffffff);return
  return super().code(u,pc,n,data)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 vm=CatalogCloseFailure();vm.capture_path=a.output;vm.scan_limit=None;vm.decoder_limit=None;vm.object_limit=1;vm.compact_states=True;vm.max_chunks=1000;vm.checkpoint_every=0
 parents,prefix,c=vm.run_catalog(0);c['closeResponses']=vm.close_responses
 assert c['dependency']['kind']=='probeObjectLimit' and len(vm.close_responses)==4
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,libSHA256=LIB_SHA256,parents=parents,prefix=prefix,case=c,blobs=vm.blobs,assets=vm.assets,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'),default=trace_json)+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output)
 print(dict(end=c['end'],dependency=c['dependency'],closeResponses=vm.close_responses,bytes=len(raw),sha256=digest(raw)),flush=True)
