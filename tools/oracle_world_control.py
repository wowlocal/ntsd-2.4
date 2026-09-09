#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Entire41e339..41e634 with real413080/403270 and helper ABIs.
Declared synthetic400-Actor pool, four Objects and initialized globals, with
original constructors and full pool bytes/masks. Not a natural match capture.
Includes aliasing, duplicate IDs, slot order and signed/overflow controls.
"""
import argparse,base64,itertools,json,os,struct,subprocess,zlib
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_state import Constructors,ACTOR_SIZE,WORLD_PREFIX,STACK
from oracle_actor_control import ActorControl,HEADER,HELPERS,GLOBAL_BASE,GLOBAL_SIZE,q,held
from oracle_actor_input import REGS,d,b,digest
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP

WORLD,POOL,OBJECT,CATALOG=0x22000020,0x70000020,0x50000000,0x60000020
BODY_SP=STACK+0xe000
CALLS={**HELPERS,0x413080:(2,8),0x403270:(2,8),0x4034e0:(1,0)}
STATES={300:400,301:401,302:500,303:501}
IDS=[10,20,20,30]
class WorldControl(Constructors):
 source_ids=IDS
 frame_states=STATES
 mutates_world=False
 def __init__(self):
  super().__init__();self.running=False;self.instructions=set();self.templates={}
  for fill in ('a5','ramp'):
   self.templates[fill]={}
   for kind,size in [('world',WORLD_PREFIX),('actor',ACTOR_SIZE)]:
    raw=b'\xa5'*size if fill=='a5' else bytes(i&255 for i in range(size))
    self.templates[fill][kind]=self.capture(kind,raw,0x100)
  for address,size in [(POOL&~0xfff,0x80000),(OBJECT,0x100000),(CATALOG&~0xfff,0x4d83000)]:self.uc.mem_map(address,size)
  self.uc.hook_add(UC_HOOK_CODE,self.code)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.access)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.access)
 def written(self,*args):
  if not self.running:super().written(*args)
  else:raise AssertionError('Control wrote World')
 def access(self,uc,access,address,size,value,data):
  if not self.running:return
  from unicorn import UC_MEM_READ
  if WORLD<=address<WORLD+WORLD_PREFIX:
   assert access==UC_MEM_READ and address+size<=WORLD+WORLD_PREFIX and all(self.world_mask[address-WORLD:address-WORLD+size])
  elif POOL-16<=address<POOL+400*0x500:
   i,offset=divmod(address-POOL,0x500)
   assert 0<=i<400 and offset+size<=ACTOR_SIZE,(hex(uc.reg_read(UC_X86_REG_EIP)),hex(address),size)
   if access==UC_MEM_READ:assert all(self.masks[i][offset:offset+size]),(hex(uc.reg_read(UC_X86_REG_EIP)),i,hex(offset),size)
   else:self.masks[i][offset:offset+size]=b'\1'*size
  elif OBJECT<=address<OBJECT+0x100000:assert access==UC_MEM_READ
  elif CATALOG<=address<CATALOG+0x4d82390:assert access==UC_MEM_READ
 def code(self,uc,pc,size,data):
  if not self.running:return
  sp=uc.reg_read(UC_X86_REG_ESP)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop();assert sp==h['sp']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGS],h
   self.helpers+=1
   if h['entry']==0x417170:self.events.append(dict(slot=self.u32(BODY_SP+0x3c),kind='random',arguments=h['args']+[uc.reg_read(UC_X86_REG_EAX)]))
  if pc==0x41e634:
   assert not self.pending;self.finished=True;uc.emu_stop();return
  self.instructions.add(pc)
  if pc in CALLS:
   count,pop=CALLS[pc];args=[self.u32(sp+4+4*i) for i in range(count)]
   self.pending.append(dict(entry=pc,sp=sp,pop=pop,returnPC=self.u32(sp),args=args,saved=[uc.reg_read(r) for r in REGS]))
   if pc==0x417090:self.events.append(dict(slot=self.u32(BODY_SP+0x3c),kind='sound',arguments=args))
  assert any(a<=pc<=e for a,e in [(0x41e339,0x41e62e),(0x412800,0x4143cb),(0x40e170,0x40e48a),(0x403270,0x4034ea),(0x417090,0x4171bc)]),hex(pc)
 def probe(self,item,index):
  item=dict(item);item['fill']='a5' if index%2==0 else 'ramp';template=self.templates[item['fill']]
  self.pending=[];self.events=[];self.helpers=0;self.finished=False
  world=bytearray.fromhex(template['world']['bytes']);self.world_mask=bytearray(template['world']['defined'])
  def write(raw,mask,offset,hexadecimal):
   v=bytes.fromhex(hexadecimal);raw[offset:offset+len(v)]=v;mask[offset:offset+len(v)]=b'\1'*len(v)
  bindings=dict(item.get('aliases',[]));self.masks=[]
  actors={i:patches for i,patches in item.get('actors',[])}
  active=dict(item.get('active',[]))
  for i in range(400):
   write(world,self.world_mask,*b(4+i,active.get(i,0)));write(world,self.world_mask,*d(0x194+4*i,POOL+bindings.get(i,i)*0x500))
   raw=bytearray.fromhex(template['actor']['bytes']);mask=bytearray(template['actor']['defined'])
   for offset,h in [d(0x368,0),*actors.get(i,[])]:write(raw,mask,offset,h)
   ordinal=int.from_bytes(raw[0x368:0x36c],'little');struct.pack_into('<I',raw,0x368,OBJECT+ordinal*0x40000)
   self.uc.mem_write(POOL+i*0x500-16,b'\x96'*16+bytes(raw)+b'\x69'*16);self.masks.append(mask)
  write(world,self.world_mask,*d(0x7d4,CATALOG));self.uc.mem_write(WORLD,bytes(world))
  objects=[]
  for i,source_id in enumerate(self.source_ids):
   raw=bytearray(ActorControl.object_bytes(self,{}))
   struct.pack_into('<i',raw,0x6f4,source_id);struct.pack_into('<i',raw,0x6f8,3 if i==3 else 0)
   for n in range(400):struct.pack_into('<i',raw,0x7ac+n*0x178,self.frame_states.get(n,3))
   for obj,n,offset,h in item.get('frames',[]):
    if obj==i:raw[0x7a4+n*0x178+offset:0x7a4+n*0x178+offset+len(bytes.fromhex(h))]=bytes.fromhex(h)
   objects.append(bytes(raw));self.uc.mem_write(OBJECT+i*0x40000,bytes(raw));self.uc.mem_write(CATALOG+4*i,struct.pack('<I',OBJECT+i*0x40000))
  self.uc.mem_write(CATALOG+0x4d82380,struct.pack('<i',item.get('count',4)))
  glob=bytearray(GLOBAL_SIZE);glob[0x44ff90-GLOBAL_BASE:0x44ff90-GLOBAL_BASE+3000]=bytes(1+i%255 for i in range(3000));struct.pack_into('<i',glob,0x44d034-GLOBAL_BASE,1)
  for address,h in item.get('globals',[]):glob[address-GLOBAL_BASE:address-GLOBAL_BASE+len(bytes.fromhex(h))]=bytes.fromhex(h)
  self.uc.mem_write(GLOBAL_BASE,bytes(glob));self.uc.reg_write(UC_X86_REG_ESP,BODY_SP)
  for r,v in zip(REGS,[WORLD,0x22334455,0x33445566,0x44556677]):self.uc.reg_write(r,v)
  self.running=True
  try:self.execute()
  finally:self.running=False
  assert self.finished and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP and self.uc.reg_read(UC_X86_REG_EBX)==WORLD
  if self.mutates_world:world=bytearray(self.uc.mem_read(WORLD,WORLD_PREFIX))
  else:assert bytes(self.uc.mem_read(WORLD,WORLD_PREFIX))==bytes(world)
  for i,raw in enumerate(objects):assert bytes(self.uc.mem_read(OBJECT+i*0x40000,len(raw)))==raw
  for i in range(400):
   struct.pack_into('<I',world,0x194+i*4,bindings.get(i,i))
  struct.pack_into('<I',world,0x7d4,0)
  pool=world;mask=self.world_mask.copy()
  for i in range(400):
   address=POOL+i*0x500;raw=bytearray(self.uc.mem_read(address,ACTOR_SIZE));ptr=int.from_bytes(raw[0x368:0x36c],'little');assert (ptr-OBJECT)%0x40000==0 and 0<=(ptr-OBJECT)//0x40000<4
   struct.pack_into('<I',raw,0x368,(ptr-OBJECT)//0x40000);pool+=raw;mask+=self.masks[i]
   assert self.uc.mem_read(address-16,16)==b'\x96'*16 and self.uc.mem_read(address+ACTOR_SIZE,16)==b'\x69'*16
  item.update(poolSHA256=digest(pool),maskSHA256=digest(mask),globalsSHA256=digest(bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE))),events=self.events,helpers=self.helpers)
  return item
 def execute(self):
  self.uc.emu_start(0x41e339,0,count=2_000_000)
  assert self.u32(BODY_SP+0x3c)==400

def probes():
 for state,facing,gate in itertools.product((300,301),(0,1,2,255),(0,1,-1)):
  for x,z in [(0,0),(9999,0),(10000,0),(10001,0),(-2147483648,0),(2147483647,1),(2147483647,2147483647)]:
   for team,hp,activity,obj in [(1,500,1,0),(2,500,1,0),(2,0,1,0),(2,-1,1,0),(2,500,0,0),(2,500,255,0),(2,500,1,3)]:
    yield dict(group='teleport',label=f'teleport-{state}-{facing}-{gate}-{x}-{z}-{team}-{hp}-{activity}-{obj}',active=[[0,1],[1,activity],[399,1]],
     actors=[[0,[d(0x70,state),b(0x80,facing),d(0x364,1),d(0x14,-5),q(0x58,12.5),q(0x60,-5.5),q(0x68,13.5)]],
     [1,[d(0x10,x),d(0x18,z),d(0x364,team),d(0x2fc,hp),d(0x368,obj)]],[399,[d(0x10,x),d(0x18,z),d(0x364,team),d(0x2fc,hp),d(0x368,obj)]]],globals=[d(0x450bd8,gate)])
 for target,previous in itertools.product((-2,-1,0,10,20,30,99),(-2,-1,0,20)):
  for state in (302,303):
   yield dict(group='transform-gates',label=f'gates-{state}-{target}-{previous}',active=[[0,255]],actors=[[0,[d(0x70,state),d(0x33c,target),d(0x324,previous)]]])
 for main,alias,hp,activity,y in itertools.product((0,4,199,399),(False,True),(-1,0,500),(0,1,128),(-1,0,1)):
  linked=(main+1)%400;earlier=(main-1)%400
  yield dict(group='linked-order',label=f'links-{main}-{alias}-{hp}-{activity}-{y}',active=[[main,1],[linked,activity],[earlier,1]],aliases=[[linked,main]] if alias else [],
   actors=[[main,[d(0x70,303),d(0x33c,20),d(0x2f4,main),d(0x14,y)]],[linked,[d(0x2f4,main),d(0x2fc,hp),d(0x14,y),*held(16)]],[earlier,[d(0x2f4,main),d(0x14,y)]]])
 for count in (-1,0,1,2,3,4):
  for target in (10,20,30,99):yield dict(group='catalog-count',label=f'count-{count}-{target}',count=count,active=[[0,1]],actors=[[0,[d(0x70,303),d(0x33c,target)]]])
 for state in (300,301):
  for facing in (0,2):yield dict(group='teleport-alias',label=f'alias-{state}-{facing}',active=[[0,1],[1,255]],aliases=[[1,0]],actors=[[0,[d(0x70,state),b(0x80,facing),d(0x364,2),d(0x10,2147483647),d(0x18,2147483647)]]])
 for state,coords in itertools.product((300,301),(((100,0),(0,100)),((100,0),(300,0)),((300,0),(100,0)))):
  team=2 if state==300 else 1
  yield dict(group='selection-order',label=f'select-{state}-{coords}',active=[[0,1],[1,1],[399,1]],actors=[[0,[d(0x70,state),d(0x364,1)]],*[ [slot,[d(0x364,team),d(0x10,x),d(0x18,z)]] for slot,(x,z) in zip((1,399),coords)]])
 # state500 frame reset must reload state501 from frame0 in the same pass.
 for target in (-1,20):yield dict(group='state-reload',label=f'reload-{target}',active=[[0,1]],actors=[[0,[d(0x70,302),d(0x33c,target),d(0x324,10)]]],frames=[[0,0,*d(8,501)]])
 # Action transfers to a teleport/transform state before caller dispatch.
 for target in (300,301,302,303):yield dict(group='input-transition',label=f'input-{target}',active=[[0,1],[1,1]],actors=[[0,[d(0x33c,20),*held(16)]],[1,[d(0x364,2),d(0x10,400)]]],frames=[[0,0,*d(0x24,target)]])
 yield dict(group='all-slots',label='all-slots-linked',active=[[i,1] for i in range(400)],actors=[[i,[d(0x2f4,199),d(0x14,-1 if i%2 else 0),d(0x70,303 if i==199 else 0),d(0x33c,20)]] for i in range(400)])
 yield dict(group='ordered-events',label='random-then-double-sound',active=[[0,1],[1,1]],actors=[[0,held(16)],[1,[d(0x70,215),*held(44)]]],frames=[[0,0,*d(8,0)],[0,215,*d(8,6)]],globals=[d(0x450bcc,2999),d(0x450c34,1233)])
 yield dict(group='empty',label='empty')

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accept',action='store_true');a=p.parse_args()
 path=ROOT/'build/original/world-control.json';report_path=ROOT/'build/research/world-control.json'
 if a.accept:
  raw=path.read_bytes();report=json.loads(report_path.read_bytes());assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
 else:
  vm=WorldControl();cases=[]
  for i,item in enumerate(probes()):
   cases.append(vm.probe(item,i))
   if (i+1)%250==0:print('WORLD CONTROL',i+1,flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,header=HEADER,states=STATES,ids=IDS,cases=cases,instructions=sorted(vm.instructions))
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),instructions=len(vm.instructions),nativeCompared=False)
  report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 if a.accept:
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalWorldControlTests/testEntireControlCaller'],env=dict(os.environ,NTSD_WORLD_CONTROL_CORPUS=str(path)),check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-world-control.json';fixture.write_bytes(packed)
  report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/world-control.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
