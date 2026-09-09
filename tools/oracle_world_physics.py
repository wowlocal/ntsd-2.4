#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Entire41e634..41eed1 with real40e490, constructors, RNG and sound.
Synthetic400-slot pool and four declared Objects, CW037f/legacy ftol2.
Full pool bytes/masks and globals SHA; real nested helper returns. No game
function is replaced; the established constructor memset boundary is retained.
"""
import argparse,base64,itertools,json,os,struct,subprocess,zlib
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_world_control import WorldControl,WORLD,POOL,BODY_SP,HEADER,d,b,q,digest,REGS
from unicorn import UC_MEM_WRITE,UcError
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EDI,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW
CALLS={0x40e490:(0,0),0x4061d0:(0,0),0x417170:(2,0),0x416fb0:(2,0),0x417090:(2,0),0x4450d0:(0,0)}
IDS=[30,31,998,999]
STATES={300:14,301:9998}
class WorldPhysics(WorldControl):
 arithmetic_control_word=0x37f # Historical default; precision revalidation supplies its own context.
 source_ids=IDS
 frame_states=STATES
 mutates_world=True
 def written(self,*args):
  if not self.running:super().written(*args)
 def access(self,uc,access,address,size,value,data):
  if self.running and WORLD<=address<WORLD+0x7d8 and access==UC_MEM_WRITE:
   assert WORLD+4<=address<address+size<=WORLD+404
   self.world_mask[address-WORLD:address-WORLD+size]=b'\1'*size;return
  super().access(uc,access,address,size,value,data)
 def execute(self):
  self.uc.reg_write(UC_X86_REG_FPCW,self.arithmetic_control_word);self.uc.mem_write(0x45971c,b'\0'*4);self.physics_slot=None
  self.uc.emu_start(0x41e634,0,count=2_000_000)
  assert self.uc.reg_read(UC_X86_REG_EDI)==400 and self.uc.reg_read(UC_X86_REG_FPCW)==self.arithmetic_control_word
 def code(self,uc,pc,size,data):
  if not self.running:return
  if pc==0x4450a0:return # only the established constructor memset boundary
  sp=uc.reg_read(UC_X86_REG_ESP)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop();assert sp==h['sp']+4 and h['saved']==[uc.reg_read(r) for r in REGS],h
   self.helpers+=1
   if h['entry']==0x417170:self.events.append(dict(slot=h['slot'],kind='random',arguments=h['args']+[uc.reg_read(UC_X86_REG_EAX)]))
   if h['entry']==0x40e490:self.physics_slot=None
  if pc==0x41eed1:
   assert not self.pending;self.finished=True;uc.emu_stop();return
  self.instructions.add(pc)
  if pc in CALLS:
   if pc==0x40e490:self.physics_slot=uc.reg_read(UC_X86_REG_EDI)
   slot=self.physics_slot if self.physics_slot is not None else uc.reg_read(UC_X86_REG_EDI)
   count,pop=CALLS[pc];args=[self.u32(sp+4+4*i) for i in range(count)]
   self.pending.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),args=args,slot=slot,saved=[uc.reg_read(r) for r in REGS]))
   if pc in (0x417090,0x416fb0):self.events.append(dict(slot=slot,kind='builtinSound' if pc==0x417090 else 'catalogSound',arguments=args))
   if pc==0x4061d0:
    self.target=uc.reg_read(UC_X86_REG_ECX);n,offset=divmod(self.target-POOL,0x500);assert offset==0 and 0<=n<400
    self.size=0x420;self.mask=self.masks[n];self.writes=[]
    self.events.append(dict(slot=slot,kind='reconstruct',arguments=[uc.reg_read(REGS[2])]))
  assert any(a<=pc<=e for a,e in [(0x41e634,0x41eecb),(0x40e490,0x40ef6a),(0x4061d0,0x406500),(0x416fb0,0x4171bc),(0x4450d0,0x44517a)]),hex(pc)
 def probe(self,item,index):
  try:return super().probe(item,index)
  except Exception:
   print('WORLD PHYSICS FAILURE',item['label'],flush=True);raise

def dead(slot=0,**patch):
 values={0x70:300,0xb4:1,0x2fc:0,0x2f4:0,0x364:1,8:1,0x30c:1,0x314:0};values.update({int(k):v for k,v in patch.items()})
 return [slot,[d(k,v) for k,v in values.items()]]
def probes():
 for slot,owner,team,wait,hp in itertools.product((0,19,20,399),(-1,0),(1,5),(-1,0,1,4,5),(-1,0,1)):
  a=dead(slot,**{'756':owner,'868':team,'8':wait,'764':hp})
  yield dict(group='death-gates',label=f'death-{slot}-{owner}-{team}-{wait}-{hp}',active=[[slot,255]],actors=[a])
 for slot,poolfull,missing,alias in itertools.product((0,49,50,399),(False,True),(False,True),(False,True)):
  activity={i:1 for i in range(50,400)} if poolfull else {};activity[slot]=1
  free=next((i for i in range(50,400) if i not in activity),None)
  actors=[dead(slot,**{'788':321,'784':3}),*[ [i,[d(0xb4,1)]] for i in activity if i!=slot]]
  yield dict(group='restore-spawn',label=f'spawn-{slot}-{poolfull}-{missing}-{alias}',active=list(activity.items()),actors=actors,count=2 if missing else 4,aliases=[[free,slot]] if alias and free is not None else [])
 for slot,activity,team,allyhp in itertools.product((0,19,20,399),(0,1,2,128),(1,2),(0,500)):
  ally=(slot+1)%400;fallback=(slot+2)%400
  yield dict(group='respawn',label=f'respawn-{slot}-{activity}-{team}-{allyhp}',active=[[slot,1],[ally,activity],[fallback,1]],
   actors=[dead(slot,**{'780':3}),[ally,[d(0xb4,1),d(0x364,team),d(0x2fc,allyhp),d(0x10,2147483647),d(0x18,-2147483648)]],[fallback,[d(0xb4,1),d(0x364,1),d(0x10,101),d(0x18,303)]]],globals=[d(0x450bcc,2999),d(0x450c34,1233)])
 for slot,target,progress,y,hp in itertools.product((0,199,399),(-2,-1,30,31,998,999,12345),(2,3),(0,-1),(0,500)):
  other=(slot+1)%400;earlier=(slot-1)%400
  yield dict(group='revert',label=f'revert-{slot}-{target}-{progress}-{y}-{hp}',active=[[slot,1],[other,255],[earlier,1]],actors=[[slot,[d(0xb4,1),d(0x324,target),b(0xdc,progress),d(0x14,y),d(0x2fc,hp)]],[other,[d(0xb4,1),d(0x2f4,slot),d(0x14,-1)]],[earlier,[d(0xb4,1),d(0x2f4,slot)]]])
 for alias,owner in itertools.product((False,True),(-1,0)):
  yield dict(group='deactivate-revert',label=f'deactivate-{alias}-{owner}',active=[[0,1],[1,1]],aliases=[[1,0]] if alias else [],actors=[[0,[d(0x70,301),d(0xb4,1),d(0x324,31),b(0xdc,3),d(0x2f4,owner)]]])
 for count in (-1,0,1,2,4):
  yield dict(group='revert-count',label=f'count-{count}',count=count,active=[[0,1]],actors=[[0,[d(0xb4,1),d(0x324,31),b(0xdc,3)]]])
 yield dict(group='all-slots',label='all-slots-real-physics',active=[[i,1] for i in range(400)])
 yield dict(group='empty',label='empty')

def fault_witness():
 vm=WorldPhysics();case=dict(label='respawn-with-no-other-active-slot',active=[[0,1]],actors=[dead(0,**{'780':2})])
 try:
  vm.probe(case,0)
  raise AssertionError('Expected original idiv fault')
 except UcError as error:
  pc=vm.uc.reg_read(UC_X86_REG_EIP);assert pc==0x41eb98
  report=dict(exeSHA256=EXE_SHA256,scope='Original World physics caller: zero eligible teammates divides by zero AFTER the first real RNG call. Source-only fault witness; native rollback is a separate unsupported-path policy.',nativeCompared=False,entry=0x41e634,faultPC=pc,error=str(error),case=case,events=vm.events,after=dict(rngIndex=vm.u32(0x450bcc),rngCounter=vm.u32(0x450c34),lives=vm.u32(POOL+0x30c),freeze=vm.u32(POOL+0xb4)))
  assert report['after']==dict(rngIndex=1,rngCounter=1,lives=1,freeze=0)
  assert vm.events==[dict(slot=0,kind='random',arguments=[144,51,3])]
  (ROOT/'docs/evidence/world-physics-no-allies.json').write_text(json.dumps(report,indent=2)+'\n')
  print(json.dumps(report,indent=2),flush=True)

def main():
 p=argparse.ArgumentParser(description=__doc__);m=p.add_mutually_exclusive_group();m.add_argument('--accept',action='store_true');m.add_argument('--fault',action='store_true');a=p.parse_args()
 if a.fault:return fault_witness()
 path=ROOT/'build/original/world-physics.json';report_path=ROOT/'build/research/world-physics.json'
 if a.accept:
  raw=path.read_bytes();report=json.loads(report_path.read_bytes());assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
 else:
  vm=WorldPhysics();cases=[]
  for i,item in enumerate(probes()):
   cases.append(vm.probe(item,i))
   if (i+1)%250==0:print('WORLD PHYSICS',i+1,flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,header=HEADER,ids=IDS,states=STATES,cases=cases,instructions=sorted(vm.instructions))
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),instructions=len(vm.instructions),nativeCompared=False)
  report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 if a.accept:
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalWorldPhysicsTests/testEntirePhysicsCaller'],env=dict(os.environ,NTSD_WORLD_PHYSICS_CORPUS=str(path)),check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-world-physics.json';fixture.write_bytes(packed)
  report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/world-physics.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
