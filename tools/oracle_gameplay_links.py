#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continue both own gameplay control/physics stages through whole417f80.
The same CPU/stack/World/catalog/resources/replay comes from freshly reproduced
MATCH_LAUNCH and GAMEPLAY_ENTRY parents. No new gameplay stimuli or synthetic
calls. Stops41eed8 before contact collection; not a complete tick or match.
"""
import argparse,json
from oracle_gameplay_entry import GameplayEntry,ROOT,EXE_SHA256,DLL_SHA256,WORLD,REGISTERS,digest,capture_startup,transport
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_ESP
HELPERS={0x417f80:(0,0),0x4450d0:(0,0),0x417170:(2,0)}
class GameplayLinks(GameplayEntry):
 def gameplay_code(self,uc,pc,size,data):
  if not self.gameplay_running or self.gameplay_label!='depth-attachments':return super().gameplay_code(uc,pc,size,data)
  self.gameplay_instructions.add(pc);sp=uc.reg_read(UC_X86_REG_ESP)
  while self.gameplay_pending and pc==self.gameplay_pending[-1]['returnPC']:
   h=self.gameplay_pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS],h
   h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.gameplay_helpers.append(h)
  if pc==self.gameplay_stop:
   assert not self.gameplay_pending;self.gameplay_finished=True;uc.emu_stop();return
  if pc in HELPERS:
   count,pop=HELPERS[pc]
   self.gameplay_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=pop,this=uc.reg_read(UC_X86_REG_ECX),arguments=[self.u32(sp+4+4*i) for i in range(count)],saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc==0x41800e:
   slot=uc.reg_read(REGISTERS[2]);assert 0<=slot<400
   self.gameplay_checkpoints.append(dict(label='depth-return',pc=pc,slot=slot,actor=self.record(self.pool[slot])))
  assert pc in (0x41eed1,0x41eed3) or any(a<=pc<=b for a,b in [(0x417f80,0x41879e),(0x4450d0,0x44517a),(0x417170,0x4171bc)]),hex(pc)
 def capture_character(self,parent):
  old=super().capture_character(parent);suffix='-control' if self.control else ''
  source=json.loads((ROOT/'docs/evidence'/f'gameplay-entry{suffix}.json').read_bytes())
  raw=(ROOT/'build/original'/source['corpus']).read_bytes()
  assert digest(raw)==source['sha256'] and len(raw)==source['bytes'] and json.loads(raw)==json.loads(json.dumps(old))
  print('Entire pinned GAMEPLAY_ENTRY reproduced; continuing whole417f80',flush=True)
  section=self.gameplay_step('depth-attachments',0x41eed1,0x41eed8)
  report=json.loads((ROOT/'docs/evidence'/f'gameplay-physics{suffix}.json').read_bytes())
  assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
  return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
   parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),worldAddress=WORLD,
   actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=[section]),{**self.early.blobs,**self.blobs})
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');a=p.parse_args()
 doc=capture_startup(a.control,vm_type=GameplayLinks,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'gameplay-links{suffix}.json';path.write_bytes(raw)
 c=doc['cases'][0];report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),parent=doc['parent'],nativeCompared=False,
  end=c['end'],helpers=len(c['helpers']),checkpoints=len(c['checkpoints']),instructions=len(c['instructions']),readsBeforeWrites=c['readsBeforeWrites'])
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
