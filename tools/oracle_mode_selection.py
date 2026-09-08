#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""431b70 and mode-screen keyboard4322ad..4328f8, with real sound/release/shutdown.
Explicit caller-state probes, not a resumed startup or whole431d10 screen.
Eight raw Actor pointers may alias; no Object/character behavior is supplied.
COM/free/PostMessage/PostQuit are observed responses. Playback stops BEFORE
43249c; rendering, panel, file IO and Windows remain outside this corpus.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_state import Constructors,AREA,STACK,STOP,WORLD_PREFIX,ACTOR_SIZE
from oracle_bitmap_drawing import digest,packed
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBP,UC_X86_REG_EBX,UC_X86_REG_ECX,UC_X86_REG_EDI,UC_X86_REG_EDX,UC_X86_REG_ESI,UC_X86_REG_ESP,UC_X86_REG_EIP

GLOBAL,GSIZE,WORLD,POOL,HEAP,API=0x44D000,0xB440,AREA+0x20,0x25000000,0x26000000,STOP+0x1000
BODY=STACK+0xD000
REGISTERS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]
HELPERS={0x431B70:0,0x401A30:4,0x423910:0,0x43EF50:0,0x4019B0:0,0x401D30:0,0x43D2A0:0,0x43D280:0}

class ModeSelection(Constructors):
 def __init__(self,control=False):
  self.running=False;self.control=control;super().__init__()
  for p,n in [(POOL,0x10000),(HEAP,0x10000),(API,0x1000)]:self.uc.mem_map(p,n)
  self.blobs={};self.regions={};self.live={}
  def backing(n):return bytes((i*37+11)&255 for i in range(n)) if control else b'\xa5'*n
  def add(p,raw):
   self.uc.mem_write(p,raw);self.regions[p]=dict(address=p,size=len(raw),mask=bytearray(len(raw)))
  add(GLOBAL,bytes(self.uc.mem_read(GLOBAL,GSIZE)));add(WORLD,backing(WORLD_PREFIX))
  self.actors=[POOL+(12-i if control else i)*0x500+0x20 for i in range(9)]
  for p in self.actors:add(p,backing(ACTOR_SIZE))
  self.bitmap=HEAP+0x20;self.replays=[HEAP+0x3000,HEAP+0x3100]
  for p,n in [(self.bitmap,0x1F50),*zip(self.replays,(13,19))]:add(p,backing(n));self.live[p]=True
  add(0x4588A8,bytes(8))
  self.tokens=[HEAP+0x4000+i*16 for i in range(10)];vtable=HEAP+0x5000
  for token in self.tokens:self.put(token,vtable)
  for i,offset in enumerate((8,0x48,0x34,0x30)):self.put(vtable+offset,API+i*16)
  for at,to in [(0x44717C,API+0x100),(0x4471EC,API+0x110),(0x4471F0,API+0x120)]:self.put(at,to)
  for p,n in [(GLOBAL,GSIZE),(POOL,0x10000),(HEAP,0x4000),(0x4588A8,8)]:
   self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=p,end=p+n-1)
  self.uc.hook_add(UC_HOOK_CODE,self.code)
  for seat,p in enumerate(self.actors[:8]):self.write(WORLD+0x194+4*seat,struct.pack('<I',p))
  self.initial=self.snapshot()
 def put(self,p,v):self.uc.mem_write(p,struct.pack('<I',v&0xFFFFFFFF))
 def blob(self,raw):
  raw=bytes(raw);h=digest(raw)
  if h not in self.blobs:self.blobs[h]=packed(raw)
  return h
 def region(self,p,n):
  for r in self.regions.values():
   if r['address']<=p and p+n<=r['address']+r['size']:return r
  raise AssertionError(('unowned write',hex(p),n))
 def write(self,p,raw):
  r=self.region(p,len(raw));o=p-r['address'];r['mask'][o:o+len(raw)]=b'\1'*len(raw);self.uc.mem_write(p,raw)
 def written(self,uc,access,p,n,value,data):
  if not self.running:return
  r=self.region(p,n);o=p-r['address'];r['mask'][o:o+n]=b'\1'*n
  self.writes.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),address=p,bytes=(value&((1<<(8*n))-1)).to_bytes(n,'little').hex()))
 def storage(self,p):
  r=self.regions[p];return dict(bytes=self.blob(self.uc.mem_read(p,r['size'])),defined=self.blob(r['mask']))
 def snapshot(self):return [dict(address=p,storage=self.storage(p),live=self.live.get(p)) for p in self.regions]
 def ret(self,value=0,pop=0):
  sp=self.uc.reg_read(UC_X86_REG_ESP);self.uc.reg_write(UC_X86_REG_EAX,value&0xFFFFFFFF);self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop);self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp))
 def event(self,kind,args):self.events.append(dict(kind=kind,arguments=args))
 def code(self,uc,pc,size,data):
  if not self.running:return
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  while self.pending and pc==self.pending[-1]['returnPC']:
   c=self.pending.pop();assert sp==c['entrySP']+4+c['pop'] and c['saved']==[uc.reg_read(r) for r in REGISTERS]
   c.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.helpers.append(c)
  if pc in (STOP,0x43249C,0x4328F8):
   assert not self.pending;self.end={STOP:'returned',0x43249C:'playback',0x4328F8:'panel'}[pc];uc.emu_stop();return
  if pc in HELPERS:
   self.pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=HELPERS[pc],saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc==0x401A30:assert uc.reg_read(UC_X86_REG_ECX)==0x455610 and arg(0)==0;self.event('soundRequest',[0])
  if API<=pc<=API+0x30:
   offset,pop={API:(8,4),API+16:(0x48,4),API+32:(0x34,8),API+48:(0x30,16)}[pc]
   kind='soundMethod' if any(c['entry']==0x401A30 for c in self.pending) else 'method'
   self.event(kind,[arg(0),offset,*[arg(i) for i in range(1,pop//4)]]);self.ret(self.method_result,pop);return
  if pc==API+0x100:
   assert self.live[arg(0)];self.live[arg(0)]=False;self.event('free',[arg(0)]);self.ret();return
  if pc==API+0x110:self.event('postMessage',[arg(i) for i in range(4)]);self.ret(self.method_result,16);return
  if pc==API+0x120:self.event('postQuit',[arg(0)]);self.ret(0,4);return
  assert any(a<=pc<=b for a,b in [(0x431B70,0x431C64),(0x4322AD,0x43249C),(0x4328DB,0x4328F8),
   (0x401A30,0x401A6F),(0x423910,0x423938),(0x43EF50,0x43EF68),(0x4019B0,0x401A26),(0x401D30,0x401D90),(0x43D280,0x43D2B7)]),hex(pc)
 def step(self,label,kind='selection',writes=(),revive=(),method_result=0):
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  for p in revive:self.live[p]=True
  self.method_result=method_result;self.events=[];self.helpers=[];self.pending=[];self.writes=[];self.end=None
  sp=BODY if kind=='selection' else BODY-4
  self.put(BODY-4,STOP)
  for offset,value in [(0x10,0x451160),(0x14,0x44D020),(0x18,self.tokens[0]),(0x1C,WORLD),(0x20,0x4512C8)]:self.put(BODY+offset,value)
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGISTERS,saved):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_ESP,sp);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  self.running=True
  try:self.uc.emu_start(0x431B70 if kind=='input' else 0x4322AD,0,count=100000)
  finally:self.running=False
  assert self.end is not None and self.uc.reg_read(UC_X86_REG_ESP)==BODY
  if kind=='input':assert saved==[self.uc.reg_read(r) for r in REGISTERS] and self.uc.reg_read(UC_X86_REG_EAX)==0x451340
  return dict(label=label,kind=kind,stimulus=stimulus,revive=list(revive),methodResult=method_result,events=self.events,helpers=self.helpers,writes=self.writes,
   continuation=self.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=BODY,after=self.snapshot())
 def defaults(self):
  return [(0x451160,0),(0x44D020,10),(0x44D024,-7),(0x44D028,-8),(0x4512C8,-9),(0x4513C0,450),(0x450C2C,0),(0x44D780,23),
   (0x44F1AF,b'\0'),(0x4511AC,self.bitmap),(self.bitmap,self.tokens[0]),(0x44EECC,self.tokens[1]),(0x455610,self.tokens[2]),
   (0x458438,2),(0x452948,struct.pack('<II',*self.tokens[3:5])),(0x45843C,1),(0x451DB0,self.tokens[5]),
   (0x44F040,self.tokens[6]),(0x44F044,self.tokens[7]),(0x44F048,self.tokens[8]),(0x44F04C,self.tokens[9]),
   (0x4588A8,struct.pack('<II',*self.replays)),(0x4546F4,0x12345678),(0x458434,0),
   (0x451320,bytes(32)),(0x4513A4,b'\xFE'*28),*[(p+0xCD,bytes(7)) for p in self.actors],
   (WORLD+0x194,struct.pack('<8I',*self.actors[:8]))]
 def capture_all(self):
  cases=[];alive=[self.bitmap,*self.replays]
  for mask in range(128):
   seat=mask%8
   for latch in (0,1,-1,-2147483648):
    buttons=bytes([0x80 if mask&(1<<i) else 0 for i in range(7)])
    cases.append(self.step(f'priority-{mask}-{seat}-{latch}','input',self.defaults()+[(self.actors[seat]+0xCD,buttons),(0x451320+seat*4,latch)],alive))
  for seat in range(8):
   for button in range(7):
    cases.append(self.step(f'each-seat-{seat}-{button}','input',self.defaults()+[(self.actors[seat]+0xCD+button,b'\xFF')],alive))
  for i in range(16):
   writes=self.defaults() if i==0 else []
   if i in (0,2,4,6,8,10,12,14):writes += [(self.actors[0]+0xCD,bytes(7)),(self.actors[0]+0xCD+(i//2)%7,b'\x02')]
   if i in (7,13):writes += [(self.actors[0]+0xCD,bytes(7))]
   cases.append(self.step(f'held-chain-{i}','input',writes,alive if i==0 else []))
  for alias in (0,8):
   for mask in range(16):
    cases.append(self.step(f'alias-{alias}-{mask}','input',self.defaults()+[(WORLD+0x194,struct.pack('<8I',*[self.actors[alias]]*8)),
     (0x451320,struct.pack('<8i',*[1 if mask&(1<<(i%4)) else 0 for i in range(8)])),(self.actors[alias]+0xCD+4,b'\x01')],alive))
  modes=(-2147483648,-9,-8,-2,-1,0,1,2,3,4,5,6,7,8,15,2147483647)
  for mode in modes:
   for network in (0,1,127,128,255):
    for mask in range(8):
     writes=self.defaults()+[(0x451160,mode),(0x44F1AF,bytes([network]))]
     for seat,button in enumerate((0,1,4)):
      if mask&(1<<seat):writes.append((self.actors[seat]+0xCD+button,b'\x01'))
     cases.append(self.step(f'mode-{mode}-{network}-{mask}',writes=writes,revive=alive,method_result=-1))
  for mode in range(8):
   for sound in range(3):
    for bitmap in range(3):
     writes=self.defaults()+[(0x451160,mode),(self.actors[0]+0xD1,b'\x01')]
     if sound<2:writes += [(0x44EECC,0 if sound==0 else self.tokens[1]),(0x455610,0)]
     if bitmap<2:writes += [(0x4511AC,0 if bitmap==0 else self.bitmap),(self.bitmap,0)]
     cases.append(self.step(f'resources-{mode}-{sound}-{bitmap}',writes=writes,revive=alive))
  for flag in (-2147483648,-1,0,1,2147483647):
   cases.append(self.step(f'quit-window-{flag}',writes=self.defaults()+[(0x451160,7),(self.actors[0]+0xD1,b'\1'),(0x458434,flag)],revive=alive))
  for i in range(12):
   writes=self.defaults()+[(self.actors[0]+0xCE,b'\1')] if i==0 else []
   if i==4:writes=[(self.actors[0]+0xCE,b'\0')]
   if i==6:writes=[(self.actors[0]+0xD1,b'\1')]
   cases.append(self.step(f'menu-hold-confirm-{i}',writes=writes,revive=alive if i==0 else []))
  return dict(exeSHA256=EXE_SHA256,scope=__doc__,control=self.control,worldAddress=WORLD,actorAddresses=self.actors,
   globalAddress=GLOBAL,replayAddress=0x4588A8,initial=self.initial,cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True);pending=[]
  for suffix in ('','-control'):
   path=ROOT/'build/research'/f'mode-selection{suffix}.json';report=json.loads(path.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'mode-selection{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--mode-selection',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data))
   pending.append((ROOT/'docs/evidence'/path.name,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=ModeSelection(a.control).capture_all();suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode()
 path=ROOT/'build/original'/f'mode-selection{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(doc['cases']),
  events=sum(len(c['events']) for c in doc['cases']),helpers=sum(len(c['helpers']) for c in doc['cases']),playback=sum(c['continuation']=='playback' for c in doc['cases']),nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
