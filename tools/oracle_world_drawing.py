#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Entire41a5a0/40de30/40be70/40bf30/43f310 with real43f010/43ef70.
Declared400-slot pool, constructed Actor/World bytes and synthetic Object,
Frame/BG/bitmap/font metadata. Full pool/masks, unchanged globals/BG/resources,
ordered metadata reads and COM Blts. No pixels, own launch or Windows claim.
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
BITMAP,TARGET,FILL_TARGET,VTABLE,API=0x73000020,0x73024000,0x73024010,0x73024100,STOP+0x100
BITMAP_SIZE=0x1f50
STATES={300:9997,301:3005}
RESOURCES={0x44faf4:5,0x44f888:6,0x44fcbc:7,0x44fb68:8,0x44faf8:9,0x44fd80:10,0x44f8fc:11,0x44fd7c:12}
BASE_ACTOR=[d(0x31c,20),d(0x10,400),d(0x18,300),d(0x1c,0),d(0x318,0),d(0x36c,0)]
DRAW_HEADER=[d(0x498,2),d(0x62c,0),d(0x630,4),d(0x6a4,2),d(0x6a8,2),d(0x6cc,2),d(0x6d0,2),d(0x754,1),d(0x758,2),d(0x77c,3),d(0x780,4)]
HELPERS={0x40de30:12,0x40be70:28,0x40bf30:4,0x43f010:24,0x43ef70:0,0x43f310:28,0x4450b2:0}
def signed(v):return (v+0x80000000)%0x100000000-0x80000000
class WorldDrawing(WorldControl):
 def __init__(self):
  super().__init__();self.uc.mem_map(BITMAP&~0xfff,0x30000)
  for p,v in [(TARGET,VTABLE),(FILL_TARGET,VTABLE),(VTABLE+0x14,API)]:self.put(p,v)
 def put(self,p,v):self.uc.mem_write(p,struct.pack('<I',v&0xffffffff))
 def ret(self,v,pop=0):
  sp=self.uc.reg_read(UC_X86_REG_ESP);self.uc.reg_write(UC_X86_REG_EAX,v&0xffffffff);self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp));self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop)
 def token(self,n):return n+1 if n<5 else BITMAP+n*0x2000
 def event(self,kind,args=(),**kw):self.events.append(dict(kind=kind,arguments=list(args),strings=[],**kw))
 def access(self,uc,access,p,size,value,data):
  if not self.running:return
  if CATALOG+BG<=p<CATALOG+BG+101*0x990:
   offset=p-CATALOG-BG;assert access==UC_MEM_READ and offset+size<=len(self.bg_masks) and all(self.bg_masks[offset:offset+size])
  elif BITMAP<=p<BITMAP+13*0x2000:
   assert access==UC_MEM_READ
   n,offset=divmod(p-BITMAP,0x2000);assert offset+size<=BITMAP_SIZE and size==4
   pc=uc.reg_read(UC_X86_REG_EIP)
   if pc==0x40bf9d:self.event('width',[self.token(n),offset])
   else:assert n==self.bitmap,(hex(pc),n,self.bitmap)
   self.event('read',read=dict(offset=offset,value=self.u32(p),defined=all(self.bitmap_masks[n][offset:offset+4])))
  else:super().access(uc,access,p,size,value,data)
 def setup_bitmaps(self,item):
  self.bitmap_bytes=[];self.bitmap_masks=[]
  for n in range(13):
   raw=bytearray(BITMAP_SIZE);mask=bytearray(b'\1'*BITMAP_SIZE)
   struct.pack_into('<4I',raw,0,TARGET+0x100+n*16,120+10*n,90+10*n,0xffffffff if n==4 else 500)
   for k in range(500):
    for offset,value in [(0x10,k*7),(0x7e0,k*11),(0xfb0,30+n+k%5),(0x1780,40+n+k%7)]:struct.pack_into('<i',raw,offset+4*k,value)
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
   if c['entry'] in (0x43f010,0x43f310):self.bitmap=None
  if self.clip and pc==self.clip['returnPC']:
   c=self.clip;self.clip=None;assert uc.reg_read(UC_X86_REG_EAX) in (0,1)
   self.event('clip',clip=dict(beforeSource=c['source'],beforeDestination=c['destination'],
    source=[signed(self.u32(p)) for p in c['src']],destination=[signed(self.u32(p)) for p in c['dst']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
  self.instructions.add(pc)
  if pc==0x41a670:self.draw_order.append(self.u32(sp+0x2c+uc.reg_read(UC_X86_REG_EAX)*4))
  if pc in HELPERS:self.pending.append(dict(entry=pc,sp=sp,pop=HELPERS[pc],returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in REGS]))
  if pc in (0x43f010,0x43f310):
   pointer=uc.reg_read(UC_X86_REG_ECX);assert BITMAP<=pointer<BITMAP+13*0x2000 and (pointer-BITMAP)%0x2000==0
   self.bitmap=(pointer-BITMAP)//0x2000
   self.event('draw' if pc==0x43f010 else 'rectangle',[self.token(self.bitmap),*[arg(n) for n in range(6 if pc==0x43f010 else 7)]])
  elif pc==0x43ef70:
   assert self.clip is None
   src=[arg(i) for i in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
   self.clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
  elif pc==API:
   assert arg(0) in (TARGET,FILL_TARGET) and arg(2) in [0,*[TARGET+0x100+n*16 for n in range(13)]] and arg(5)==0
   self.event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=None))
   self.ret(0x80004005 if len(self.events)%2 else 0,24);return
  assert any(a<=pc<=e for a,e in [(0x41a5a0,0x41ae50),(0x40de30,0x40e160),(0x40be70,0x40bfa8),(0x43ef70,0x43f37a),(0x4450b2,0x4450ba)]),hex(pc)
 def probe(self,item,index):
  item=dict(item,fill='a5' if index%2==0 else 'ramp');template=self.templates[item['fill']]
  self.draw_order=[];self.pending=[];self.events=[];self.helpers=0;self.clip=None;self.bitmap=None;self.fill_inputs=[];self.stage='drawing'
  world=bytearray.fromhex(template['world']['bytes']);self.world_mask=bytearray(template['world']['defined'])
  def write(raw,mask,offset,h):
   v=bytes.fromhex(h);raw[offset:offset+len(v)]=v;mask[offset:offset+len(v)]=b'\1'*len(v)
  bindings=dict(item.get('aliases',[]));self.masks=[];actors=dict(item.get('actors',[]));active=dict(item.get('active',[]))
  for i in range(400):
   write(world,self.world_mask,*b(4+i,active.get(i,0)));write(world,self.world_mask,*d(0x194+4*i,POOL+bindings.get(i,i)*0x500))
   raw=bytearray.fromhex(template['actor']['bytes']);mask=bytearray(template['actor']['defined'])
   for offset,h in [d(0x368,0),*BASE_ACTOR,*actors.get(i,[])]:write(raw,mask,offset,h)
   ordinal=int.from_bytes(raw[0x368:0x36c],'little');struct.pack_into('<I',raw,0x368,OBJECT+ordinal*0x40000)
   self.uc.mem_write(POOL+i*0x500-16,b'\x96'*16+bytes(raw)+b'\x69'*16);self.masks.append(mask)
  write(world,self.world_mask,*d(0x7d4,CATALOG));self.uc.mem_write(WORLD,bytes(world));objects=[]
  for i,id in enumerate(IDS):
   raw=bytearray(ActorControl.object_bytes(self,{}));struct.pack_into('<ii',raw,0x6f4,id,0 if i==0 else 1)
   for n in range(400):struct.pack_into('<i',raw,0x7ac+n*0x178,STATES.get(n,3))
   for offset,h in DRAW_HEADER:raw[offset:offset+len(bytes.fromhex(h))]=bytes.fromhex(h)
   for obj,offset,h in item.get('headers',[]):
    if obj==i:raw[offset:offset+len(bytes.fromhex(h))]=bytes.fromhex(h)
   for obj,n,offset,h in item.get('frames',[]):
    if obj==i:raw[0x7a4+n*0x178+offset:0x7a4+n*0x178+offset+len(bytes.fromhex(h))]=bytes.fromhex(h)
   for offset in [0x754+4*n for n in range(10)]+[0x77c+4*n for n in range(10)]:
    token=int.from_bytes(raw[offset:offset+4],'little')
    if token:struct.pack_into('<I',raw,offset,BITMAP+(token-1)*0x2000)
   objects.append(bytes(raw));self.uc.mem_write(OBJECT+i*0x40000,bytes(raw));self.uc.mem_write(CATALOG+4*i,struct.pack('<I',OBJECT+i*0x40000))
  self.uc.mem_write(CATALOG+0x4d82380,struct.pack('<i',4))
  bg=bytearray(101*0x990)
  for i in range(101):
   struct.pack_into('<iii',bg,i*0x990,item.get('width',1600),*item.get('bounds',[0,600]))
  arena=item.get('arena',0)
  for offset,h in [d(0x14,40),d(0x18,20),d(0x98c,5),*item.get('background',[])]:
   raw=bytes.fromhex(h);bg[arena*0x990+offset:arena*0x990+offset+len(raw)]=raw
  for offset in [0x98c]:
   token=int.from_bytes(bg[arena*0x990+offset:arena*0x990+offset+4],'little')
   if token:struct.pack_into('<I',bg,arena*0x990+offset,BITMAP+(token-1)*0x2000)
  self.bg_masks=bytearray(b'\1'*len(bg))
  for offset,count in item.get('undefinedBackground',[]):self.bg_masks[arena*0x990+offset:arena*0x990+offset+count]=bytes(count)
  self.uc.mem_write(CATALOG+BG,bytes(bg))
  glob=bytearray(GLOBAL_SIZE);glob[0x44ff90-GLOBAL_BASE:0x44ff90-GLOBAL_BASE+3000]=bytes(1+i%255 for i in range(3000));struct.pack_into('<i',glob,0x44d034-GLOBAL_BASE,1)
  for slot in range(10):glob[0x44fcc0-GLOBAL_BASE+11*slot:0x44fcc0-GLOBAL_BASE+11*slot+3]=f'P{slot}\0'.encode()
  for address,h in [*[d(g,BITMAP+n*0x2000) for g,n in RESOURCES.items()],d(0x44d024,arena),d(0x44d78c,794),d(0x44d790,550),d(0x455608,FILL_TARGET),*item.get('globals',[])]:glob[address-GLOBAL_BASE:address-GLOBAL_BASE+len(bytes.fromhex(h))]=bytes.fromhex(h)
  self.uc.mem_write(GLOBAL_BASE,bytes(glob));self.uc.mem_write(0x45971c,struct.pack('<I',item.get('sse2',0)))
  self.setup_bitmaps(item)
  self.uc.mem_write(BODY_SP-0x4000,bytes([0xa5 if item['fill']=='a5' else 0x69])*0x4000)
  self.uc.mem_write(BODY_SP,struct.pack('<IIII',STOP,item.get('target',TARGET),item.get('phase',0)&0xffffffff,item.get('mode',0)&0xffffffff))
  self.uc.reg_write(UC_X86_REG_ESP,BODY_SP);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGS,saved):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_FPCW,0x37f);self.running=True
  try:self.uc.emu_start(0x41a5a0,STOP,count=8_000_000)
  except Exception:print('WORLD DRAWING FAILURE',item['label'],hex(self.uc.reg_read(UC_X86_REG_EIP)),flush=True);raise
  finally:self.running=False
  assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and not self.pending and self.clip is None
  assert self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP+16 and [self.uc.reg_read(r) for r in REGS]==saved
  assert self.uc.reg_read(UC_X86_REG_FPCW)==0x37f and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  assert bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE))==glob
  now=bytes(self.uc.mem_read(WORLD,WORLD_PREFIX));assert now==world
  after_bg=bytearray(self.uc.mem_read(CATALOG+BG,len(bg)));assert after_bg==bg
  for offset in [0x98c]:
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
  item.update(poolSHA256=digest(pool),maskSHA256=digest(mask),globalsSHA256=digest(bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE))),events=self.events,helpers=self.helpers,backgroundsSHA256=digest(after_bg),backgroundMasksSHA256=digest(self.bg_masks),drawOrder=self.draw_order);return item
