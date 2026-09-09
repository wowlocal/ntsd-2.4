#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole418c30/4187b0 and caller41f2ac..41f484 with cleanup/second417f80.
Declared synthetic400-slot pool, Object/Frame/BG inputs and retained caller slot.
Actual original functions and helper ABIs, full pool/masks/globals, ordered RNG.
Finite CW037f only; not natural DAT sequences or a complete match.
"""
import argparse,itertools,json,struct
from collections import Counter
from oracle_world_links import WorldLinks,IDS,BG,f,h
from oracle_world_control import WORLD,POOL,OBJECT,CATALOG,BODY_SP,HEADER,REGS,d,b,q,digest
from oracle_actor_control import ActorControl,GLOBAL_BASE,GLOBAL_SIZE
from oracle_state import ACTOR_SIZE,WORLD_PREFIX,STOP
from import_ntsd import ROOT,EXE_SHA256
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW
STATES={300:9,301:10,302:12,303:17}
class WorldCPoints(WorldLinks):
 def code(self,uc,pc,size,data):
  if not self.running:return
  sp=uc.reg_read(UC_X86_REG_ESP)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop();assert sp==h['sp']+4 and h['saved']==[uc.reg_read(r) for r in REGS],h
   self.helpers+=1
   if h['entry']==0x417170:self.events.append(dict(slot=h['slot'],kind='random',arguments=h['args']+[uc.reg_read(UC_X86_REG_EAX)]))
  if pc==STOP or (self.stage=='caller' and pc==0x41f484) or (self.stage=='cleanup' and pc==0x41f47d):
   assert not self.pending;self.finished=True;uc.emu_stop();return
  self.instructions.add(pc)
  if pc in (0x417f80,0x417170,0x4450d0) or (self.stage=='caller' and pc in (0x418c30,0x4187b0)):
   args=[self.u32(sp+4+4*i) for i in range(2)] if pc==0x417170 else []
   self.pending.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),slot=self.u32(BODY_SP-4-0x10-16+0x1c),args=args,saved=[uc.reg_read(r) for r in REGS]))
  assert any(a<=pc<=e for a,e in [(0x41f2ac,0x41f484),(0x417f80,0x419373),(0x417170,0x4171bc),(0x4450d0,0x44517a)]),hex(pc)
 def probe(self,item,index):
  item=dict(item,fill='a5' if index%2==0 else 'ramp');template=self.templates[item['fill']]
  self.pending=[];self.events=[];self.helpers=0;self.finished=False;self.stage=item.get('stage','actions')
  world=bytearray.fromhex(template['world']['bytes']);self.world_mask=bytearray(template['world']['defined'])
  def write(raw,mask,offset,h):
   v=bytes.fromhex(h);raw[offset:offset+len(v)]=v;mask[offset:offset+len(v)]=b'\1'*len(v)
  bindings=dict(item.get('aliases',[]));self.masks=[];actors=dict(item.get('actors',[]));active=dict(item.get('active',[]))
  for i in range(400):
   write(world,self.world_mask,*b(4+i,active.get(i,0)));write(world,self.world_mask,*d(0x194+4*i,POOL+bindings.get(i,i)*0x500))
   raw=bytearray.fromhex(template['actor']['bytes']);mask=bytearray(template['actor']['defined'])
   for offset,h in [d(0x368,0),d(0x31c,20),*actors.get(i,[])]:write(raw,mask,offset,h)
   ordinal=int.from_bytes(raw[0x368:0x36c],'little');struct.pack_into('<I',raw,0x368,OBJECT+ordinal*0x40000)
   self.uc.mem_write(POOL+i*0x500-16,b'\x96'*16+bytes(raw)+b'\x69'*16);self.masks.append(mask)
  write(world,self.world_mask,*d(0x7d4,CATALOG));self.uc.mem_write(WORLD,bytes(world));objects=[]
  for i,id in enumerate(IDS):
   raw=bytearray(ActorControl.object_bytes(self,{}));struct.pack_into('<ii',raw,0x6f4,id,0 if i==0 else 1)
   for n in range(400):struct.pack_into('<i',raw,0x7ac+n*0x178,STATES.get(n,3))
   for obj,offset,h in item.get('headers',[]):
    if obj==i:raw[offset:offset+len(bytes.fromhex(h))]=bytes.fromhex(h)
   for obj,n,offset,h in item.get('frames',[]):
    if obj==i:raw[0x7a4+n*0x178+offset:0x7a4+n*0x178+offset+len(bytes.fromhex(h))]=bytes.fromhex(h)
   objects.append(bytes(raw));self.uc.mem_write(OBJECT+i*0x40000,bytes(raw));self.uc.mem_write(CATALOG+4*i,struct.pack('<I',OBJECT+i*0x40000))
  self.uc.mem_write(CATALOG+0x4d82380,struct.pack('<i',4))
  bg=bytearray(101*0x990)
  for i in range(101):struct.pack_into('<ii',bg,i*0x990+4,*item.get('bounds',[0,600]))
  self.uc.mem_write(CATALOG+BG,bytes(bg))
  glob=bytearray(GLOBAL_SIZE);glob[0x44ff90-GLOBAL_BASE:0x44ff90-GLOBAL_BASE+3000]=bytes(1+i%255 for i in range(3000));struct.pack_into('<i',glob,0x44d034-GLOBAL_BASE,1)
  for address,h in item.get('globals',[]):glob[address-GLOBAL_BASE:address-GLOBAL_BASE+len(bytes.fromhex(h))]=bytes.fromhex(h)
  self.uc.mem_write(GLOBAL_BASE,bytes(glob));self.uc.mem_write(0x45971c,struct.pack('<I',item.get('sse2',0)))
  entries={'actions':0x418c30,'placement':0x4187b0,'cleanup':0x41f2b8,'caller':0x41f2ac}
  self.entry_sp=BODY_SP if self.stage in ('cleanup','caller') else BODY_SP-4
  self.uc.mem_write(self.entry_sp-4,struct.pack('<i',item.get('retainedPartnerSlot',0)))
  if self.stage=='caller':self.uc.mem_write(BODY_SP-8,struct.pack('<i',item.get('retainedPartnerSlot',0)))
  self.uc.mem_write(self.entry_sp,struct.pack('<I',STOP));self.uc.reg_write(UC_X86_REG_ESP,self.entry_sp);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  saved=[WORLD if self.stage in ('cleanup','caller') else 0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGS,saved):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_FPCW,0x37f);self.running=True
  try:self.uc.emu_start(entries[self.stage],0,count=2_000_000)
  except Exception:print('WORLD CPOINT FAILURE',item['label'],hex(self.uc.reg_read(UC_X86_REG_EIP)),flush=True);raise
  finally:self.running=False
  assert (self.finished or self.uc.reg_read(UC_X86_REG_EIP)==STOP) and not self.pending and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP,(item['label'],self.finished,self.pending,hex(self.uc.reg_read(UC_X86_REG_EIP)),hex(self.uc.reg_read(UC_X86_REG_ESP)))
  assert self.uc.reg_read(REGS[0])==saved[0]
  if self.stage not in ('cleanup','caller'):assert [self.uc.reg_read(r) for r in REGS]==saved and self.uc.reg_read(UC_X86_REG_ECX)==WORLD
  assert self.uc.reg_read(UC_X86_REG_FPCW)==0x37f and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  assert bytes(self.uc.mem_read(WORLD,WORLD_PREFIX))==bytes(world) and bytes(self.uc.mem_read(CATALOG+BG,len(bg)))==bytes(bg)
  for i,raw in enumerate(objects):assert bytes(self.uc.mem_read(OBJECT+i*0x40000,len(raw)))==raw
  for i in range(400):struct.pack_into('<I',world,0x194+i*4,bindings.get(i,i))
  struct.pack_into('<I',world,0x7d4,0);pool=world;mask=self.world_mask.copy()
  for i in range(400):
   address=POOL+i*0x500;raw=bytearray(self.uc.mem_read(address,ACTOR_SIZE));ptr=int.from_bytes(raw[0x368:0x36c],'little');assert (ptr-OBJECT)%0x40000==0 and 0<=(ptr-OBJECT)//0x40000<4
   struct.pack_into('<I',raw,0x368,(ptr-OBJECT)//0x40000);pool+=raw;mask+=self.masks[i]
   assert self.uc.mem_read(address-16,16)==b'\x96'*16 and self.uc.mem_read(address+ACTOR_SIZE,16)==b'\x69'*16
  item.update(poolSHA256=digest(pool),maskSHA256=digest(mask),globalsSHA256=digest(bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE))),events=self.events,helpers=self.helpers);return item
def linked(label,group,stage='actions',owner=0,target=1,holder=(),caught=(),frames=(),**kw):
 return dict(label=label,group=group,stage=stage,retainedPartnerSlot=3,active=[[owner,1],[target,1]],
  actors=[[owner,[d(0x368,0),d(0x70,300),d(0x7c,300),d(0x8c,target),d(0x94,200),*holder]],
   [target,[d(0x368,3),d(0x70,301),d(0x7c,301),d(0x90,owner),*caught]]],
  frames=[f(0,300,0x88,1),f(0,300,0x9c,301),f(3,301,0x88,2),*frames],**kw)
def probes():
 for stage,kind,hitstop,reciprocal in itertools.product(('actions','placement'),(0,1,2,3),(-1,0,1),(2,0)):
  yield linked(f'gate-{stage}-{kind}-{hitstop}-{reciprocal}','gates',stage=stage,holder=[d(0xb4,hitstop)],caught=[d(0x90,reciprocal)],frames=[f(0,300,0x88,kind)])
 for decrease,count,x in itertools.product((-2147483648,-201,-1,0,1,201,2147483647),(-2147483648,-1,0,1,200,2147483647),(-100,0,100)):
  yield linked(f'counter-{decrease}-{count}-{x}','counter',holder=[d(0x94,count),d(0x10,x)],frames=[f(0,300,0xb8,decrease)])
 for bits,attack,jump,direction,edge in itertools.product(range(16),(0,65,-65),(0,70,-70),(0,75,-75),(0,1,128,255)):
  # All direction bits and signed edge-byte gates, with both action latches set.
  if bits not in (0,1,4,5,15) and (attack,jump,direction,edge)!=(65,70,75,1):continue
  yield linked(f'input-{bits}-{attack}-{jump}-{direction}-{edge}','input',holder=[b(0xd1,255),b(0xd2,255),b(0xbe,edge),b(0xbf,edge),*[b(o,(bits>>n)&1) for n,o in enumerate((0xcd,0xce,0xcf,0xd0))]],
   frames=[f(0,300,0xa0,attack),f(0,300,0xa4,jump),f(0,300,0xc0,direction),f(0,65,0x9c,310),f(0,70,0x9c,311),f(0,75,0x9c,312)])
 for vx,vaction,facing,directions,hurting in itertools.product((-2147483648,-3,3,2147483647),(301,305),(0,1,2,255),range(4),(-2,-1,0,9)):
  c=linked(f'throw-{vx}-{vaction}-{facing}-{directions}-{hurting}','throw',holder=[b(0x80,facing),b(0xcd,directions&1),b(0xce,(directions>>1)&1),d(0x10,100),d(0x14,-30)],
   frames=[f(0,300,0xac,vx),f(0,300,0xb0,-2147483648),f(0,300,0xc8,2147483647),f(0,300,0x9c,vaction),f(0,300,0xc4,hurting),f(0,300,0x8c,33),f(0,300,0x90,-17),f(0,300,0x50,7),f(0,300,0x54,11),f(0,300,0x10,80),f(3,0,0x50,29),f(3,0,0x54,31),f(3,0,0x10,90)])
  c['active'] += [[n,255] for n in (2,3,4,5,398,399)]
  c['actors'] += [[n,[d(0x2f4,0)]] for n in (2,3,4,5,398,399)]
  yield c
 for turn,latch,directions,facing in itertools.product((-1,0,1,2),(0,1,2),range(4),(0,1,255)):
  yield linked(f'turn-{turn}-{latch}-{directions}-{facing}','turn',holder=[d(0x88,latch),b(0xcf,directions&1),b(0xd0,directions>>1),b(0x80,facing)],frames=[f(0,300,0xbc,turn)])
 for backlink,kind,y in itertools.product((-1,1),(0,1,2),(-100.,-2.,-.0,.1,100.)):
  yield dict(label=f'orphan-{backlink}-{kind}-{y}',group='orphan',stage='actions',active=[[1,1]],actors=[[0,[d(0x8c,backlink)]],[1,[d(0x368,3),d(0x70,301),d(0x7c,301),d(0x90,0),q(0x60,y)]]],frames=[f(3,301,0x88,2),f(0,0,0x88,kind)])
 for injury,divisor,team,owned,latch in itertools.product((-2147483648,-31,-1,0,1,501,2147483647),(0,1,3,2147483647),(-1,0,1,2,3),(-1,0),(0,1)):
  yield linked(f'injury-{injury}-{divisor}-{team}-{owned}-{latch}','injury',stage='placement',holder=[d(0x88,latch),d(0x354,399)],caught=[d(0x340,divisor),d(0x344,team),d(0x2f4,owned)],frames=[f(0,300,0x94,injury)])
 for facing,caughtface,cover,gate,hitstop in itertools.product((0,1,2,255),(0,1,2,255),(-11,-1,0,1,10,11,20,21,30),(0,1,2),(-1,0,1)):
  if gate!=1 and (facing,caughtface,cover)!=(0,1,11):continue
  yield linked(f'geometry-{facing}-{caughtface}-{cover}-{gate}-{hitstop}','geometry',stage='placement',holder=[b(0x80,facing),d(0x10,2147483647),d(0x14,-2147483648),d(0x18,2147483647)],caught=[b(0x80,caughtface),d(0xb4,hitstop)],
   frames=[f(0,300,0x98,cover),f(0,300,0xb4,gate),f(0,300,0x9c,305),f(0,300,0x8c,33),f(0,300,0x90,11),f(0,300,0x50,-21),f(0,300,0x54,7),f(3,301,0x50,19),f(3,301,0x54,-31),f(3,305,0x50,37),f(3,305,0x54,41),f(3,305,0x8c,47),f(3,305,0x90,53)])
 for typ,target,activity,backlink in itertools.product((-2,0,1,2),(-2147483648,-1,1,399,400,2147483647),(0,255),(0,99)):
  yield dict(label=f'cleanup-{typ}-{target}-{activity}-{backlink}',group='cleanup',stage='cleanup',active=[[0,1],[1,activity],[399,activity]],actors=[[0,[d(0x98,typ),d(0x9c,target)]],[1,[d(0xa0,backlink)]],[399,[d(0xa0,backlink)]]])
 # Invalid reciprocal links deliberately use the retained slot, not Actor8c.
 for seed,vx,alias in itertools.product((0,1,3,399),(-3,3),(False,True)):
  c=linked(f'stale-{seed}-{vx}-{alias}','retained',holder=[d(0x10,99)],caught=[d(0x90,2)],frames=[f(0,300,0xac,vx)],aliases=[[seed,0]] if alias else [])
  c['retainedPartnerSlot']=seed;yield c
 for owner,target,stage in itertools.product((0,1,398,399),(0,1,398,399),('actions','placement','caller')):
  if owner==target:continue
  yield linked(f'order-{owner}-{target}-{stage}','order',stage=stage,owner=owner,target=target,holder=[b(0xd1,1),b(0xbe,1)],frames=[f(0,300,0xa0,65),f(0,65,0x9c,301),f(0,65,0x88,1),f(0,65,8,9)])
 for lane in range(5):
  c=linked(f'caller-held-{lane}','caller',stage='caller',owner=lane,target=399)
  c['actors'][0][1] += [d(0x98,1),d(0x9c,100+lane)]
  c['actors'] += [[100+lane,[d(0x368,1),d(0x98,-1),d(0xa0,lane)]]];c['active'] += [[100+lane,1]]
  c['frames'] += [f(0,300,0xe4,40),f(0,300,0xf0,3),f(0,300,0xf4,-2)]
  yield c
 for vaction,facing in itertools.product((-1,-2,-3,-4,-5),(0,1,2,255)):
  offset=0x7a4+vaction*0x178+0x88
  yield linked(f'negative-vaction-{vaction}-{facing}','negative-vaction',stage='placement',caught=[b(0x80,facing)],frames=[f(0,300,0x9c,vaction)],headers=[h(3,offset+4,47),h(3,offset+8,-53)])
 for lane in range(5):
  c=linked(f'clone-lane-{lane}','clone-lanes',frames=[f(0,300,0xac,3),f(0,300,0xc4,-1)])
  c['active'] += [[5+lane,1]];c['actors'] += [[5+lane,[d(0x2f4,0)]]];yield c
 for lane,target in itertools.product(range(5),(-1,399)):
  yield dict(label=f'cleanup-lane-{lane}-{target}',group='cleanup-lanes',stage='caller',active=[[lane,255]],actors=[[lane,[d(0x98,1),d(0x9c,target)]]])
 for typ,kind,state,hp in itertools.product((1,2,4,6),(1,3),(9,12,17),(0,1,2)):
  c=linked(f'caller-rng-{typ}-{kind}-{state}-{hp}','caller-rng',stage='caller')
  c['actors'][0][1] += [d(0x98,1),d(0x9c,50)]
  c['actors'] += [[50,[d(0x368,1),d(0x98,-1),d(0xa0,0),d(0x2fc,hp)]]];c['active'] += [[50,1]]
  c['headers']=[h(1,0x6f8,typ)]
  c['frames'] += [f(0,300,8,state),f(0,300,0xd8,kind),f(0,300,0xe4,40),f(0,300,0xf0,3),f(0,300,0xf4,-2),f(0,300,0xf8,1)]
  yield c
 for prior,alias in itertools.product((False,True),(False,True)):
  # A previous valid pair chooses slot2; slot1's broken link names3 instead.
  yield dict(label=f'partner-lifetime-{prior}-{alias}',group='partner-lifetime',stage='actions',retainedPartnerSlot=399,
   active=[[0,int(prior)],[1,1]],aliases=[[2,0]] if alias else [],
   actors=[[0,[d(0x70,300),d(0x7c,300),d(0x8c,2),d(0x90,0)]],[1,[d(0x368,1),d(0x70,300),d(0x7c,300),d(0x8c,3)]],[2,[d(0x368,3),d(0x70,301),d(0x7c,301),d(0x90,0)]]],
   frames=[f(0,300,0x88,1),f(1,300,0x88,1),f(1,300,0xac,3),f(3,301,0x88,2)])
 for stage in ('actions','placement','cleanup','caller'):
  yield dict(label='all400-'+stage,group='all-slots',stage=stage,active=[[n,1] for n in range(400)])
  yield dict(label='empty-'+stage,group='empty',stage=stage)
def main():
 path=ROOT/'build/original/world-cpoints.json';vm=WorldCPoints();cases=[]
 for n,item in enumerate(probes()):
  cases.append(vm.probe(item,n))
  if (n+1)%500==0:print('WORLD CPOINTS',n+1,flush=True)
 doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,ids=IDS,states=STATES,header=HEADER,baseActor=[d(0x31c,20)],cases=cases,instructions=sorted(vm.instructions),fpcw=0x37f)
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),instructions=len(vm.instructions),events=sum(len(c['events']) for c in cases),nativeCompared=False)
 (ROOT/'build/research/world-cpoints.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
