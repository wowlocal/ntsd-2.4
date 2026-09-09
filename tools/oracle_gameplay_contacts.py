#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continue own gameplay through caller41eed8 and whole419380/4064d0.
Freshly reproduces all menu/loading/launch/control/physics/held-object parents
on the same CPU/stack. No gameplay stimuli or imported expected state.
Stops41eefb before item/hit-resolution passes; not a full tick or match.
"""
import argparse,json
from oracle_gameplay_links import GameplayLinks
from oracle_gameplay_entry import ROOT,EXE_SHA256,DLL_SHA256,WORLD,REGISTERS,digest,capture_startup,transport
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_ESP
HELPERS={0x419380:(1,4),0x417200:(2,8),0x417400:(3,12),0x4171c0:(8,0),0x417170:(2,0),0x4064d0:(0,0),0x4061d0:(0,0),0x4034e0:(1,0)}
class GameplayContacts(GameplayLinks):
 def gameplay_code(self,uc,pc,size,data):
  if not self.gameplay_running or self.gameplay_label!='contacts':return super().gameplay_code(uc,pc,size,data)
  self.gameplay_instructions.add(pc);sp=uc.reg_read(UC_X86_REG_ESP)
  while self.gameplay_pending and pc==self.gameplay_pending[-1]['returnPC']:
   h=self.gameplay_pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS],h
   h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.gameplay_helpers.append(h)
  if pc==self.gameplay_stop:
   assert not self.gameplay_pending;self.gameplay_finished=True;uc.emu_stop();return
  if pc in HELPERS:
   count,pop=HELPERS[pc]
   self.gameplay_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=pop,this=uc.reg_read(UC_X86_REG_ECX),arguments=[self.u32(sp+4+4*i) for i in range(count)],saved=[uc.reg_read(r) for r in REGISTERS]))
  assert any(a<=pc<=b for a,b in [(0x41eed8,0x41eefb),(0x419380,0x4196df),(0x417170,0x4173fa),(0x417400,0x417f7b),(0x4061d0,0x406a1f),(0x4034e0,0x4034ea)]),hex(pc)
 def capture_character(self,parent):
  old=super().capture_character(parent);suffix='-control' if self.control else ''
  report=json.loads((ROOT/'docs/evidence'/f'gameplay-links{suffix}.json').read_bytes())
  raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and json.loads(raw)==json.loads(json.dumps(old))
  assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
  print('Entire pinned GAMEPLAY_LINKS reproduced; continuing whole contacts/fusion',flush=True)
  section=self.gameplay_step('contacts',0x41eed8,0x41eefb)
  return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
   parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),worldAddress=WORLD,
   actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=[section]),{**self.early.blobs,**self.blobs})
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');a=p.parse_args()
 doc=capture_startup(a.control,vm_type=GameplayContacts,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'gameplay-contacts{suffix}.json';path.write_bytes(raw)
 c=doc['cases'][0];report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),parent=doc['parent'],nativeCompared=False,
  end=c['end'],helpers=len(c['helpers']),checkpoints=len(c['checkpoints']),instructions=len(c['instructions']),readsBeforeWrites=c['readsBeforeWrites'])
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