def actor_case(label,patches=(),slot=0,**kw):return dict(label=label,active=[[slot,1]],actors=[[slot,list(patches)]],**kw)
def probes():
 yield dict(label='empty',group='empty')
 for flag,held,state,id in itertools.product((-2147483648,-71,-70,-69,-26,-25,-24,-3,-2,-1,0,1,2,3,4,2147483647),(-1,0,1),(3,3005,9997),(222,223,224,225)):
  yield actor_case(f'shadow-{flag}-{held}-{state}-{id}',[d(8,flag),d(0x98,held)],group='shadow',frames=[f(0,0,8,state)],headers=[h(0,0x6f4,id)])
 for state,face,shift,phase,x in itertools.product((3,9997),(0,1,2,128,255),(-1,0,1),(-2147483648,-1,0,1,2147483647),(-2147483648,-100,0,700,714,800,2147483647)):
  if face not in (0,1) and (phase,x)!=(0,0):continue
  if shift>=0 and phase!=0:continue
  yield actor_case(f'sprite-{state}-{face}-{shift}-{phase}-{x}',[b(0x80,face),d(0xb4,shift),d(0x10,x),d(0x14,-20),d(0x1c,13)],group='sprite',phase=phase,frames=[f(0,0,8,state),f(0,0,0x50,17),f(0,0,0x54,23)],globals=[d(0x450bc4,47)])
 for hp,maxhp,point,state,face in itertools.product((-2147483648,-1,0,1,166,167,2147483647),(-2147483648,-3,0,3,500,2147483647),(-1,0,1,11),(3,9997),(0,1,2)):
  if (hp,maxhp)!=(0,3) and (point,state,face)!=(1,3,1):continue
  yield actor_case(f'point-{hp}-{maxhp}-{point}-{state}-{face}',[d(0x2fc,hp),d(0x304,maxhp),b(0x80,face),d(0xb4,-1),d(0x14,-9)],group='point',phase=1,frames=[f(0,0,8,state),f(0,0,0x80,point),f(0,0,0x84,19),f(0,0,0x50,10),f(0,0,0x54,20)])
 for face,present,count,pic,offset in itertools.product((0,1),(0,1),(-1,0,1,2,10),(-2147483648,-1,0,3,4,7,8,2147483647),(-2147483648,-4,0,4,2147483647)):
  if present==0 and (count,pic,offset)!=(2,0,0):continue
  yield actor_case(f'sheet-{face}-{present}-{count}-{pic}-{offset}',[b(0x80,face),d(0x318,offset)],group='sheet',frames=[[0,0,*b(0,present)],f(0,0,4,pic)],headers=[h(0,0x498,count)])
 for first,cols,rows,pic in itertools.product((-4,0,1,2147483647),(-2147483648,-1,0,2,2147483647),(-1,0,2,2147483647),(-1,0,1,3)):
  # Keep returned relative pictures in known bitmap metadata; wrapped range
  # arithmetic is still evaluated when it produces no sheet.
  end=signed(first+signed(cols*rows))
  if first<=pic<end and not 0<=signed(pic-first)<500:continue
  yield actor_case(f'range-{first}-{cols}-{rows}-{pic}',[b(0x80,1)],group='range',frames=[f(0,0,4,pic)],headers=[h(0,0x498,1),h(0,0x62c,first),h(0,0x6a4,cols),h(0,0x6cc,rows)])
 for slot,typ,team,id,flag in itertools.product((0,9,10,19,20,399),(-1,0,1),(-1,0,1,2,3,4,5,6),(29,30,37,38,39,49,50),(-25,-24,2)):
  if (id,flag)!=(38,2) and (typ,team)!=(0,5):continue
  yield actor_case(f'label-{slot}-{typ}-{team}-{id}-{flag}',[d(0x364,team),d(8,flag)],slot=slot,group='label',headers=[h(0,0x6f8,typ),h(0,0x6f4,id)])
 for name,status,x in itertools.product((b'',b'A',b'12345678901',b'12345678901234567',b'\xfd\xfe\xff',b'A'*89),(-2,-1,0,1),(-2147483648,-1,0,794,1000,2147483647)):
  if status==-1 and len(name)>17:continue
  yield actor_case(f'name-{name.hex()}-{status}-{x}',[d(0x10,x)],group='name',globals=[(0x44fcc0,(name+b'\0').hex()),d(0x450b4c,status)])
 for lives,blink,x in itertools.product((-2147483648,-1,0,1,2,9,10,99,100,101,2147483647),(-70,-25,-24,0,2),(-100,400,2147483647)):
  yield actor_case(f'lives-{lives}-{blink}-{x}',[d(0x30c,lives),d(8,blink),d(0x10,x),d(0x14,-15)],group='lives',frames=[f(0,0,0x54,20)])
 for value,count,aliases in itertools.product((-2147483648,-4,-3,-2,-1,*range(41),2147483647),(-1,0,1,2,10),(False,True)):
  patches=[d(0x36c,count),d(0x1c,17),d(8,-70)]
  for i in range(max(0,count)):patches += [d(0x3c0+4*i,value if i==count-1 else 5),d(0x370+4*i,400+i),d(0x398+4*i,300+i)]
  item=actor_case(f'sparks-{value}-{count}-{aliases}',patches,group='sparks',globals=[d(0x450bc4,27)])
  if aliases:item.update(active=[[0,1],[1,255]],aliases=[[1,0]])
  yield item
 for count in (11,24):
  yield actor_case(f'spark-overlap-{count}',[d(0x36c,count),*[d(0x370+4*i,10) for i in range(44)]],group='sparks')
 for count,order,alias in itertools.product((2,10,400),('ascending','descending','ties','signed'),(False,True)):
  active=[[i,1+i%255] for i in range(count)]
  patches=[[i,[d(0x18,i if order=='ascending' else 400-i if order=='descending' else 300 if order=='ties' else (-2147483648 if i%2 else 2147483647)),d(0x10,i*2),d(0x368,i%4)]] for i in range(count)]
  yield dict(label=f'order-{count}-{order}-{alias}',group='order',active=active,actors=patches,aliases=[[i,0] for i in range(count)] if alias else [])
 for value in (0,-1,2147483647):
  yield actor_case(f'bitmap-backing-{value}',[b(0x80,1)],group='provenance',bitmaps=[[0,*d(0xc,value)],[4,*d(0xc,value)]],undefinedBitmap=[[0,0xc,4],[4,0xc,4],[0,0xfb0,4]])
 for x,y in itertools.product((-2147483648,-3,-1,0,1,3,2147483647),(-3,0,3)):
  yield actor_case(f'shadow-size-{x}-{y}',group='shadow-size',background=[d(0x14,x),d(0x18,y)])
 for x in (-1,1000):yield actor_case(f'alternate-label-clamp-{x}',[d(0x10,x),d(0x364,5)],slot=20,group='label')
 for x in (-2147483648,2147483647):yield actor_case(f'point-wrap-{x}',[d(0x10,x),d(0x14,x),d(0x2fc,-1)],group='point',frames=[f(0,0,0x80,1),f(0,0,0x84,2147483647)])
 for mode in (-2147483648,-1,0,1,2,2147483647):yield actor_case(f'unused-mode-{mode}',group='caller',mode=mode)

 for face in (0,1):
  yield actor_case(f'tenth-sheet-{face}',[b(0x80,face)],group='sheet',frames=[f(0,0,4,40)],headers=[h(0,0x498,10),h(0,0x650,40),h(0,0x6c8,1),h(0,0x6f0,1),h(0,0x778,1),h(0,0x7a0,3)])
 yield actor_case('overlapping-sheet-first',[b(0x80,1)],group='sheet',frames=[f(0,0,4,2)],headers=[h(0,0x630,0)])
 yield actor_case('present-byte-255',group='sheet',frames=[[0,0,*b(0,255)]])

