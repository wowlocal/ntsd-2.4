#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole413080 with real input, RNG417170 and sound accumulator417090.
Synthetic declared Actor/Object/Frame/globals, not natural match/DAT coverage.
Compare full Actor bytes/masks and the hash of ALL globals, with ordered events.
No gameplay/sound/RNG helper is stubbed. Native acceptance is separate.
"""
import argparse,base64,itertools,json,os,struct,subprocess,zlib
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_actor_input import ActorInput,OBJECT,REGS,COMBOS,BUFFERS,d,b,f,digest
from oracle_state import ACTOR_SIZE,STOP
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_ESP

def q(offset,value):return [offset,struct.pack('<d',value).hex()]
HEADER=[d(0,3),d(0x18,2),d(0x6f4,2),*[(offset,struct.pack('<d',value).hex()) for offset,value in
 [(8,2.8),(0x10,1.3),(0x20,6.4),(0x28,2.2),(0x30,1.9),(0x38,0.8),(0x40,4.1),(0x48,1.1),
  (0x68,-12.3),(0x70,13.7),(0x78,2.6),(0x80,-9.8),(0x88,4.7)]]]
STATES={**{n:0 for n in range(5)},**{n:1 for n in range(5,9)},**{n:2 for n in range(9,12)},
 **{n:1 for n in range(12,16)},**{n:2 for n in range(16,19)},19:3,110:7,182:12,188:12,212:4,
 213:5,214:5,215:6,216:5,217:5,218:3,219:6,300:301,301:19,302:15}
HELPERS={**{entry:(0,0) for entry in COMBOS},0x412F40:(1,4),0x40E170:(2,8),0x40E2D0:(1,4),
 0x40E450:(1,4),0x417170:(2,0),0x417090:(2,0)}
GLOBAL_BASE,GLOBAL_SIZE=0x44d000,0xb440

class ActorControl(ActorInput):
 def code(self,uc,pc,size,data):
  if not self.running:return
  sp=uc.reg_read(UC_X86_REG_ESP)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop()
   assert sp==h['sp']+4+h['pop'] and [uc.reg_read(r) for r in REGS]==h['saved'],h
   if h['entry']==0x417170:self.events.append(dict(kind='random',arguments=h['args']+[uc.reg_read(UC_X86_REG_EAX)]))
  if pc==self.until:
   assert not self.pending;uc.emu_stop();return
  self.instructions.add(pc)
  if pc in HELPERS:
   count,pop=HELPERS[pc];args=[self.u32(sp+4+4*i) for i in range(count)]
   self.pending.append(dict(entry=pc,sp=sp,pop=pop,returnPC=self.u32(sp),args=args,saved=[uc.reg_read(r) for r in REGS]))
   if pc==0x417090:self.events.append(dict(kind='sound',arguments=args))
  assert any(a<=pc<=b for a,b in [(0x40E170,0x40E48A),(0x412800,0x4143CB),(0x417090,0x4171BC)]),hex(pc)
 def object_bytes(self,item):
  obj=bytearray(0x40000)
  for offset,hexadecimal in HEADER+item.get('header',[]):
   raw=bytes.fromhex(hexadecimal);obj[offset:offset+len(raw)]=raw
  for n in range(400):
   obj[0x7a4+n*0x178]=1;struct.pack_into('<i',obj,0x7a4+n*0x178+8,STATES.get(n,3))
   if n in (60,65,80,85,90):struct.pack_into('<i',obj,0x7a4+n*0x178+0x4c,100)
  for n,offset,hexadecimal in item.get('frames',[]):
   raw=bytes.fromhex(hexadecimal);obj[0x7a4+n*0x178+offset:0x7a4+n*0x178+offset+len(raw)]=raw
  return bytes(obj)
 def probe(self,item,index):
  item=dict(item);item['fill']='a5' if index%2==0 else 'ramp';t=self.templates[item['fill']]
  self.target=int(t['address'],16);self.size=ACTOR_SIZE;self.mask=t['defined'].copy();self.writes=[];self.pending=[];self.events=[]
  self.uc.mem_write(self.target-16,b'\x96'*16+bytes.fromhex(t['bytes'])+b'\x69'*16)
  item['actor']=[d(0x368,OBJECT),*item.get('actor',[])]
  for offset,hexadecimal in item['actor']:
   raw=bytes.fromhex(hexadecimal);self.uc.mem_write(self.target+offset,raw);self.mask[offset:offset+len(raw)]=[True]*len(raw)
  obj=self.object_bytes(item);self.uc.mem_write(OBJECT,obj)
  globals_=bytearray(GLOBAL_SIZE);globals_[0x44ff90-GLOBAL_BASE:0x44ff90-GLOBAL_BASE+3000]=bytes(1+i%255 for i in range(3000))
  struct.pack_into('<i',globals_,0x44d034-GLOBAL_BASE,1)
  for offset,hexadecimal in item.get('globals',[]):
   raw=bytes.fromhex(hexadecimal);globals_[offset-GLOBAL_BASE:offset-GLOBAL_BASE+len(raw)]=raw
  self.uc.mem_write(GLOBAL_BASE,bytes(globals_))
  self.call(0x413080,(item.get('phase',1),item.get('mode',0)),pop=8)
  assert bytes(self.uc.mem_read(OBJECT,len(obj)))==bytes(obj)
  assert self.uc.mem_read(self.target-16,16)==b'\x96'*16 and self.uc.mem_read(self.target+ACTOR_SIZE,16)==b'\x69'*16
  item.update(after=bytes(self.uc.mem_read(self.target,ACTOR_SIZE)).hex(),defined=bytes(self.mask).hex(),
   globalsSHA256=digest(bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE))),events=self.events)
  return item

def held(mask):return [b(0xcd+i,(mask>>i)&1) for i in range(7)]
def probes():
 for mask,number,kind,facing in itertools.product(range(128),(0,5,9,12,16,110,182,188,212,213,215,216,217,300,301),(0,1,2,4,6,101),range(2)):
  yield dict(label=f'matrix-{mask}-{number}-{kind}-{facing}',group='matrix',actor=[d(0x70,number),d(0x98,kind),b(0x80,facing),d(0x14,-1 if number in (182,188,212,213,216,217) else 0),*held(mask)])
 for number,kind,tap,phase,previous in itertools.product((0,5,9,12,16),(0,2),(-12,-11,-1,0,1,11,12),(0,5,11,17,2147483647),(0,1)):
  yield dict(label=f'phase-{number}-{kind}-{tap}-{phase}-{previous}',group='phase',actor=[d(0x70,number),d(0x98,kind),d(4,tap),d(0,phase),b(0xc9,previous),*held(8)])
 for number,mask,vx,facing in itertools.product((182,188,213,215,216,217),(0,16,32,48,44),(-13.7,-1.,-0.001,-0.0,0.001,1.,13.7),(0,1,2,255)):
  yield dict(label=f'air-{number}-{mask}-{vx}-{facing}',group='air',actor=[d(0x70,number),q(0x40,vx),q(0x48,4.5),b(0x80,facing),*held(mask)])
 for number,mp,cost,enabled in itertools.product((0,212,9,213),(-1,0,99,100,101,2147483647),(-1001,0,100,2001,2147483647,-2147483648),(0,1)):
  yield dict(label=f'cost-{number}-{mp}-{cost}-{enabled}',group='cost',actor=[d(0x70,number),d(0x14,-1),d(0x308,mp),d(0x350,2147483647),*held(16)],
   globals=[d(0x44d034,enabled)],frames=[f(n,0x4c,cost) for n in (60,65,80,85,90)])
 for dvx,dvy,dvz,facing,mask in itertools.product((-10,0,10,500,501,550,551),(-10,0,501),(0,10,501),(0,1,2),(0,1,2,3)):
  yield dict(label=f'dv-{dvx}-{dvy}-{dvz}-{facing}-{mask}',group='dv',actor=[d(0x70,302),b(0x80,facing),q(0x40,-3.5),q(0x48,0.125),*held(mask)],frames=[f(302,0x14,dvx),f(302,0x18,dvy),f(302,0x1c,dvz)])
 for x,camera,flag in itertools.product((-400,-1,0,199,200,399,400,600,799,800,999,1000,2147483647,-2147483648),(-1,0,2147483647),(0,1,-1)):
  yield dict(label=f'sound-{x}-{camera}-{flag}',group='sound',actor=[d(0x70,215),d(0x10,x),*held(44)],globals=[d(0x450bc4,camera),d(0x453e10+28,flag),d(0x4527e8+28,2147483647),d(0x4554c8+28,-2147483648)])
 for index,counter,kind in itertools.product((0,2998,2999),(0,1232,1233),(0,1,101,201,-99)):
  yield dict(label=f'random-{index}-{counter}-{kind}',group='random',actor=[d(0x98,kind),*held(16)],globals=[d(0x450bcc,index),d(0x450c34,counter)])

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accept',action='store_true');a=p.parse_args()
 path=ROOT/'build/original/actor-control.json';report_path=ROOT/'build/research/actor-control.json'
 if a.accept:
  report=json.loads(report_path.read_bytes());raw=path.read_bytes();assert len(raw)==report['bytes'] and digest(raw)==report['sha256']
 else:
  vm=ActorControl();cases=[]
  for i,item in enumerate(probes()):
   cases.append(vm.probe(item,i))
   if (i+1)%2000==0:print('ACTOR CONTROL',i+1,flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,header=HEADER,states=STATES,cases=cases,instructions=sorted(vm.instructions))
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),nativeCompared=False)
  report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 if a.accept:
  env=dict(os.environ,NTSD_ACTOR_CONTROL_CORPUS=str(path))
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalActorControlTests/testWholeOriginalControlOnRawActorAndGlobals'],env=env,check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-actor-control.json';fixture.write_bytes(packed)
  report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/actor-control.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
