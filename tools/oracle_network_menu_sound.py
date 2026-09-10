#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole NTSD network menus with explicitly enabled sound-device API bindings.

Pinned EXE/lib.dll/VC80 on Unicorn2.1.4. The original library installer, fresh
menu parent, whole caller, sound instructions and output tails execute. Bind
existing controlled COM objects and device flag before subsequent callers;
this is not recovered Windows/audio initialization or audible-device evidence.
Observe real play requests, ignored COM failures and failed GetDC continuation.
Preserve the separately published device-absent matrices and all their bytes.
"""
import argparse,json,os
from pathlib import Path
from import_ntsd import ROOT
from oracle_network_menu import NetworkMenu,SOURCE,PRODUCER_SHA256 as BASE_PRODUCER
from oracle_bitmap_drawing import digest

class SoundMenu(NetworkMenu):
 def __init__(self,control):self.sound_result=0;super().__init__(control)
 def code(self,uc,pc,size,data):
  # Change only the declared API response input, before any UI instruction.
  if getattr(self,'network_active',False):self.menu_input['methodResult']=self.sound_result
  super().code(uc,pc,size,data)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--control',action='store_true');a=p.parse_args()
 path=ROOT/a.output;assert not path.exists();parts=path.with_suffix('.parts');parts.mkdir(exist_ok=False)
 source_sha=digest(Path(__file__).read_bytes());vm=SoundMenu(a.control);d=vm.parent_capture();d.update(scope=__doc__,suite='sound',producerSHA256=source_sha,baseProducerSHA256=BASE_PRODUCER)
 pins=[];known=set()
 def save(value):
  additions={k:v for k,v in vm.blobs.items() if k not in known};known.update(additions);raw=(json.dumps(dict(value=value,blobs=additions),separators=(',',':'))+'\n').encode();name=f'{len(pins):04d}.json';temp=parts/(name+'.tmp');temp.write_bytes(raw);os.replace(temp,parts/name);pins.append(dict(path=name,sha256=digest(raw),bytes=len(raw)));temp=parts/'index.tmp';temp.write_text(json.dumps(pins,indent=2)+'\n');os.replace(temp,parts/'index.json')
 save(d);mouse=lambda x,y,h:[(0x4546f0,x),(0x453cdc,y),(0x457580,h)]
 calls=[]
 def plain(label,stimulus=()):
  c=dict(loop=vm.loop_step(label,stimulus));calls.append(c);save(c)
 def ui(label,stimulus=(),failed=False):
  vm.sound_result=-1 if failed else 0;before=vm.loop_step(label,stimulus);assert before['continuation']=='otherSelector'
  network=vm.network_step(label,dc_result=-1 if failed else 0,draw_result=-1 if failed else 0);tail=vm.finish_network(label);c=dict(loop=before,network=network,tail=tail);calls.append(c);save(c)
 plain('next-natural-frame')
 bindings=[(0x45560c+4*i,SOURCE+16*i) for i in range(5)]+[(0x44eecc,SOURCE)]
 d['platformAudioBindings']=[dict(address=p,value=v) for p,v in bindings]
 plain('controlled-enabled-audio-device-binding',mouse(0,0,0)+bindings)
 plain('open-network',mouse(300,252,1))
 for label,stimulus in [('choice-idle',mouse(0,0,0)),('choose-client',mouse(300,310,1)),('client-idle',mouse(0,0,0)),('client-type',[(0x455378+65,b'\x64')]),('client-enter',[(0x455385,b'\x64')]),('client-connect',[]),('controlled-host-choice',mouse(300,280,1)+[(0x44d064,1)]),('server-idle',mouse(0,0,0)),('server-dots',[(0x4511d4,3)]),('server-back',mouse(400,370,1)),('choice-release',mouse(0,0,0)),('choice-cancel',mouse(400,345,1))]:ui(label,stimulus)
 plain('main-after-network-cancel',mouse(0,0,0))
 for label,selector,x,y in [('failed-sound-host',1,300,280),('failed-sound-server-back',2,400,370),('failed-sound-forum',1,400,470),('failed-sound-client-enter',3,300,370)]:
  ui(label,mouse(x,y,1)+[(0x44d060,0),(0x44d064,selector),(0x455378,bytes(300)),(0x4511b0,0)],True)
 d.update(calls=calls,sources=list(vm.background_sources.values()),blobs=vm.blobs,checkpointParts=pins)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path)
 print(json.dumps(dict(path=str(path.relative_to(ROOT)),sha256=digest(raw),bytes=len(raw),sourceSHA256=source_sha,baseSourceSHA256=BASE_PRODUCER,calls=len(calls),soundMethods=sum(e['kind']=='soundMethod' for c in calls if 'network' in c for e in c['network']['events']),nativeCompared=False),indent=2))
if __name__=='__main__':main()
