#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Entire41b5d0/41a250/41a050 with real43f010/43ef70/415160 children.
Synthetic400-slot pool, Object/Frame/BG/bitmap metadata, stack backing and COM
responses are explicit inputs. Full pool/masks/globals/BG, ordered bitmap reads,
clips and device requests; finiteCW037f. No raster, own launch or Windows claim.
"""
import argparse,base64,itertools,json,os,struct,subprocess,zlib
from collections import Counter
from oracle_world_control import WorldControl,WORLD,POOL,OBJECT,CATALOG,BODY_SP,HEADER,REGS,d,b,q,digest
from oracle_world_links import IDS,BG,f,h
from oracle_actor_control import ActorControl,GLOBAL_BASE,GLOBAL_SIZE
from oracle_state import ACTOR_SIZE,WORLD_PREFIX,STOP
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_MEM_READ
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EDI,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW
BITMAP,TARGET,FILL_TARGET,VTABLE,API=0x72000020,0x72009000,0x72009010,0x72009100,STOP+0x100
STATES={300:14,301:3}
BITMAP_SIZE=0x1f50
HELPERS={0x41a250:4,0x41a050:4,0x43f010:24,0x43ef70:0,0x415160:0,0x4450d0:0}
def signed(v):return (v+0x80000000)%0x100000000-0x80000000
class WorldCamera(WorldControl):
 arithmetic_control_word=0x37f
 def __init__(self):
  super().__init__();self.uc.mem_map(BITMAP&~0xfff,0x10000)
  for p,v in [(TARGET,VTABLE),(FILL_TARGET,VTABLE),(VTABLE+0x14,API)]:self.put(p,v)
 def put(self,p,v):self.uc.mem_write(p,struct.pack('<I',v&0xffffffff))
 def ret(self,v,pop=0):
  sp=self.uc.reg_read(UC_X86_REG_ESP);self.uc.reg_write(UC_X86_REG_EAX,v&0xffffffff);self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp));self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop)
 def written(self,uc,access,p,size,value,data):
  if not getattr(self,'running',False):return super().written(uc,access,p,size,value,data)
  assert WORLD+4<=p<p+size<=WORLD+404
 def access(self,uc,access,p,size,value,data):
  if not self.running:return
  if WORLD<=p<WORLD+WORLD_PREFIX:
   assert p+size<=WORLD+WORLD_PREFIX and all(self.world_mask[p-WORLD:p-WORLD+size])
   if access!=UC_MEM_READ:assert WORLD+4<=p<p+size<=WORLD+404
  elif CATALOG+BG<=p<CATALOG+BG+101*0x990:
   assert p+size<=CATALOG+BG+101*0x990
   offset=p-CATALOG-BG
   if access==UC_MEM_READ:assert all(self.bg_masks[offset:offset+size]),(hex(uc.reg_read(UC_X86_REG_EIP)),hex(offset),size)
   else:
    assert 0x824<=offset%0x990<0x89c and size==4;self.bg_masks[offset:offset+size]=b'\1'*size
  elif BITMAP<=p<BITMAP+4*0x2000:
   assert access==UC_MEM_READ
   n,offset=divmod(p-BITMAP,0x2000);assert offset+size<=BITMAP_SIZE
   if self.bitmap is not None and 0x43f010<=uc.reg_read(UC_X86_REG_EIP)<=0x43f2fe:
    assert n==self.bitmap and size==4
    self.event('read',read=dict(offset=offset,value=self.u32(p),defined=all(self.bitmap_masks[n][offset:offset+4])))
  else:super().access(uc,access,p,size,value,data)
 def event(self,kind,args=(),**kw):self.events.append(dict(kind=kind,arguments=list(args),strings=[],**kw))
 def setup_bitmaps(self,item):
  self.bitmap_bytes=[];self.bitmap_masks=[]
  for n in range(4):
   raw=bytearray(BITMAP_SIZE);mask=bytearray(b'\1'*BITMAP_SIZE)
   struct.pack_into('<4I',raw,0,TARGET,120+10*n,90+10*n,0xffffffff)
   for obj,offset,h in item.get('bitmaps',[]):
    if obj==n:raw[offset:offset+len(bytes.fromhex(h))]=bytes.fromhex(h)
   for obj,offset,count in item.get('undefinedBitmap',[]):
    if obj==n:mask[offset:offset+count]=bytes(count)
   self.uc.mem_write(BITMAP+n*0x2000,bytes(raw));self.bitmap_bytes.append(bytes(raw));self.bitmap_masks.append(mask)
 def code(self,uc,pc,size,data):
  if not getattr(self,'running',False):return
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
  while self.pending and pc==self.pending[-1]['returnPC']:
   c=self.pending.pop();assert sp==c['sp']+4+c['pop'] and c['saved']==[uc.reg_read(r) for r in REGS],c
   self.helpers+=1
   if c['entry']==0x43f010:self.bitmap=None
  if self.clip and pc==self.clip['returnPC']:
   c=self.clip;self.clip=None;assert uc.reg_read(UC_X86_REG_EAX) in (0,1)
   self.event('clip',clip=dict(beforeSource=c['source'],beforeDestination=c['destination'],
    source=[signed(self.u32(p)) for p in c['src']],destination=[signed(self.u32(p)) for p in c['dst']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
  self.instructions.add(pc)
  if pc in HELPERS and not (sp==BODY_SP and pc==0x41a250):
   self.pending.append(dict(entry=pc,sp=sp,pop=HELPERS[pc],returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in REGS]))
  if pc==0x43f010:
   pointer=uc.reg_read(UC_X86_REG_ECX);assert BITMAP<=pointer<BITMAP+4*0x2000 and (pointer-BITMAP)%0x2000==0
   self.bitmap=(pointer-BITMAP)//0x2000;self.event('draw',[self.bitmap+1,*[arg(n) for n in range(6)]])
  elif pc==0x43ef70:
   assert self.clip is None
   src=[arg(i) for i in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
   self.clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
  elif pc==0x415160:self.fill_inputs.append(bytes(uc.mem_read(sp-0x64,100)).hex())
  elif pc==API:
   if arg(4)==0x1000400:
    assert arg(0)==FILL_TARGET and arg(2)==arg(3)==0 and arg(5)!=0
    defined=[i<4 or 0x50<=i<0x54 for i in range(100)]
    self.event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=list(uc.mem_read(arg(5),100)),defined=defined))
   else:
    assert arg(0)==TARGET and arg(2) in (0,TARGET) and arg(5)==0
    self.event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=None))
   self.ret(0x80004005 if len(self.events)%2 else 0,24);return
  assert any(a<=pc<=e for a,e in [(0x41b5d0,0x41bc87),(0x41a050,0x41a590),(0x43ef70,0x43f2fe),(0x415160,0x4151c2),(0x4450d0,0x44517a)]),hex(pc)
 def probe(self,item,index):
  item=dict(item,fill='a5' if index%2==0 else 'ramp');template=self.templates[item['fill']]
  self.pending=[];self.events=[];self.helpers=0;self.clip=None;self.bitmap=None;self.fill_inputs=[];self.stage=item.get('stage','camera')
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
  for i in range(101):
   struct.pack_into('<iii',bg,i*0x990,item.get('width',1600),*item.get('bounds',[0,600]))
  arena=item.get('arena',0)
  for offset,h in item.get('background',[]):
   raw=bytes.fromhex(h);bg[arena*0x990+offset:arena*0x990+offset+len(raw)]=raw
  for offset in ([0x914,0x918,0x91c] if arena==99 else [0x914+4*i for i in range(30)]):
   token=int.from_bytes(bg[arena*0x990+offset:arena*0x990+offset+4],'little')
   if token:struct.pack_into('<I',bg,arena*0x990+offset,BITMAP+(token-1)*0x2000)
  self.bg_masks=bytearray(b'\1'*len(bg))
  for offset,count in item.get('undefinedBackground',[]):self.bg_masks[arena*0x990+offset:arena*0x990+offset+count]=bytes(count)
  self.uc.mem_write(CATALOG+BG,bytes(bg))
  glob=bytearray(GLOBAL_SIZE);glob[0x44ff90-GLOBAL_BASE:0x44ff90-GLOBAL_BASE+3000]=bytes(1+i%255 for i in range(3000));struct.pack_into('<i',glob,0x44d034-GLOBAL_BASE,1)
  for address,h in [d(0x44d024,arena),d(0x44d78c,794),d(0x44d790,550),d(0x455608,FILL_TARGET),*item.get('globals',[])]:glob[address-GLOBAL_BASE:address-GLOBAL_BASE+len(bytes.fromhex(h))]=bytes.fromhex(h)
  self.uc.mem_write(GLOBAL_BASE,bytes(glob));self.uc.mem_write(0x45971c,struct.pack('<I',item.get('sse2',0)))
  self.setup_bitmaps(item)
  self.uc.mem_write(BODY_SP-0x4000,bytes([0xa5 if item['fill']=='a5' else 0x69])*0x4000)
  self.uc.mem_write(BODY_SP,struct.pack('<III',STOP,item.get('target',TARGET),item.get('mode',0)))
  self.uc.reg_write(UC_X86_REG_ESP,BODY_SP);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGS,saved):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_FPCW,self.arithmetic_control_word);self.running=True
  try:self.uc.emu_start(0x41b5d0 if self.stage=='camera' else 0x41a250,STOP,count=2_000_000)
  except Exception:print('WORLD CAMERA FAILURE',item['label'],hex(self.uc.reg_read(UC_X86_REG_EIP)),flush=True);raise
  finally:self.running=False
  assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and not self.pending and self.clip is None
  assert self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP+(12 if self.stage=='camera' else 8) and [self.uc.reg_read(r) for r in REGS]==saved
  assert self.uc.reg_read(UC_X86_REG_FPCW)==self.arithmetic_control_word and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  # Only activity bytes may change in World; normalize the LIVE record below.
  now=bytes(self.uc.mem_read(WORLD,WORLD_PREFIX));assert now[:4]==world[:4] and now[404:]==world[404:];world=bytearray(now)
  after_bg=bytearray(self.uc.mem_read(CATALOG+BG,len(bg)))
  for at in range(len(bg)):
   within=at-arena*0x990
   if not 0x824<=within<0x89c:assert after_bg[at]==bg[at],(item['label'],hex(at))
  for offset in ([0x914,0x918,0x91c] if arena==99 else [0x914+4*i for i in range(30)]):
   at=arena*0x990+offset;pointer=int.from_bytes(after_bg[at:at+4],'little')
   if pointer:struct.pack_into('<I',after_bg,at,(pointer-BITMAP)//0x2000+1)
  for n,raw in enumerate(self.bitmap_bytes):assert bytes(self.uc.mem_read(BITMAP+n*0x2000,len(raw)))==raw
  for i,raw in enumerate(objects):assert bytes(self.uc.mem_read(OBJECT+i*0x40000,len(raw)))==raw
  for i in range(400):struct.pack_into('<I',world,0x194+i*4,bindings.get(i,i))
  struct.pack_into('<I',world,0x7d4,0);pool=world;mask=self.world_mask.copy()
  for i in range(400):
   address=POOL+i*0x500;raw=bytearray(self.uc.mem_read(address,ACTOR_SIZE));ptr=int.from_bytes(raw[0x368:0x36c],'little');assert (ptr-OBJECT)%0x40000==0 and 0<=(ptr-OBJECT)//0x40000<4
   struct.pack_into('<I',raw,0x368,(ptr-OBJECT)//0x40000);pool+=raw;mask+=self.masks[i]
   assert self.uc.mem_read(address-16,16)==b'\x96'*16 and self.uc.mem_read(address+ACTOR_SIZE,16)==b'\x69'*16
  item.update(poolSHA256=digest(pool),maskSHA256=digest(mask),globalsSHA256=digest(bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE))),events=self.events,helpers=self.helpers,backgroundsSHA256=digest(after_bg),backgroundMasksSHA256=digest(self.bg_masks),fillInputs=self.fill_inputs);return item
def layer(index=0,**kw):
 fields=dict(width=(0x464,1200),x=(0x4dc,0),y=(0x554,0),height=(0x5cc,550),step=(0x644,0),period=(0x7ac,0),counter=(0x824,0),start=(0x6bc,0),end=(0x734,100),color=(0x89c,0),bitmap=(0x914,1),key=(0x3ec,0))
 return [d(offset+index*4,kw.get(name,default)) for name,(offset,default) in fields.items()]
def probes():
 for typ,slot,x,sse in itertools.product((-1,0,1,2,3,4,6),(0,19,20,399),(-1e20,-301,-300,-100.1,-100,-.1,-0.,.1,9.9,10,1590,1600,1700,1900,1900.1,1e20),(0,1)):
  yield dict(label=f'bounds-{typ}-{slot}-{x}-{sse}',group='bounds',active=[[slot,255]],actors=[[slot,[q(0x58,x)]]],headers=[h(0,0x6f8,typ)],sse2=sse)
 for typ,bounds,z,sse in itertools.product((0,1,3),([0,600],[600,0],[-2147483648,2147483647],[17,17]),(-1e20,-2147483648.9,-1,-0.,.1,17,599.9,600,600.1,2147483648.,1e20),(0,1)):
  yield dict(label=f'depth-{typ}-{bounds}-{z}-{sse}',group='depth',active=[[0,255]],actors=[[0,[q(0x68,z)]]],headers=[h(0,0x6f8,typ)],bounds=bounds,sse2=sse)
 for slot,team,flag,cap,x in itertools.product((0,19,20,399),(-1,0,5),(0,1,-1),(-1,0,1,200),(-400.,100.,1700.)):
  yield dict(label=f'fighter-{slot}-{team}-{flag}-{cap}-{x}',group='fighter',active=[[slot,1]],actors=[[slot,[q(0x58,x),d(0x364,team),d(8,flag)]]],globals=[d(0x450bb4,cap)])
 for id,team,mode,stage,x,y in itertools.product((121,122,123,124),(-1,0,1),(0,1),(49,50,59,60),(-1.,5.,10.,1595.,1601.),(-1,0,1)):
  yield dict(label=f'items-{id}-{team}-{mode}-{stage}-{x}-{y}',group='items',active=[[0,1]],actors=[[0,[q(0x58,x),d(0x344,team),d(0x14,y)]]],headers=[h(0,0x6f8,1),h(0,0x6f4,id)],mode=mode,globals=[d(0x450b94,stage)])
 for slot,hp,seat,typ,frame,face in itertools.product(range(8),(-1,0,1),(-1,0,1),(0,1),(0,300),(0,1,128,255)):
  if (hp,seat)!=(1,1) and (typ,frame,face)!=(0,0,1):continue
  yield dict(label=f'target-{slot}-{hp}-{seat}-{typ}-{frame}-{face}',group='target',active=[[slot,1],[399,1]],actors=[[slot,[q(0x58,700),d(0x2fc,hp),d(0x70,frame),b(0x80,face)]],[399,[q(0x58,1400)]]],headers=[h(0,0x6f8,typ)],globals=[d(0x450b4c+slot*4,seat)])
 for width,current,velocity,cap in itertools.product((-2147483648,-1,0,100,793,794,795,1600,2147483647),(-2147483648,-15,0,402,2147483647),(-2147483648,-1,0,1,2147483647),(-1,0,100)):
  yield dict(label=f'smooth-{width}-{current}-{velocity}-{cap}',group='smooth',width=width,globals=[d(0x450bc4,current),d(0x450bc8,velocity),d(0x450bb0,cap)])
 for flag1,flag2,position,width in itertools.product((-1,0,1),(-1,0,1),(-2147483648,-1,0,50,2147483647),(100,794,1600)):
  yield dict(label=f'replay-{flag1}-{flag2}-{position}-{width}',group='replay',width=width,globals=[d(0x450b74,flag1),d(0x450b84,flag2),d(0x450b7c,position)])
 for count,face,aliases in itertools.product((1,2,8,399,400),(0,1,128,255),(False,True)):
  yield dict(label=f'sum-{count}-{face}-{aliases}',group='sum',width=2147483647,active=[[i,1] for i in range(count)],actors=[[i,[q(0x58,2147483647.),b(0x80,face)]] for i in range(count)],aliases=[[i,0] for i in range(count)] if aliases else [],globals=[d(0x450b4c+i*4,1) for i in range(8)])
 for camera,width,lwidth,step in itertools.product((-2147483648,-100,0,403,2147483647),(100,793,795,1600),(0,794,1000),(0,1000,-2147483000)):
  yield dict(label=f'parallax-{camera}-{width}-{lwidth}-{step}',group='parallax',stage='background',width=width,background=[d(0x1c,1),*layer(width=lwidth,step=step)],globals=[d(0x450bc4,camera)])
 for step,period,counter,start,end in itertools.product((0,500),(-1,0,1,3,2147483647),(-2147483648,-1,0,2,2147483647),(-1,0,2),(0,1,3)):
  yield dict(label=f'animation-{step}-{period}-{counter}-{start}-{end}',group='animation',stage='background',background=[d(0x1c,1),*layer(width=1000,step=step,period=period,counter=counter,start=start,end=end)])
 for color,xy in itertools.product((0x175317,0x575347,0x977757,0x473f1f,0x80000000,0xffffffff),((-1,-2),(2147483647,-2147483648))):
  yield dict(label=f'fill-{color}-{xy}',group='fill',stage='background',background=[d(0x1c,1),*layer(color=color,x=xy[0],y=xy[1],width=300,height=-10,period=3)])
 for camera in (-2147483648,-300,-1,0,1,100,1069,2147483647):
  yield dict(label=f'builtin-{camera}',group='builtin',stage='background',arena=99,background=[d(0x914,1),d(0x918,2),d(0x91c,3)],globals=[d(0x450bc4,camera)])
 for count in (-1,0,1,30):
  yield dict(label=f'layers-{count}',group='layers',stage='background',background=[d(0x1c,count),*[p for n in range(max(0,count)) for p in layer(n,x=n*100,y=n*20,width=400+10*n,bitmap=1+n%4,key=n%2)]])
 for count in (0,1,0x7fffffff,0xffffffff):
  yield dict(label=f'bitmap-backing-{count}',group='bitmap',stage='background',background=[d(0x1c,1),*layer()],bitmaps=[[0,*d(0xc,count)]],undefinedBitmap=[[0,0xc,4]])
 for arena in (0,1,16,99,100):
  bg=[d(0x914,1),d(0x918,2),d(0x91c,3)] if arena==99 else [d(0x1c,2),*layer(0,width=1200),*layer(1,color=0x175317)]
  yield dict(label=f'whole-background-{arena}',group='whole-background',arena=arena,background=bg,active=[[0,1],[399,1]],actors=[[0,[q(0x58,700),b(0x80,0)]],[399,[q(0x58,1400)]]],globals=[d(0x450b4c,1)])
 # Unused storage remains undefined; source must not access these words.
 for count in (-1,0):
  yield dict(label=f'undefined-empty-{count}',group='provenance',stage='background',background=[d(0x1c,count)],undefinedBackground=[[0,4],[0x3ec,0x59c]])
 yield dict(label='undefined-fill-width',group='provenance',stage='background',background=[d(0x1c,1),*layer(color=0x175317)],undefinedBackground=[[0,4],[0x644,4],[0x7ac,4],[0x824,4],[0x914,4]])
 yield dict(label='undefined-skipped-loop',group='provenance',stage='background',background=[d(0x1c,1),*layer(step=500,period=3,start=2)],undefinedBackground=[[0,4],[0x464,4],[0x4dc,4],[0x554,4],[0x914,4]])
 yield dict(label='undefined-nonloop-width',group='provenance',stage='background',width=794,background=[d(0x1c,1),*layer()],undefinedBackground=[[0x464,4],[0x824,4],[0x6bc,4],[0x734,4]])
def main():
 p=argparse.ArgumentParser();p.add_argument('--limit',type=int);p.add_argument('--accept',action='store_true');args=p.parse_args()
 path=ROOT/'build/original/world-camera.json'
 if not args.accept:
  vm=WorldCamera();cases=[]
  for n,item in enumerate(probes()):
   if args.limit is not None and n>=args.limit:break
   cases.append(vm.probe(item,n))
   if (n+1)%500==0:print('WORLD CAMERA',n+1,flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,ids=IDS,states=STATES,header=HEADER,baseActor=[d(0x31c,20)],cases=cases,instructions=sorted(vm.instructions),fpcw=0x37f,bitmapSurface=TARGET,drawTarget=TARGET,fillTarget=FILL_TARGET)
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),instructions=len(vm.instructions),events=sum(len(c['events']) for c in cases),nativeCompared=False)
  (ROOT/'build/research/world-camera.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 else:
  raw=path.read_bytes();report=json.loads((ROOT/'build/research/world-camera.json').read_bytes());assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalWorldCameraTests'],env=dict(os.environ,NTSD_WORLD_CAMERA_CORPUS=str(path)),check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-world-camera.json';fixture.write_bytes(packed);report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/world-camera.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
