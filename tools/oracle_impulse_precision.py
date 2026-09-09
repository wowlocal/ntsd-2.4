#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole4196f0 under explicit CW007f/027f/037f on all1030 declared controls.
Original instructions and full pools/masks/writes. The64-bit slice reproduces
the accepted historical corpus exactly; other slices change only CPU precision.
"""
import json,struct
from oracle_world_impulses import WorldImpulses,probes,ROOT,EXE_SHA256,digest,WORLD,BODY_SP,REGS,STOP
from unicorn.x86_const import UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW
class Impulses(WorldImpulses):
 def execute(self):
  saved=[self.uc.reg_read(r) for r in REGS]
  self.uc.mem_write(BODY_SP-4,struct.pack('<I',STOP));self.uc.reg_write(UC_X86_REG_ESP,BODY_SP-4);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  self.uc.reg_write(UC_X86_REG_FPCW,self.fpcw);self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.emu_start(0x4196f0,STOP,count=20000)
  assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and [self.uc.reg_read(r) for r in REGS]==saved
  assert self.uc.reg_read(UC_X86_REG_FPCW)==self.fpcw and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  self.finished=True
def main():
 r=json.loads((ROOT/'docs/evidence/world-impulses.json').read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
 assert digest(raw)==r['sha256'] and digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/r['fixture']).read_bytes())==r['fixtureSHA256']
 parent=json.loads(raw);old={c['label']:c for c in parent['cases']};vm=Impulses();cases=[];changes={0x7f:0,0x27f:0,0x37f:0}
 for n,item in enumerate(probes()):
  for cw in changes:
   vm.fpcw=cw;case=vm.probe(item,n)
   if cw==0x37f:assert case==old[item['label']]
   changes[cw]+=case['poolSHA256']!=old[item['label']]['poolSHA256']
   case['fpcw']=cw;cases.append(case)
 doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,cases=cases,instructions=sorted(vm.instructions),historical=dict(fixture=r['fixture'],sha256=r['fixtureSHA256']))
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original/impulse-precision.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),writes=sum(len(c['events']) for c in cases),changedPoolsFrom64=changes,historical=doc['historical'],nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
