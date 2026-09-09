#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Original whole42e100..431b64 and41eefb..41f2ac type-separated caller.
Synthetic400-slot pool and raw Frame heap; actual original helpers and actual
pinned VC80 rand on its retained supplied PTD via the declared IAT boundary.
Full pool/masks/globals and mutable Frame heap SHA, ordered sound/game RNG/CRT
requests. Source capture for the complete hit-resolution study, not a full match.
"""
import argparse,itertools,json,struct
from collections import Counter
from oracle_world_contacts import WorldContacts,IDS,STATES,HEAP,itr,bdy,f,h,paircase
from oracle_world_control import WORLD,POOL,OBJECT,CATALOG,BODY_SP,HEADER,REGS,d,b,q,digest
from oracle_actor_control import ActorControl,GLOBAL_BASE,GLOBAL_SIZE
from oracle_state import ACTOR_SIZE,WORLD_PREFIX,STOP
from oracle_crt import CRT,DLL_SHA256
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_MEM_READ,UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW
CRT_RAND=STOP+0x800
CALLS={0x42e100:(1,4),0x417170:(2,0),0x416fb0:(2,0),0x417090:(2,0),0x4450d0:(0,0),0x4061d0:(0,0)}
def signed(x):return (x+2**31)%2**32-2**31
class WorldHits(WorldContacts):
 arithmetic_control_word=0x37f # Historical default; precision revalidation supplies its own context.
 def __init__(self):
  super().__init__();self.crt=CRT()
 def access(self,uc,access,address,size,value,data):
  if self.running and HEAP<=address<HEAP+0x40000:
   assert any(lo<=address<address+size<=hi for lo,hi in self.heap_extents),(hex(uc.reg_read(UC_X86_REG_EIP)),hex(address),size)
   return
  super().access(uc,access,address,size,value,data)
 def code(self,uc,pc,size,data):
  if not self.running:return
  if pc==0x4450a0:return
  sp=uc.reg_read(UC_X86_REG_ESP)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop();assert sp==h['sp']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGS],h
   self.helpers+=1
   if h['entry']==0x417170:self.events.append(dict(kind='random',arguments=h['args']+[uc.reg_read(UC_X86_REG_EAX)]))
  if pc==STOP or (self.caller and pc==0x41f2ac):
   assert not self.pending;self.finished=True;uc.emu_stop();return
  if pc==CRT_RAND:
   saved=[uc.reg_read(r) for r in REGS];r=self.crt.random_call();self.events.append(dict(kind='crtRandom',arguments=[r['before'],r['after'],r['result']]))
   uc.reg_write(UC_X86_REG_EAX,r['result']);uc.reg_write(UC_X86_REG_ESP,sp+4);uc.reg_write(UC_X86_REG_EIP,self.u32(sp));assert saved==[uc.reg_read(r) for r in REGS];return
  self.instructions.add(pc)
  if pc in CALLS:
   count,pop=CALLS[pc];args=[self.u32(sp+4+4*i) for i in range(count)]
   if pc==0x4061d0:
    self.target=uc.reg_read(UC_X86_REG_ECX);n,offset=divmod(self.target-POOL,0x500);assert offset==0 and 0<=n<400
    self.size=ACTOR_SIZE;self.mask=self.masks[n];self.writes=[]
    self.events.append(dict(kind='reconstruct',arguments=[self.u32(BODY_SP+0x4c)]))
   self.pending.append(dict(entry=pc,sp=sp,pop=pop,returnPC=self.u32(sp),args=args,saved=[uc.reg_read(r) for r in REGS]))
   if pc in (0x416fb0,0x417090):self.events.append(dict(kind='catalogSound' if pc==0x416fb0 else 'builtinSound',arguments=args))
  assert any(lo<=pc<=hi for lo,hi in [(0x41eefb,0x41f2ac),(0x42e100,0x431b64),(0x4061d0,0x4064cf),(0x416fb0,0x4171bc),(0x4450d0,0x44517a)]),hex(pc)
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
  self.uc.mem_write(0x447198,struct.pack('<I',CRT_RAND))
  self.caller=item.get('caller',False);entry=0x41eefb if self.caller else 0x42e100;args=[] if self.caller else [item.get('attacker',0)]
  item['entry']=entry
  if self.caller:
   self.uc.mem_write(BODY_SP+0x4c,struct.pack('<i',item['retainedSpawnSlot']))
   bg=bytearray(0x990)
   for offset,value in item['background']:bg[offset:offset+len(bytes.fromhex(value))]=bytes.fromhex(value)
   self.uc.mem_write(CATALOG+0x4d45db0,bytes(bg))
  self.entry_sp=BODY_SP if self.caller else BODY_SP-8;self.uc.mem_write(self.entry_sp,struct.pack('<'+'I'*(1+len(args)),STOP,*[v&0xffffffff for v in args]))
  self.uc.reg_write(UC_X86_REG_ESP,self.entry_sp);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  saved=[WORLD if self.caller else 0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGS,saved):self.uc.reg_write(r,v)
  self.crt.random_call(item.get('crtSeed',1));self.uc.reg_write(UC_X86_REG_FPCW,self.arithmetic_control_word);self.running=True
  try:self.uc.emu_start(entry,0,count=10_000_000)
  except Exception:print('WORLD HITS FAILURE',item['label'],hex(self.uc.reg_read(UC_X86_REG_EIP)),flush=True);raise
  finally:self.running=False
  assert self.finished and not self.pending and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP and (self.caller or [self.uc.reg_read(r) for r in REGS]==saved), (item['label'],self.finished,self.pending,hex(self.uc.reg_read(UC_X86_REG_EIP)),hex(self.uc.reg_read(UC_X86_REG_ESP)))
  if self.caller:assert self.uc.reg_read(REGS[0])==WORLD and bytes(self.uc.mem_read(CATALOG+0x4d45db0,len(bg)))==bg
  assert self.uc.reg_read(UC_X86_REG_FPCW)==self.arithmetic_control_word and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  if entry==0x417200:item['result']=self.uc.reg_read(UC_X86_REG_EAX)
  world=bytearray(self.uc.mem_read(WORLD,WORLD_PREFIX))
  item['heapSHA256']=digest(bytes(self.uc.mem_read(HEAP,len(heap))))
  item['crtAfter']=self.crt.random_state
  for i,raw in enumerate(objects):assert bytes(self.uc.mem_read(OBJECT+i*0x40000,len(raw)))==raw
  for i in range(400):struct.pack_into('<I',world,0x194+i*4,bindings.get(i,i))
  struct.pack_into('<I',world,0x7d4,0);pool=world;mask=self.world_mask.copy()
  for i in range(400):
   address=POOL+i*0x500;raw=bytearray(self.uc.mem_read(address,ACTOR_SIZE));ptr=int.from_bytes(raw[0x368:0x36c],'little');assert (ptr-OBJECT)%0x40000==0 and 0<=(ptr-OBJECT)//0x40000<4
   struct.pack_into('<I',raw,0x368,(ptr-OBJECT)//0x40000);pool+=raw;mask+=self.masks[i]
   assert self.uc.mem_read(address-16,16)==b'\x96'*16 and self.uc.mem_read(address+ACTOR_SIZE,16)==b'\x69'*16
  item.update(poolSHA256=digest(pool),maskSHA256=digest(mask),globalsSHA256=digest(bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE))),events=self.events,helpers=self.helpers);return item
def hitcase(label,group,kind=0,effect=0,fall=60,injury=40,arest=0,vrest=1,dvx=3,dvy=-2,bdefend=40,attack=(),**kwargs):
 interaction=itr(kind,vrest,effect,fall);interaction[5]=dvx;interaction[6]=dvy;interaction[8]=arest;interaction[16]=bdefend;interaction[17]=injury
 return paircase(label,group,attack=[d(0x2e4,1),d(0x280,1),b(0x2d0,0),*attack],interactions=[interaction],**kwargs)
def probes():
 for kind,typ,effect in itertools.product(range(18),range(7),(0,1,2,3,4,20,21,22,30,40)):
  interaction=itr(kind,1,effect);interaction[5]=3;interaction[6]=-2;interaction[16]=40;interaction[17]=40
  yield paircase(f'initial-{kind}-{typ}-{effect}','initial',attack=[d(0x2e4,1),d(0x280,1),b(0x2d0,0)],headers=[h(1,0x6f8,typ)],interactions=[interaction])
 for typ,effect,fall,y in itertools.product((0,1,2,3,4,6),(0,1,2,3,4,20,21,22,23,30),(-40,0,20,21,40,41,60,61,100),(0,-1,1)):
  yield hitcase(f'fall-{typ}-{effect}-{fall}-{y}','fall',effect=effect,fall=fall,headers=[h(1,0x6f8,typ)],defender=[d(0x14,y)])
 for injury,divisor,hp,guarded in itertools.product((-2147483648,-100,-1,0,1,9,40,500,2147483647),(-1,0,1,33,150),(0,1,500),(False,True)):
  yield hitcase(f'damage-{injury}-{divisor}-{hp}-{guarded}','damage',injury=injury,attack=[d(0x354,2),b(0x80,1)],defender=[d(0x340,divisor),d(0x2fc,hp),d(0x344,1 if hp==1 else 2)],frames=[f(1,0,8,7 if guarded else 3)])
 for id,effect,bdefend,frame in itertools.product((2,6,37,52),(0,2,3,20,23,30),(0,30,60,61,100),(10,20,110)):
  yield hitcase(f'guard-{id}-{effect}-{bdefend}-{frame}','guard',effect=effect,bdefend=bdefend,attack=[b(0x80,1)],defender=[d(0x70,frame),d(0xb8,0)],headers=[h(1,0x6f4,id)],frames=[f(1,frame,8,7),f(1,0,8,7)])
 for type,face,dvx,vx,impulse in itertools.product((4,6),(0,1,2,255),(-20,-1,0,1,5,20),(-30,-6,-0.1,0,0.1,6,30),(-10,0,10)):
  yield hitcase(f'rebound-{type}-{face}-{dvx}-{vx}-{impulse}','rebound',dvx=dvx,headers=[h(1,0x6f8,type)],attack=[b(0x80,face)],defender=[q(0x40,vx),q(0x28,impulse)])
 for kind,owner,attacking,typ in itertools.product((0,5),(1,2),(-1,0,1,2),(0,2)):
  c=hitcase(f'weapon-{kind}-{owner}-{attacking}-{typ}','weapon',kind=kind,dvx=-19,dvy=-7,attack=[d(0x98,-1),d(0xa0,owner)],headers=[h(1,0x6f8,typ)],frames=[f(1 if owner==1 else 2,0,0xe8,attacking)])
  target=c['actors'][1][1] if owner==1 else []
  target.extend([d(0x9c,0),d(0x368,1 if owner==1 else 2)])
  if owner==2:c['actors'].append([2,target])
  for strength in (1,2):
   for word,value in enumerate([0,0,0,0,0,11,-3,80,7,9,0,1,0,0,0,0,100,60,0,0]):c['headers'].append(h(0,0xb0+strength*80+word*4,value))
  yield c
 for kind,held,reciprocal,defType in itertools.product((0,16),(0,1,2),(0,1),(0,2)):
  c=hitcase(f'drop-{kind}-{held}-{reciprocal}-{defType}','drop',kind=kind,headers=[h(1,0x6f8,defType)],defender=[d(0x98,held),d(0x9c,2)])
  c['actors'].append([2,[d(0x98,-2),d(0xa0,1 if reciprocal else 0)]])
  yield c
 for kind,x,face in itertools.product((1,3),(-2147483648,-30,0,30,2147483647),(0,1)):
  c=hitcase(f'catch-{kind}-{x}-{face}','catch',kind=kind,attack=[d(0x10,x),b(0x80,face)],defender=[d(0x10,17),d(0x14,-3)])
  c['boxes'][0][2][0][12]=12;c['boxes'][0][2][0][14]=34
  c['frames']=[f(0,12,0x8c,30),f(1,34,0x8c,17),f(0,12,0x50,51),f(0,34,0x50,87),f(1,34,0x50,103),f(0,12,0x54,7),f(1,34,0x54,37)]
  yield c
 for aID,dID,aState,dState,held in itertools.product((2,8,209,213),(200,209,214),(3,3000,3005,3006),(3,3005,3006),(0,-1)):
  c=hitcase(f'projectile-{aID}-{dID}-{aState}-{dState}-{held}','projectile',attack=[d(0x98,held),d(0xa0,2)],headers=[h(0,0x6f4,aID),h(1,0x6f4,dID),h(1,0x6f8,3),h(2,0x6f4,209)],frames=[f(0,0,8,aState),f(1,0,8,dState),f(0,10,0x18,-7)])
  c['actors'].append([2,[d(0x364,13),d(0x354,3)]]);yield c
 for kind,typ,state,vy,y in itertools.product((9,10,11,15,16),(0,1,2,3,4,6),(3,1000,2000),(-8,-6,-5,0),(-3,-2,0)):
  yield hitcase(f'force-{kind}-{typ}-{state}-{vy}-{y}','force',kind=kind,defender=[d(0x10,9),d(0x18,-9),q(0x40,4),q(0x50,-3),q(0x48,vy),d(0x14,y),d(0x320,-1)],headers=[h(1,0x6f8,typ)],frames=[f(1,0,8,state)])
 for kind,type,id,held,hp in itertools.product((2,7),(0,1,2,3,4,6),(120,124,201,122),(0,1),(-1,1)):
  yield hitcase(f'pickup-{kind}-{type}-{id}-{held}-{hp}','pickup',kind=kind,attack=[d(0x98,held)],defender=[d(0x2fc,hp)],headers=[h(1,0x6f8,type),h(1,0x6f4,id)])
 for kind,x,z,vx,vz in itertools.product((14,15),(-7,-5,0,5,7),(-3,-2,0,2,3),(-1,0,1),(-1,0,1)):
  yield hitcase(f'obstruction-{kind}-{x}-{z}-{vx}-{vz}','obstruction',kind=kind,attack=[d(0x10,x),d(0x18,z)],defender=[q(0x40,vx),q(0x50,vz),q(0x28,-vx),q(0x38,-vz)])
 for rest,count,latch,bodyKind in itertools.product((-128,0,1,127),(0,1,2),(0,1),(0,1000,1001,1034)):
  yield hitcase(f'early-{rest}-{count}-{latch}-{bodyKind}','early',attack=[d(0x2e4,count),d(0x284,1),b(0x2d1,0),b(0xeb,latch)],defender=[b(0xf0,rest)],bodies=[bdy(bodyKind)],headers=[h(1,0x6f4,300)])
 for face,fall,owner,hurting in itertools.product((0,1),(0,20,60,80),(0,2),(0,1)):
  c=hitcase(f'caught-{face}-{fall}-{owner}-{hurting}','caught',fall=fall,attack=[b(0x80,face)],defender=[d(0x90,owner)],frames=[f(1,0,0x88,2),f(1,0,0x94,222),f(1,0,0x98,224),f(2,0,0xb4,hurting)])
  c['actors'].append([2,[d(0x368,2),d(0x8c,1)]]);yield c
 for kind,flag,face,vx in itertools.product((0,4),(-1,0,1),(0,1,2,255),(-1,0,1)):
  yield hitcase(f'passive-{kind}-{flag}-{face}-{vx}','passive',kind=kind,attack=[d(0x320,flag),b(0x80,face),q(0x40,vx)])
 for guarded,state,face,dvx,dvy,x,y in itertools.product((False,True),(3,1002,2000,3000),(0,1),(-1,0,8),(0,4),(-10,10),(0,-1)):
  yield hitcase(f'reaction-{guarded}-{state}-{face}-{dvx}-{dvy}-{x}-{y}','reaction',dvx=dvx,dvy=dvy,arest=19,vrest=0,attack=[b(0x80,face),d(0x10,x),d(0x98,-1),d(0xa0,2)],defender=[d(0x2fc,1),d(0x14,y)],frames=[f(0,0,8,state),f(1,0,8,7 if guarded else 3)],headers=[h(0,0x6f4,37)])
 for id,typ,face,impulse in itertools.product((100,201,214),(0,2,4,6),(0,1),(-20,-1,0,1,20)):
  c=hitcase(f'id-{id}-{typ}-{face}-{impulse}','hit-ids',dvx=0,attack=[d(0x98,-2),d(0xa0,2),b(0x80,face)],defender=[q(0x28,impulse)],headers=[h(0,0x6f4,id),h(1,0x6f8,typ)],frames=[f(2,0,0xe8,1)])
  c['actors'].append([2,[d(0x368,2),d(0x9c,0)]]);yield c
 for guarded,typ,source in itertools.product((False,True),(0,3),(0,1)):
  yield hitcase(f'sound-{guarded}-{typ}-{source}','sound',attack=[b(0x80,1),d(0x368,source)],headers=[h(0,0x6f8,typ),h(0,0xac,5),h(1,0xa4,7)],frames=[f(1,0,8,7 if guarded else 3)])
 for rest,arest in itertools.product((0,4,5,12,13,127,128,255,256,257),(-1,0,4,12,13)):
  yield hitcase(f'rest-{rest}-{arest}','rest',vrest=rest,arest=arest,attack=[b(0x80,1)],frames=[f(1,0,8,7)])
 for kind,typ,count,alias in itertools.product((0,1,2,3,5,7,8,9,10,14,15,16),(0,2,3),(1,2),(False,True)):
  c=hitcase(f'alias-{kind}-{typ}-{count}-{alias}','alias',kind=kind,attack=[d(0x2e4,count),d(0x284,2),b(0x2d1,0)],headers=[h(0,0x6f8,typ),h(1,0x6f8,typ)],aliases=[[1,0]] if alias else [])
  c['actors'].append([2,[d(0x368,1),d(0x364,3)]]);yield c
 for count in (2,4,10):
  c=hitcase(f'raw-itr-repeat-{count}','raw-itr-repeat',kind=5,dvx=-19,dvy=-7,attack=[d(0x98,-1),d(0xa0,2),d(0x2e4,count),*[d(0x280+i*4,1) for i in range(count)],*[b(0x2d0+i,0) for i in range(count)]],headers=[h(1,0x6f8,2)],frames=[f(2,0,0xe8,0)])
  c['actors'].append([2,[d(0x368,2),d(0x9c,0)]]);yield c
 for kind,team,owner in itertools.product((10,16),(0,1,2,3),(-1,0)):
  yield hitcase(f'force-stats-{kind}-{team}-{owner}','force-stats',kind=kind,injury=200,defender=[d(0x340,50),d(0x2fc,100),d(0x344,team),d(0x2f4,owner)])
 for seed,mode,override,free in itertools.product((0,1,197,199),(0,1,2,3,4,5),(0,57,1000),(50,53)):
  c=dict(label=f'items-{seed}-{mode}-{override}-{free}',group='items',caller=True,retainedSpawnSlot=77,background=[d(0,1200),d(4,400),d(8,600)],headers=[h(i,0x6f4,id) for i,id in enumerate((99,100,122,123))],globals=[d(0x450c34,seed),d(0x451160,mode),d(0x450bb4,override)],active=[[n,1] for n in range(50,free)],actors=[])
  yield c
 for n in (0,1,3,4,5):
  yield dict(label=f'item-cap-{n}',group='items-cap',caller=True,retainedSpawnSlot=77,background=[d(0,1200),d(4,400),d(8,600)],headers=[h(0,0x6f8,1),h(1,0x6f4,100)],active=[[i,1] for i in range(n)])
 yield dict(label='full-pool-retained-slot',group='items-full',caller=True,retainedSpawnSlot=77,background=[d(0,1200),d(4,400),d(8,600)],headers=[h(0,0x6f8,3),h(1,0x6f4,100)],active=[[i,1] for i in range(400)],globals=[d(0x450c34,197)])
 for face,dvx,impulse in itertools.product((0,1),(1,3,20),(-20,-1,0,1,20)):
  yield hitcase(f'bat-{face}-{dvx}-{impulse}','bat',dvx=dvx,attack=[d(0x98,-1),d(0xa0,2),b(0x80,face)],defender=[q(0x28,impulse),q(0x40,7)],headers=[h(0,0x6f4,100),h(1,0x6f8,4)])
 for typ,fall in itertools.product((0,2,3,4),(0,40,41,80)):
  yield hitcase(f'vertical-zero-{typ}-{fall}','vertical-zero',dvx=0,dvy=0,fall=fall,vrest=0,arest=0,attack=[d(0x98,-2),d(0xa0,2)],defender=[d(0xb0,80),b(0x80,1),q(0x28,-5)],headers=[h(0,0x6f8,4),h(1,0x6f8,typ)],frames=[f(0,0,8,1002)])
 for guarded,effect,y,x,face in itertools.product((False,True),(22,23),(0,-1),(-10,10),(0,1)):
  yield hitcase(f'radial-{guarded}-{effect}-{y}-{x}-{face}','radial',effect=effect,bdefend=20,dvx=-8,attack=[b(0x80,face)],defender=[d(0x10,x),d(0x14,y)],frames=[f(1,0,8,7 if guarded else 3)])
 for id,count in itertools.product((8,213),(0,1,4)):
  yield hitcase(f'missing-reflection-{id}-{count}','missing-reflection',count=count,headers=[h(0,0x6f4,id),h(1,0x6f8,3),h(1,0x6f4,200)],attack=[d(0x98,-1),d(0xa0,2)])
 yield hitcase('kind9-state3005','kind9-state3005',kind=9,headers=[h(1,0x6f8,3)],frames=[f(1,0,8,3005)])
 yield hitcase('type2-pull-positive-z','type2-pull-positive-z',kind=15,headers=[h(1,0x6f8,2)],defender=[d(0x18,20)])
 for az,dz,face in itertools.product((-5,0,5),(-5,0,5),(0,1)):
  yield hitcase(f'spark-owner-{az}-{dz}-{face}','spark-owner',attack=[d(0x18,az),b(0x80,face)],defender=[d(0x18,dz)],crtSeed=0xffffffff)
 for vy,y,sse2 in itertools.product((-9223372036854775808.0,-4294967296.5,-1e-9,-3e-10,0,1e-9,4294967295.5,9223372036854775808.0),(-2147483648,0,2147483647),(0,1)):
  yield hitcase(f'extended-{vy}-{y}-{sse2}','extended',dvy=1,fall=80,defender=[q(0x30,vy),d(0x14,y)],sse2=sse2)
 for frame in (-2147483648,-1,400,2147483647):
  for count in (-1,0):yield hitcase(f'no-frame-read-{frame}-{count}','no-frame-read',attack=[d(0x7c,frame),d(0x2e4,count)])
  yield hitcase(f'no-defender-frame-read-{frame}','no-frame-read',defender=[d(0x7c,frame),b(0xf0,1)])
 yield hitcase('air-guard-forward-impulse','air-guard-forward',dvx=-3,attack=[b(0x80,0)],defender=[d(0x14,-1)],frames=[f(1,0,8,7)])
 c=hitcase('reverse-slot-spark-tie','reverse-slot-spark',attack=[d(0x280,0)],attacker=1)
 for actor in c['actors']:actor[0]=1-actor[0]
 yield c
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--limit',type=int);a=p.parse_args();vm=WorldHits();cases=[]
 for n,item in enumerate(itertools.islice(probes(),a.limit)):
  cases.append(vm.probe(item,n))
  if (n+1)%100==0:print('WORLD HITS',n+1,flush=True)
 doc=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,ids=IDS,states=STATES,header=HEADER,baseActor=[d(0x31c,20)],cases=cases,instructions=sorted(vm.instructions),fpcw=0x37f)
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original/world-hits.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),instructions=len(vm.instructions),events=sum(len(c['events']) for c in cases),nativeCompared=False)
 (ROOT/'build/research/world-hits.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
