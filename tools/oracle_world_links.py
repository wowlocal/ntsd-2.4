#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole417f80..4187a3: depth clamping and held-object placement/use/throw.
Synthetic400-slot pool, four declarative Objects/Frames and BG boundaries.
Real function, RNG and ftol2; constructors retain their declared memset boundary.
Full pool bytes/masks, globals hashes, ordered RNG events, CW037f.
"""
import argparse,base64,itertools,json,os,struct,subprocess,zlib
from collections import Counter
from oracle_world_control import WorldControl,WORLD,POOL,OBJECT,CATALOG,BODY_SP,HEADER,REGS,d,b,q,digest
from oracle_actor_control import ActorControl,GLOBAL_BASE,GLOBAL_SIZE
from oracle_state import ACTOR_SIZE,WORLD_PREFIX,STOP
from import_ntsd import ROOT,EXE_SHA256
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW
IDS=[2,122,123,10];STATES={300:17,301:12,302:10,303:18};BG=0x4d45db0
class WorldLinks(WorldControl):
 arithmetic_control_word=0x37f # Historical default; precision revalidation supplies its own context.
 def code(self,uc,pc,size,data):
  if not self.running:return
  sp=uc.reg_read(UC_X86_REG_ESP)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop();assert sp==h['sp']+4 and h['saved']==[uc.reg_read(r) for r in REGS],h
   self.helpers+=1
   if h['entry']==0x417170:self.events.append(dict(slot=h['slot'],kind='random',arguments=h['args']+[uc.reg_read(UC_X86_REG_EAX)]))
  self.instructions.add(pc)
  if pc in (0x417170,0x4450d0):
   args=[self.u32(sp+4+4*i) for i in range(2)] if pc==0x417170 else []
   self.pending.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),slot=self.u32(BODY_SP-4-0x10-16+0x1c),args=args,saved=[uc.reg_read(r) for r in REGS]))
  assert any(a<=pc<=e for a,e in [(0x417f80,0x41879e),(0x417170,0x4171bc),(0x4450d0,0x44517a)]),hex(pc)
 def probe(self,item,index):
  item=dict(item,fill='a5' if index%2==0 else 'ramp');template=self.templates[item['fill']]
  self.pending=[];self.events=[];self.helpers=0
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
  self.uc.mem_write(BODY_SP-4,struct.pack('<I',STOP));self.uc.reg_write(UC_X86_REG_ESP,BODY_SP-4);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  for r,v in zip(REGS,[0x11223344,0x22334455,0x33445566,0x44556677]):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_FPCW,self.arithmetic_control_word);self.running=True
  try:self.uc.emu_start(0x417f80,STOP,count=2_000_000)
  except Exception:print('WORLD LINKS FAILURE',item['label'],hex(self.uc.reg_read(UC_X86_REG_EIP)),flush=True);raise
  finally:self.running=False
  assert not self.pending and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP and [self.uc.reg_read(r) for r in REGS]==[0x11223344,0x22334455,0x33445566,0x44556677]
  assert self.uc.reg_read(UC_X86_REG_FPCW)==self.arithmetic_control_word and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  assert bytes(self.uc.mem_read(WORLD,WORLD_PREFIX))==bytes(world) and bytes(self.uc.mem_read(CATALOG+BG,len(bg)))==bytes(bg)
  for i,raw in enumerate(objects):assert bytes(self.uc.mem_read(OBJECT+i*0x40000,len(raw)))==raw
  for i in range(400):struct.pack_into('<I',world,0x194+i*4,bindings.get(i,i))
  struct.pack_into('<I',world,0x7d4,0);pool=world;mask=self.world_mask.copy()
  for i in range(400):
   address=POOL+i*0x500;raw=bytearray(self.uc.mem_read(address,ACTOR_SIZE));ptr=int.from_bytes(raw[0x368:0x36c],'little');assert (ptr-OBJECT)%0x40000==0 and 0<=(ptr-OBJECT)//0x40000<4
   struct.pack_into('<I',raw,0x368,(ptr-OBJECT)//0x40000);pool+=raw;mask+=self.masks[i]
   assert self.uc.mem_read(address-16,16)==b'\x96'*16 and self.uc.mem_read(address+ACTOR_SIZE,16)==b'\x69'*16
  item.update(poolSHA256=digest(pool),maskSHA256=digest(mask),globalsSHA256=digest(bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE))),events=self.events,helpers=self.helpers);return item
def linked(label,group='placement',slot=1,owner=0,actor=(),holder=(),frames=(),headers=(),**kwargs):
 return dict(label=label,group=group,active=[[slot,1],[owner,1]],actors=[[slot,[d(0x368,3),d(0x98,-1),d(0xa0,owner),*actor]],[owner,[d(0x9c,slot),*holder]]],frames=frames,headers=headers,**kwargs)
def f(obj,n,offset,value):return [obj,n,*d(offset,value)]
def h(obj,offset,value):return [obj,*d(offset,value)]
def probes():
 for kind,bounds,z,sse in itertools.product((-2,0,1,2,3,4,6),([0,600],[600,0],[-2147483648,2147483647],[17,17]),(-1e20,-2147483648.9,-1,-0.,0.1,17,599.9,600,600.1,2147483648.,1e20),(0,1)):
  yield dict(label=f'depth-{kind}-{bounds}-{z}-{sse}',group='depth',active=[[0,255]],actors=[[0,[q(0x68,z),d(0x18,123)]]],headers=[h(0,0x6f8,kind)],bounds=bounds,sse2=sse)
 for carried,owner,activity,backlink in itertools.product((-2,-1,0,1),(-2147483648,-1,0,1,399,400,2147483647),(0,1,255),(-1,0,1)):
  actors=[[1,[d(0x98,carried),d(0xa0,owner),d(0x9c,backlink)]]]
  if owner in (0,399):actors.append([owner,[d(0x9c,backlink)]])
  active={1:1}
  if 0<=owner<400:active[owner]=activity
  yield dict(label=f'gate-{carried}-{owner}-{activity}-{backlink}',group='link-gates',active=list(active.items()),actors=actors)
 for kind,state,facing,cover,coordinates in itertools.product((0,1,2,3,4,6),(0,300,301,302),(0,1,2,255),(0,1,-1),((100,-20,300),(2147483647,-2147483648,2147483647))):
  yield linked(f'position-{kind}-{state}-{facing}-{cover}-{coordinates}',holder=[d(0x70,state),b(0x80,facing),d(0xb4,7),*[d(o,v) for o,v in zip((0x10,0x14,0x18),coordinates)]],
   headers=[h(3,0x6f8,kind)],frames=[f(0,state,0x50,-13),f(0,state,0x54,27),f(0,state,0xdc,31),f(0,state,0xe0,-19),f(0,state,0xe4,21),f(0,state,0xec,cover),f(3,21,0x50,11),f(3,21,0x54,-7),f(3,21,0xdc,-29),f(3,21,0xe0,23)])
 for kind,state,dvx,held,wpKind,hit in itertools.product((1,2,3,4,6),(0,301,302),(-2147483648,-1,0,1,2147483647),(0,1,2,3),(1,3),(0,1)):
  yield linked(f'throw-{kind}-{state}-{dvx}-{held}-{wpKind}-{hit}',group='throw',holder=[d(0x70,state),b(0xcd,held&1),b(0xce,(held>>1)&1),d(0x20,hit),q(0x28,2.8),q(0x30,-3.7),q(0x40,-2.8),q(0x48,4.9)],
   headers=[h(3,0x6f8,kind)],frames=[f(0,state,0xd8,wpKind),f(0,state,0xf0,dvx),f(0,state,0xf4,-2147483648),f(0,state,0xf8,2147483647)],globals=[d(0x450bcc,2999),d(0x450c34,1233)])
 for obj,hp,state,resources,owner in itertools.product((1,2),(-1,0,1,2,5,6,7,30,2147483647),(0,300,301),((100,200,500,499),(2147483647,2147483647,500,2147483647),(-20,-10,-1,-5)),(-1,0)):
  yield linked(f'use-{obj}-{hp}-{state}-{resources}-{owner}',group='consumption',actor=[d(0x368,obj),d(0x2fc,hp),d(0x2f4,owner),d(0x308,151)],holder=[d(0x70,state),*[d(o,v) for o,v in zip((0x2fc,0x300,0x304,0x308),resources)]])
 for main,owner,alias,kind in itertools.product((0,1,199,399),(0,1,199,399),(False,True),(1,3)):
  if main==owner:continue
  case=linked(f'order-{main}-{owner}-{alias}-{kind}',group='alias-order',slot=main,owner=owner,holder=[d(0x70,300)],frames=[f(0,300,0xd8,kind),f(0,300,0xe4,21)],aliases=[[main,owner]] if alias else [])
  if alias:case['actors'][1][1]+=[d(0x98,-1),d(0xa0,owner)]
  yield case
 yield dict(label='all400-depth',group='all-slots',active=[[i,1] for i in range(400)],actors=[[i,[q(0x68,700+i*.1)]] for i in range(400)])
 yield dict(label='empty',group='empty')
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accept',action='store_true');a=p.parse_args();path=ROOT/'build/original/world-links.json';report_path=ROOT/'build/research/world-links.json'
 if not a.accept:
  vm=WorldLinks();cases=[]
  for n,item in enumerate(probes()):
   cases.append(vm.probe(item,n))
   if (n+1)%1000==0:print('WORLD LINKS',n+1,flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,ids=IDS,states=STATES,header=HEADER,baseActor=[d(0x31c,20)],cases=cases,instructions=sorted(vm.instructions),fpcw=0x37f)
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),instructions=len(vm.instructions),events=sum(len(c['events']) for c in cases),nativeCompared=False)
  report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 else:
  raw=path.read_bytes();report=json.loads(report_path.read_bytes());assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalWorldLinksTests'],env=dict(os.environ,NTSD_WORLD_LINKS_CORPUS=str(path)),check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-world-links.json';fixture.write_bytes(packed);report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/world-links.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
