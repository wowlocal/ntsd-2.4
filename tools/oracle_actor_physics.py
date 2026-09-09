#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole40e490 with actual sound416fb0/417090 and conversion4450d0.
Declared synthetic Actors/Objects/Frames/globals, original constructors,
x87 round-to-nearest64-bit significand (CW037f), no game/helper stubs.
Entire Actor bytes/masks, globals SHA and ordered sound requests are compared.
This does not cover the World death/spawn caller or complete match physics.
"""
import argparse,base64,itertools,json,math,os,random,struct,subprocess,zlib
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_actor_control import ActorControl,HEADER,STATES,d,b,f,q,digest,REGS
from unicorn.x86_const import UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW
EXTRA_HEADER=[d(0x94,3),d(0xa8,-1)]
class ActorPhysics(ActorControl):
 def probe(self,item,index):
  item=dict(item,actor=[d(0x31c,20),*item.get('actor',[])])
  try:return super().probe(item,index)
  except Exception:
   print('PHYSICS FAILURE',item['label'],flush=True);raise
 def object_bytes(self,item):
  return super().object_bytes(dict(item,header=EXTRA_HEADER+item.get('header',[])))
 def execute(self,item):
  # Explicit CPU contract, separately from game globals. Both ftol2 CPU paths
  # are probed, but the original arithmetic instructions retain CW037f.
  self.uc.reg_write(UC_X86_REG_FPCW,0x37f);self.uc.mem_write(0x45971c,struct.pack('<I',item.get('sse2',0)))
  self.call(0x40e490)
  assert self.uc.reg_read(UC_X86_REG_FPCW)==0x37f
  assert (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
 def code(self,uc,pc,size,data):
  if not self.running:return
  sp=uc.reg_read(UC_X86_REG_ESP)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop();assert sp==h['sp']+4 and [uc.reg_read(r) for r in REGS]==h['saved'],h
  if pc==self.until:
   assert not self.pending;uc.emu_stop();return
  self.instructions.add(pc)
  if pc in (0x416fb0,0x417090,0x4450d0):
   self.pending.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in REGS]))
   if pc!=0x4450d0:self.events.append(dict(kind='catalogSound' if pc==0x416fb0 else 'builtinSound',arguments=[self.u32(sp+4),self.u32(sp+8)]))
  assert any(a<=pc<=e for a,e in [(0x40e490,0x40ef6a),(0x416fb0,0x417162),(0x4450d0,0x44517a)]),hex(pc)

def scenario(label,group='motion',state=3,number=0,kind=0,id=2,actor=(),frames=(),header=(),**other):
 return dict(label=label,group=group,actor=[d(0x70,number),*actor],frames=[f(number,8,state),*frames],header=[d(0x6f8,kind),d(0x6f4,id),*header],**other)
def probes():
 for kind,state,vy,vx in itertools.product((0,1,2,3,4,5,6),(0,6,12,13,18,100,1000,1002),(-20,-9,-1,0,0.0001,0.0002,1,8.5,9,9.9,11,12,17,17.1,30),(-12,-9,0,9,12)):
  yield scenario(f'matrix-{kind}-{state}-{vy}-{vx}',group='type-state',kind=kind,state=state,number=180 if state==12 else 200 if state in (13,18) else 0,
   actor=[d(0x14,-1),q(0x40,vx),q(0x48,vy),q(0x60,0),d(0x320,10),d(0x31c,20)])
 for kind,id,y in itertools.product((0,1,3,4,6),(2,101,120,124,999),(-100,-1,-0.00010001,-0.0001,0,0.0001)):
  yield scenario(f'gravity-{kind}-{id}-{y}',group='gravity',kind=kind,id=id,state=1002,actor=[q(0x60,y),q(0x48,0),d(0x14,-1),q(0x40,13.7)])
 for offset,value,iy in itertools.product((0x40,0x50),(-1.0002,-1.0001,-1,-0.9999999999999999,-0.9999,-0.1,-0.0001,-0.0,0.0,0.0001,0.1,0.9999,1,1.0001,1.0002),(-1,0)):
  yield scenario(f'friction-{offset}-{value}-{iy}',group='friction',kind=3,actor=[q(offset,value),q(0x60,-1),d(0x14,iy)])
 for kind,id,mask,flag in itertools.product((0,3,4),(2,101,120),range(16),(1,2)):
  yield scenario(f'blocks-{kind}-{id}-{mask}-{flag}',group='blocking',kind=kind,id=id,actor=[q(0x40,1 if mask&1 else -1),q(0x50,1 if mask&2 else -1),d(0x14,-1),*[d(o,flag if mask>>i&1 else 0) for i,o in enumerate((0x3e8,0x3ec,0x3f0,0x3f4))]])
 for freeze,carried,cpoint in itertools.product((-2147483648,-2,-1,0,1,2,2147483647),(-2,-1,0,2),(0,1,2,3)):
  yield scenario(f'gates-{freeze}-{carried}-{cpoint}',group='gates',actor=[d(0xb4,freeze),d(0x98,carried),d(0x320,23)],frames=[f(0,0x88,cpoint)])
 for number,vy,hurt,counter in itertools.product((179,180,184,185,186,190,191,200,204,205),(-20,-9.7,-9.699999999999998,-.7,6.3,10.3,12),(0,-1),(5,6)):
  yield scenario(f'air-{number}-{vy}-{hurt}-{counter}',group='air-frames',number=number,state=18 if number>=200 else 12,actor=[d(0x14,-1),q(0x60,-100),q(0x48,vy),d(0x320,hurt)],globals=[d(0x450bd0,counter)])
 for state,number,hurt,divisor in itertools.product((12,13,18),(180,185,186,191,212),(-2147483648,-101,-1,0,1,101,2147483647),(-2147483648,-100,-1,0,1,33,100,2147483647)):
  yield scenario(f'damage-{state}-{number}-{hurt}-{divisor}',group='damage',state=state,number=number,actor=[q(0x60,1),q(0x48,20),q(0x40,12),d(0x14,-1),d(0x320,hurt),d(0x340,divisor),d(0x2fc,-2147483648),d(0x300,2147483647)])
 for kind,state,vy,facing,sound in itertools.product((1,2,4,6),(1000,1002),(9,10,20),(0,1,2,255),(-1,0,399)):
  yield scenario(f'weapon-{kind}-{state}-{vy}-{facing}-{sound}',group='weapon',kind=kind,state=state,actor=[q(0x60,1),q(0x48,vy),q(0x40,3.1),d(0x14,-1),b(0x80,facing),d(0x2fc,0)],header=[d(0xa8,sound)])
 for number,state,y,vy in itertools.product((0,212),(0,6,100),(-0.0001,0,0.0001,0.00010001),(-.0001,0,.0001,.00010001)):
  yield scenario(f'landing-{number}-{state}-{y}-{vy}',group='landing',number=number,state=state,actor=[q(0x60,y),q(0x48,vy),q(0x40,7),d(0x14,-1)])
 for x,sse in itertools.product((-1e20,-9223372036854775808.,-4294967296.9,-2147483648.9,-2147483648.,2147483647.9,2147483648.,4294967296.9,9223372036854775808.,1e20),(0,1)):
  yield scenario(f'conversion-{x}-{sse}',group='conversion',kind=3,actor=[q(0x58,x),q(0x40,0),q(0x60,-1),q(0x48,0),d(0x14,-1)],sse2=sse)
 for hit in (-2147483648,-1,0,1,49,50,51,2147483647):
  yield scenario(f'type3-depth-{hit}',group='type3-depth',kind=3,frames=[f(0,0x2c,hit)],actor=[q(0x68,12.7),q(0x50,-.1)])
 for kind in (4,6):
  yield scenario(f'changed-cpoint-{kind}',group='changed-frame',kind=kind,state=1000,actor=[q(0x40,10),q(0x48,1),d(0x14,-1)],frames=[f(40,0x88,2)])
 rng=random.Random(0x40e490)
 for n in range(3000):
  vx=math.ldexp(rng.uniform(-1,1),rng.randrange(-40,40));x=math.ldexp(rng.uniform(-1,1),rng.randrange(-40,40))
  yield scenario(f'numeric-{n}',group='numeric',kind=3,id=(101,120)[n%2],actor=[q(0x40,vx),q(0x58,x),q(0x48,0),q(0x60,-1),d(0x14,-1)])

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accept',action='store_true');a=p.parse_args()
 path=ROOT/'build/original/actor-physics.json';report_path=ROOT/'build/research/actor-physics.json'
 if a.accept:
  raw=path.read_bytes();report=json.loads(report_path.read_bytes());assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
 else:
  vm=ActorPhysics();cases=[]
  for i,item in enumerate(probes()):
   cases.append(vm.probe(item,i))
   if (i+1)%2000==0:print('ACTOR PHYSICS',i+1,flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,fpcw=0x37f,header=HEADER+EXTRA_HEADER,states=STATES,cases=cases,instructions=sorted(vm.instructions))
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),instructions=len(vm.instructions),events=sum(len(c['events']) for c in cases),nativeCompared=False)
  report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 if a.accept:
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalActorPhysicsTests/testWholePhysics'],env=dict(os.environ,NTSD_ACTOR_PHYSICS_CORPUS=str(path)),check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-actor-physics.json';fixture.write_bytes(packed)
  report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/actor-physics.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
