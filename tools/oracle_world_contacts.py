#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole419380/417200/417400/4171c0 and mandatory4064d0 fusion tail.
Declared synthetic400-slot pool, four raw Objects/Frames and bounded ITR/BDY
allocations. All original helper bodies/ABIs, full pool bytes/masks/globals,
ordered RNG/reconstruction events. Only constructor memset remains a boundary.
Not a natural match or exhaustive source DAT/reachable-sequence corpus.
"""
import argparse,base64,itertools,json,os,struct,subprocess,zlib
from collections import Counter
from oracle_world_control import WorldControl,WORLD,POOL,OBJECT,CATALOG,BODY_SP,HEADER,REGS,d,b,q,digest
from oracle_actor_control import ActorControl,GLOBAL_BASE,GLOBAL_SIZE
from oracle_state import ACTOR_SIZE,WORLD_PREFIX,STOP
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_MEM_READ,UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW
IDS=[2,7,8,51];STATES={300:2,301:12,302:10,303:18,304:19,305:13,306:16,307:1004,308:2004,309:1001,310:14};HEAP=0x51000000
CALLS={0x419380:(1,4),0x417200:(2,8),0x417400:(3,12),0x4171c0:(8,0),0x417170:(2,0),0x4064d0:(0,0),0x4061d0:(0,0),0x4034e0:(1,0)}
def signed(x):return (x+2**31)%2**32-2**31
class WorldContacts(WorldControl):
 def __init__(self):
  super().__init__();self.uc.mem_map(HEAP,0x40000);self.uc.ctl_remove_cache(STOP,STOP+0x1000)
 def written(self,*args):
  if not self.running:super().written(*args)
 def access(self,uc,access,address,size,value,data):
  if self.running and WORLD<=address<WORLD+WORLD_PREFIX and access==UC_MEM_WRITE:
   assert WORLD+4<=address<address+size<=WORLD+404
   self.world_mask[address-WORLD:address-WORLD+size]=b'\1'*size;return
  if self.running and HEAP<=address<HEAP+0x40000:
   assert access==UC_MEM_READ and any(lo<=address<address+size<=hi for lo,hi in self.heap_extents),(hex(uc.reg_read(UC_X86_REG_EIP)),hex(address),size)
   return
  super().access(uc,access,address,size,value,data)
 def code(self,uc,pc,size,data):
  if not self.running:return
  if pc==0x4450a0:return
  sp=uc.reg_read(UC_X86_REG_ESP)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop();assert sp==h['sp']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGS],h
   self.helpers+=1
   if h['entry']==0x417170:self.events.append(dict(kind='random',arguments=h['pair']+h['args']+[uc.reg_read(UC_X86_REG_EAX)]))
  if pc==STOP or (self.caller and pc==0x41eefb):
   assert not self.pending;self.finished=True;uc.emu_stop();return
  self.instructions.add(pc)
  if pc in CALLS:
   count,pop=CALLS[pc];args=[self.u32(sp+4+4*i) for i in range(count)]
   if pc==0x417170:pair=next(h['args'][:2] for h in reversed(self.pending) if h['entry']==0x417400)
   else:pair=[]
   if pc==0x4061d0:
    owner=next(h for h in reversed(self.pending) if h['entry']==0x4064d0)
    self.target=uc.reg_read(UC_X86_REG_ECX);n,offset=divmod(self.target-POOL,0x500);assert offset==0 and 0<=n<400
    self.size=ACTOR_SIZE;self.mask=self.masks[n];self.writes=[]
    self.events.append(dict(kind='reconstruct',arguments=[self.u32(owner['sp']-12),uc.reg_read(REGS[3])]))
   self.pending.append(dict(entry=pc,sp=sp,pop=pop,returnPC=self.u32(sp),args=args,pair=pair,saved=[uc.reg_read(r) for r in REGS]))
  assert any(lo<=pc<=hi for lo,hi in [(0x41eed8,0x41eefb),(0x419380,0x4196df),(0x417170,0x4173fa),(0x417400,0x417f7b),(0x4061d0,0x406a1f),(0x4034e0,0x4034ea)]),hex(pc)
 def probe(self,item,index):
  item=dict(item,fill='a5' if index%2==0 else 'ramp');template=self.templates[item['fill']]
  self.pending=[];self.events=[];self.helpers=0;self.finished=False
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
  write(world,self.world_mask,*d(0x7d4,CATALOG));self.uc.mem_write(WORLD,bytes(world));objects=[];heap=bytearray(0x40000);self.heap_extents=[];cursor=0
  for i,id in enumerate(IDS):
   raw=bytearray(ActorControl.object_bytes(self,{}));struct.pack_into('<ii',raw,0x6f4,id,0)
   for n in range(400):struct.pack_into('<i',raw,0x7ac+n*0x178,STATES.get(n,3))
   for obj,n,interactions,bodies in item.get('boxes',[]):
    if obj!=i:continue
    for boxes,countoff,ptroff,boundoff,stride in [(interactions,0x128,0x130,0x138,20),(bodies,0x12c,0x134,0x148,10)]:
     struct.pack_into('<i',raw,0x7a4+n*0x178+countoff,len(boxes))
     if not boxes:continue
     assert len(boxes)<=5 and all(len(box)==stride for box in boxes)
     storage=b''.join(struct.pack('<'+'i'*stride,*box) for box in boxes);size=5*stride*4
     heap[cursor:cursor+len(storage)]=storage;self.heap_extents.append((HEAP+cursor,HEAP+cursor+len(storage)))
     struct.pack_into('<I',raw,0x7a4+n*0x178+ptroff,HEAP+cursor);cursor+=size
     x=min(box[1] for box in boxes);y=min(box[2] for box in boxes)
     right=max(signed(box[1]+box[3]) for box in boxes);bottom=max(signed(box[2]+box[4]) for box in boxes)
     struct.pack_into('<iiii',raw,0x7a4+n*0x178+boundoff,x,y,signed(right-x),signed(bottom-y))
   for obj,offset,h in item.get('headers',[]):
    if obj==i:raw[offset:offset+len(bytes.fromhex(h))]=bytes.fromhex(h)
   for obj,n,offset,h in item.get('frames',[]):
    if obj==i:raw[0x7a4+n*0x178+offset:0x7a4+n*0x178+offset+len(bytes.fromhex(h))]=bytes.fromhex(h)
   objects.append(bytes(raw));self.uc.mem_write(OBJECT+i*0x40000,bytes(raw));self.uc.mem_write(CATALOG+4*i,struct.pack('<I',OBJECT+i*0x40000))
  self.uc.mem_write(CATALOG+0x4d82380,struct.pack('<i',item.get('count',4)))
  self.uc.mem_write(HEAP,bytes(heap))
  glob=bytearray(GLOBAL_SIZE);glob[0x44ff90-GLOBAL_BASE:0x44ff90-GLOBAL_BASE+3000]=bytes(1+i%255 for i in range(3000));struct.pack_into('<i',glob,0x44d034-GLOBAL_BASE,1)
  for address,h in item.get('globals',[]):glob[address-GLOBAL_BASE:address-GLOBAL_BASE+len(bytes.fromhex(h))]=bytes.fromhex(h)
  self.uc.mem_write(GLOBAL_BASE,bytes(glob));self.uc.mem_write(0x45971c,struct.pack('<I',item.get('sse2',0)))
  entry=item.get('entry',0x419380);self.caller=entry==0x41eed8;args={0x41eed8:[],0x419380:[item.get('mode',0)],0x4064d0:[],0x417400:item.get('pair',[0,1])+[item.get('mode',0)],0x417200:item.get('pair',[0,1])}[entry]
  self.entry_sp=BODY_SP if self.caller else BODY_SP-4-len(args)*4;self.uc.mem_write(self.entry_sp,struct.pack('<'+'I'*(1+len(args)),STOP,*[v&0xffffffff for v in args]))
  self.uc.reg_write(UC_X86_REG_ESP,self.entry_sp);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  saved=[WORLD if self.caller else 0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGS,saved):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_FPCW,0x37f);self.running=True
  try:self.uc.emu_start(entry,0,count=10_000_000)
  except Exception:print('WORLD CONTACTS FAILURE',item['label'],hex(self.uc.reg_read(UC_X86_REG_EIP)),flush=True);raise
  finally:self.running=False
  assert self.finished and not self.pending and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP and [self.uc.reg_read(r) for r in REGS]==saved, (item['label'],self.finished,self.pending,hex(self.uc.reg_read(UC_X86_REG_EIP)),hex(self.uc.reg_read(UC_X86_REG_ESP)))
  assert self.uc.reg_read(UC_X86_REG_FPCW)==0x37f and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  if entry==0x417200:item['result']=self.uc.reg_read(UC_X86_REG_EAX)
  world=bytearray(self.uc.mem_read(WORLD,WORLD_PREFIX))
  assert bytes(self.uc.mem_read(HEAP,len(heap)))==bytes(heap)
  for i,raw in enumerate(objects):assert bytes(self.uc.mem_read(OBJECT+i*0x40000,len(raw)))==raw
  for i in range(400):struct.pack_into('<I',world,0x194+i*4,bindings.get(i,i))
  struct.pack_into('<I',world,0x7d4,0);pool=world;mask=self.world_mask.copy()
  for i in range(400):
   address=POOL+i*0x500;raw=bytearray(self.uc.mem_read(address,ACTOR_SIZE));ptr=int.from_bytes(raw[0x368:0x36c],'little');assert (ptr-OBJECT)%0x40000==0 and 0<=(ptr-OBJECT)//0x40000<4
   struct.pack_into('<I',raw,0x368,(ptr-OBJECT)//0x40000);pool+=raw;mask+=self.masks[i]
   assert self.uc.mem_read(address-16,16)==b'\x96'*16 and self.uc.mem_read(address+ACTOR_SIZE,16)==b'\x69'*16
  item.update(poolSHA256=digest(pool),maskSHA256=digest(mask),globalsSHA256=digest(bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE))),events=self.events,helpers=self.helpers);return item
def f(obj,n,offset,value):return [obj,n,*d(offset,value)]
def h(obj,offset,value):return [obj,*d(offset,value)]
def itr(kind=0,rest=0,effect=0,fall=60,zwidth=0,box=(-20,-20,40,40)):
 r=[0]*20;r[0]=kind;r[1:5]=box;r[7]=fall;r[9]=rest;r[11]=effect;r[18]=zwidth;return r
def bdy(kind=0,box=(-20,-20,40,40)):return [kind,*box,0,0,0,0,0]
def paircase(label,group,attack=(),defender=(),frames=(),headers=(),interactions=None,bodies=None,entry=0x417400,**kwargs):
 return dict(label=label,group=group,entry=entry,active=[[0,1],[1,1]],actors=[[0,[d(0x368,0),d(8,0),d(0x2e8,9999),d(0x2ec,9999),d(0x364,1),*attack]],[1,[d(0x368,1),d(8,0),d(0x2e8,9999),d(0x2ec,9999),d(0x364,2),*defender]]],
  boxes=[[0,0,interactions if interactions is not None else [itr()],[]],[1,0,[],bodies if bodies is not None else [bdy()]]],frames=frames,headers=headers,**kwargs)
def probes():
 for kind,state,rest,buttons in itertools.product(range(-1,19),(0,301,302,303,304,305,306,307,308),(0,1),(0,1)):
  yield paircase(f'kind-{kind}-{state}-{rest}-{buttons}','kinds',interactions=[itr(kind,rest)],defender=[d(0x70,state),d(0x7c,state)],attack=[b(0xd0,buttons),b(0xcf,buttons),b(0xd1,buttons)],frames=[f(1,state,0x12c,1),f(1,state,0x134,HEAP+400)])
 for kind,typ,team,state in itertools.product((-1,0,1,2,3,5,6,8,9,10,11,14,15,16),(0,1,2,3,4,6),(0,1,2),(0,303,305)):
  yield paircase(f'team-{kind}-{typ}-{team}-{state}','teams',interactions=[itr(kind,1)],headers=[h(1,0x6f8,typ)],attack=[d(0x364,team),d(0x70,state),b(0x80,1)],defender=[d(0x364,team)],frames=[f(0,state,8,STATES.get(state,3))])
 for effect,oldA,oldD,typ,inv in itertools.product((0,2,4,20,21,22,30),(0,303,304),(0,303,304),(0,3),(0,1)):
  yield paircase(f'effect-{effect}-{oldA}-{oldD}-{typ}-{inv}','effects',interactions=[itr(0,1,effect)],attack=[d(0x78,oldA)],defender=[d(0x78,oldD),d(8,inv)],headers=[h(1,0x6f8,typ)])
 for aid,did,kind,af,df in itertools.product((199,200,203,205,206,207,215,216,212),(209,212),(0,5,9),(0,10),(0,5)):
  yield paircase(f'ids-{aid}-{did}-{kind}-{af}-{df}','source-ids',interactions=[itr(kind,1)],attack=[d(0x70,af)],defender=[d(0x70,df),d(0x364,1)],headers=[h(0,0x6f4,aid),h(1,0x6f4,did)])
 for mode,typ,aid,team,held,ownerActive,bodyKind in itertools.product((0,1),(0,1),(2,201,202),(1,5),(0,-1),(0,1,2),(999,1000)):
  c=paircase(f'mode-{mode}-{typ}-{aid}-{team}-{held}-{ownerActive}-{bodyKind}','mode',mode=mode,interactions=[itr(0,1)],bodies=[bdy(bodyKind)],attack=[d(0x98,held),d(0xa0,2),d(0x364,team)],headers=[h(0,0x6f4,aid),h(0,0x6f8,typ)])
  c['active'].append([2,ownerActive]);c['actors'].append([2,[d(0x368,1),d(0x364,1)]]);yield c
 for faceA,faceD,dx,dz,zw in itertools.product((0,1,255),(0,1),(-40,-39,0,39,40,2147483647),(-15,-14,0,14,15),(0,1,-1,15)):
  yield paircase(f'geometry-{faceA}-{faceD}-{dx}-{dz}-{zw}','geometry',attack=[b(0x80,faceA),d(0x10,dx),d(0x18,dz)],defender=[b(0x80,faceD)],interactions=[itr(0,1,zwidth=zw)],frames=[f(0,0,0x50,7),f(1,0,0x50,-11),f(0,0,0x54,9),f(1,0,0x54,-13)])
 for kind,rest,fall,count,near,owner in itertools.product((0,1,2,7,10),(0,1),(40,41),(-1,0,19,20),(0,9999),(-1,0,1)):
  c=paircase(f'list-{kind}-{rest}-{fall}-{count}-{near}-{owner}','lists',interactions=[itr(kind,rest,fall=fall)]*5,bodies=[bdy()]*5,attack=[d(0x2e4,count),d(0x2e8,near),b(0xd0,1),b(0xcf,1),b(0xd1,1),d(0x98,owner),d(0xa0,1)],defender=[d(0x2ec,near),d(0x70,306)],globals=[d(0x450bcc,2999),d(0x450c34,1233)])
  yield c
 for entry,activity,arest,vrest,state,ownerAttack in itertools.product((0x419380,0x417200),(0,1,255),(-1,0,1),(-128,-1,0,1,2,127),(0,309),(0,1)):
  c=paircase(f'rest-{entry}-{activity}-{arest}-{vrest}-{state}-{ownerAttack}','rest-prefix',entry=entry,attack=[d(0xec,arest),d(0x70,state),d(0xa0,1),b(0xf1,vrest&255)],defender=[b(0xf0,vrest&255)],frames=[f(0,state,0x128,1),f(0,state,0x130,HEAP),*[f(0,state,0x138+o*4,v) for o,v in enumerate((-20,-20,40,40))],f(1,0,0xe8,ownerAttack)])
  c['active'][1][1]=activity;yield c
 for main,other,alias,rest in itertools.product((0,1,19,199,399),(0,1,19,199,399),(False,True),(0,2)):
  if main==other:continue
  c=paircase(f'order-{main}-{other}-{alias}-{rest}','slot-order',entry=0x419380,interactions=[itr(0,1)],attack=[b(0xf0+other,rest)],defender=[b(0xf0+main,rest)])
  c['active']=[[main,1],[other,1]];c['actors'][0][0]=main;c['actors'][1][0]=other
  if alias:c['aliases']=[[other,main]]
  yield c
 for slot,other,hp,cooldown,flag,x,z,state,activity in itertools.product((0,9,10),(1,11),(176,177),(0,1),(0,1),(20,50),(7,8),(300,0),(1,2)):
  if slot==other:continue
  yield dict(label=f'fusion-{slot}-{other}-{hp}-{cooldown}-{flag}-{x}-{z}-{state}-{activity}',group='fusion',entry=0x4064d0,active=[[slot,activity],[other,1]],actors=[[slot,[d(0x368,1),d(0x70,300),d(0x2fc,hp),d(0x338,cooldown),d(0x364,1),d(0x10,x),d(0x18,z)]],[other,[d(0x368,2),d(0x70,state),d(0x2fc,100),d(0x364,1)]]],globals=[d(0x458428,flag)])
 for slot,other,alias,count,frame,cooldown,ids in itertools.product((0,19),(0,10),(False,True),(-1,0,2,4),(0,8,9,260,261),(0,1,2),((7,8),(8,7),(7,7),(99,98))):
  yield dict(label=f'unfusion-{slot}-{other}-{alias}-{count}-{frame}-{cooldown}-{ids}',group='unfusion',entry=0x4064d0,count=count,active=[[slot,1]],aliases=[[other,slot]] if alias and other!=slot else [],actors=[[slot,[d(0x368,3),d(0x70,frame),d(0x328,1),d(0x32c,other),d(0x338,cooldown),d(0x330,ids[0]),d(0x334,ids[1]),d(0x2fc,177),d(0x300,179),b(0x80,255)]]])
 for duplicate,target in itertools.product((7,8,51),(0,10)):
  yield dict(label=f'duplicate-{duplicate}-{target}',group='duplicate-fusion',entry=0x4064d0,active=[[0,1]],headers=[h(0,0x6f4,duplicate)],actors=[[0,[d(0x368,3),d(0x328,1),d(0x32c,target),d(0x330,7),d(0x334,8),d(0x338,0)]]])
 for entry,faceA,faceD,coordinate in itertools.product((0x417200,0x419380),(0,1,255),(0,1,255),(-2147483648,-40,0,40,2147483647)):
  yield paircase(f'broad-{entry}-{faceA}-{faceD}-{coordinate}','broad-mirror',entry=entry,attack=[b(0x80,faceA),d(0x10,coordinate)],defender=[b(0x80,faceD)],frames=[f(0,0,0x50,7),f(1,0,0x50,-11)])
 for kind,fall,inv,frame in itertools.product((0,8,10,11,14),(-1,40,41),(-1,0,1),(199,200,201,202,203,301)):
  yield paircase(f'state-effect-{kind}-{fall}-{inv}-{frame}','state-effect-gates',interactions=[itr(kind,1,effect=30,fall=fall)],defender=[d(0x70,frame),d(8,inv)])
 for kind,typ,held,state,owner,x,near,flag in itertools.product((0,1,4),(0,1),(-1,0),(0,307),(0,1,2),(-5,5),(0,5,9999),(0,1)):
  c=paircase(f'held-distance-{kind}-{typ}-{held}-{state}-{owner}-{x}-{near}-{flag}','held-distance',interactions=[itr(kind,0 if kind==0 else 1)],attack=[d(0x98,held),d(0xa0,owner),d(0x10,x),d(0x2e8,near),d(0x320,flag),b(0xcf,1),b(0xd0,1)],defender=[d(0x2ec,near)],headers=[h(0,0x6f8,typ)],frames=[f(1,0,8,STATES.get(state,3))])
  c['actors'].append([2,[d(0x10,-21)]]);yield c
 for slot,state,attacking in itertools.product(range(5),(0,309),(0,1)):
  yield dict(label=f'prefix-lane-{slot}-{state}-{attacking}',group='prefix-lanes',active=[[slot,1]],actors=[[slot,[d(0x70,state),d(0xec,9),d(0xa0,19)]]],frames=[f(0,state,0x128,1),f(0,0,0xe8,attacking)])
 for count,hp,red,maximum in itertools.product((0,3,4),(100,176),(-1,10,200),(50,500)):
  yield dict(label=f'fusion-clamp-{count}-{hp}-{red}-{maximum}',group='fusion-clamp',entry=0x4064d0,count=count,active=[[0,1],[1,1]],actors=[[0,[d(0x368,1),d(0x70,300),d(0x2fc,hp),d(0x300,red),d(0x304,maximum),d(0x10,20),d(0x364,1)]],[1,[d(0x368,2),d(0x70,300),d(0x2fc,100),d(0x300,red),d(0x364,1)]]])
 for flag in (-1,0,1,2,3):
  yield paircase(f'caller-flag-{flag}','caller',entry=0x41eed8,globals=[d(0x44d05c,flag),d(0x451160,1)],attack=[d(0x7c,219),d(0x338,2)])
 yield dict(label='all400-active-no-itr',group='all-slots',active=[[i,1] for i in range(400)],actors=[[i,[d(0x338,2)]] for i in range(400)])
 yield dict(label='empty-cooldown',group='empty',actors=[[i,[d(0x338,2)]] for i in range(400)])
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accept',action='store_true');p.add_argument('--limit',type=int);a=p.parse_args();path=ROOT/'build/original/world-contacts.json';report_path=ROOT/'build/research/world-contacts.json'
 if not a.accept:
  vm=WorldContacts();cases=[]
  for n,item in enumerate(itertools.islice(probes(),a.limit)):
   cases.append(vm.probe(item,n))
   if (n+1)%500==0:print('WORLD CONTACTS',n+1,flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,ids=IDS,states=STATES,header=HEADER,baseActor=[d(0x31c,20)],cases=cases,instructions=sorted(vm.instructions),fpcw=0x37f)
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),instructions=len(vm.instructions),events=sum(len(c['events']) for c in cases),nativeCompared=False)
  report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 else:
  assert a.limit is None
  raw=path.read_bytes();report=json.loads(report_path.read_bytes());assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalWorldContactsTests'],env=dict(os.environ,NTSD_WORLD_CONTACTS_CORPUS=str(path)),check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-world-contacts.json';fixture.write_bytes(packed);report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/world-contacts.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