def main():
 p=argparse.ArgumentParser();p.add_argument('--limit',type=int);p.add_argument('--accept',action='store_true');args=p.parse_args()
 path=ROOT/'build/original/world-drawing.json';report_path=ROOT/'build/research/world-drawing.json'
 if not args.accept:
  vm=WorldDrawing();cases=[]
  for n,item in enumerate(probes()):
   if args.limit is not None and n>=args.limit:break
   cases.append(vm.probe(item,n))
   if (n+1)%250==0:print('WORLD DRAWING',n+1,flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,ids=IDS,states=STATES,header=HEADER,drawHeader=DRAW_HEADER,baseActor=BASE_ACTOR,cases=cases,instructions=sorted(vm.instructions),fpcw=0x37f,bitmapBase=BITMAP,drawTarget=TARGET,fillTarget=FILL_TARGET,resources=RESOURCES)
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),instructions=len(vm.instructions),events=sum(len(c['events']) for c in cases),nativeCompared=False)
  report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 else:
  raw=path.read_bytes();report=json.loads(report_path.read_bytes());assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and args.limit is None
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalWorldDrawingTests'],env=dict(os.environ,NTSD_WORLD_DRAWING_CORPUS=str(path)),check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-world-drawing.json';fixture.write_bytes(packed);report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/world-drawing.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
