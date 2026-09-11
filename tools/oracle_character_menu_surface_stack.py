#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Full-stack observation of the existing27 controlled menu-surface cases.
The independent verifier found ordinary constructor-unwind state stores at
callerSP+aa0 outside the inherited d000..f400 snapshot, although all such stores
were already traced. Repeat the finite27 controls with an expanded read-only
snapshot of the existing mapped stack and its historical write mask. The
reference NTSD/VC80/DIBs, Unicorn2.1.4, allocation/API inputs, frame, code hooks,
guards and normal cookie checks remain identical. Do not modify stack bytes,
protection structures, expected outputs or live producers. Independently require
every old observation unchanged after removing only the added full-stack fields.
This is a snapshot-completeness study, not a fault retry, whole menu return,
native private-ABI comparison or Windows/device claim. Research execution only;
see CHARACTER_MENU_SURFACE_PLAN and CHARACTER_MENU_SURFACE_RETAINED_PLAN.
"""
import argparse,json,os
from pathlib import Path
from oracle_character_menu_surface import CharacterMenuSurface,EXE_SHA256,DLL_SHA256,TRACE_STACK,TRACE_SIZE,WORLD,STACK,digest,specs as initial_specs
from oracle_character_menu_surface_retained import specs as retained_specs

class FullStackMenuSurface(CharacterMenuSurface):
 def snapshot_menu(self):
  result=super().snapshot_menu()
  result.update(fullStack=self.blob(self.uc.mem_read(STACK,0x10000)),fullKnownStack=self.blob(self.stack_known))
  return result

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};assets={}
 for index,spec in enumerate([*initial_specs(),*retained_specs()]):
  vm=FullStackMenuSurface();vm.capture_path=a.output;case=vm.run_menu(spec)
  part=parts/f'{index:04d}.json';temp=part.with_suffix('.tmp')
  temp.write_text(json.dumps(dict(case=case,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(case);blobs.update(vm.blobs);assets.update(vm.assets)
  print('completed',index,spec['label'],case['end'],len(case['events']),len(case['writes']),len(case['reads']),flush=True)
 doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,assets=assets,
          stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,fullStackAddress=STACK,fullStackCount=0x10000,worldToken=WORLD,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output)
 print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
