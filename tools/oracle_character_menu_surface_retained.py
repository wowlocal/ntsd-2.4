#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Seven controlled character-menu dimension-lifetime continuations.
Execute pinned NTSD/VC80 bitmap helpers and caller in Unicorn2.1.4 with the
unchanged CharacterMenuSurface harness. Ordinary allocation/image/COM failures
recover retained copy height/width and an unavailable first operand boundary.
All instructions/reads/writes/guards/cookie checks and actual API responses remain
observable. No private expected-byte import, control/protection corruption,
bypass, fault continuation, unrelated target or Windows/device claim. Research
only; see CHARACTER_MENU_SURFACE_RETAINED_PLAN.md for finite acceptance.
"""
import argparse, json, os
from pathlib import Path
from oracle_character_menu_surface import CharacterMenuSurface, EXE_SHA256, DLL_SHA256, TRACE_STACK, TRACE_SIZE, WORLD, digest

def specs():
 yield dict(kind='controlledMenu',label='retained-after-null-rface',nulls=[9],results={'description#10':-1})
 yield dict(kind='controlledMenu',label='retained-after-missing-rface',missing=[9],results={'description#10':-1})
 yield dict(kind='controlledMenu',label='retained-after-surface-rface',results={'createSurface#10':-1,'description#10':-1})
 yield dict(kind='controlledMenu',label='retained-after-key-rface',results={'colorKey#10':-1,'description#11':-1})
 yield dict(kind='controlledMenu',label='retained-after-description-rface',results={'description#10':-1,'description#11':-1})
 yield dict(kind='controlledMenu',label='first-description-unavailable',results={'description#1':-1})
 yield dict(kind='controlledMenu',label='first-unconsumed-then-retained',results={'description#1':-1,'getDC#1':-1,'description#11':-1})

if __name__ == '__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};assets={}
 for index,spec in enumerate(specs()):
  vm=CharacterMenuSurface();vm.capture_path=a.output;case=vm.run_menu(spec)
  part=parts/f'{index:04d}.json';temp=part.with_suffix('.tmp')
  temp.write_text(json.dumps(dict(case=case,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(case);blobs.update(vm.blobs);assets.update(vm.assets)
  print('completed',index,spec['label'],case['end'],len(case['events']),len(case['writes']),len(case['reads']),flush=True)
 doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,assets=assets,
          stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,worldToken=WORLD,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output)
 print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
