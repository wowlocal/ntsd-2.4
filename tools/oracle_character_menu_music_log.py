#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Seven continuous menu music-log/first-GetObject lifetime controls.
Pinned NTSD EXE/VC80/main-track name/11DIBs, Unicorn2.1.4, original prologue,
music helpers, sprintf, bitmap helpers and memset on one CPU. Declared caller,
PTD, allocator and COM/Win32 responses recover ordered ownership and shared
stack provenance. Full stack/SEH/globals/music/bitmap bytes and write/read masks
are observations, never native expected-state inputs. Ordinary failure controls
and unknown consumed operands remain distinct boundaries. Normal cookie/guard
checks execute unchanged; no control/protection corruption, bypass, source-fault
continuation, unrelated system or Windows/device claim. Research only; see
CHARACTER_MENU_MUSIC_LOG_PLAN.md. Stop at429e5a, not a whole menu return.
"""
import argparse,json,os
from pathlib import Path
from oracle_character_menu_music_surface import CharacterMenuMusicSurface,EXE_SHA256,DLL_SHA256,TRACE_STACK,TRACE_SIZE,STACK,WORLD,digest

def specs():
 for label,extra in [
  ('object-after-render-negative',dict(music=dict(renderResult=-1))),
  ('object-after-null-wide',dict(music=dict(nullAllocation=True))),
  ('object-after-create-negative',dict(music=dict(createResult=-1,createPointer=0))),
  ('object-after-cached',dict(cached=True)),
  ('object-after-disabled',dict(musicEnabled=0)),
  ('object-after-empty-directory',dict(directory='')),
  ('object-after-long-directory',dict(directory='A'*40))]:
  yield dict(kind='controlledMenuMusicSurface',label=label,results={'getObject#1':0},**extra)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);a=p.parse_args()
 assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};assets={}
 for i,s in enumerate(specs()):
  if a.limit is not None and i>=a.limit:break
  vm=CharacterMenuMusicSurface();vm.capture_path=a.output;c=vm.run_join(s)
  part=parts/f'{i:04d}.json';temp=part.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(c);blobs.update(vm.blobs);assets.update(vm.assets);print('completed',i,s['label'],c['end'],len(c['events']),len(c['writes']),len(c['reads']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,assets=assets,stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,fullStackAddress=STACK,fullStackCount=0x10000,worldToken=WORLD,crtDataAddress=vm.db,crtDataCount=vm.ds,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
