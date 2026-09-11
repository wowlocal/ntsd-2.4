#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh music/11 embedded menu bitmaps through installed-library screen and ret4.
Pinned NTSD/lib/VC80/DIBs under Unicorn2.1.4; actual41bc90 prologue and declared
4229cc tail, skipping the earlier tick body. Same CPU executes music/sprintf,
whole bitmap helpers, screen/panel/output/normal cookie checks and actual return.
Full memory/stack/helper/ownership observations recover composition. API/COM/GDI/
allocator/PTD/time are controlled responses, not host/Windows/device behavior.
NULL-SPARK stops before the known write; no fault continuation, private expected
inputs, damaged control/protection structures or bypass. FRESH_LIBRARY_MENU_PLAN.
"""
import argparse,collections,json,os,struct
from pathlib import Path
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
from oracle_lib_menu_continuation import MenuContinuation,SPRINT,TAIL_SP,SP,LIB,BM,TARGET,STACK,WORLD,GLOBAL,GSIZE,REGISTERS,EXE_SHA256,DLL_SHA256,digest,STOP
from oracle_bitmap_surface_loading import BitmapSurface,ARENA,API as BITMAP_API,IATS,DEVICE
from oracle_menu_resources import PATHS,SLOTS,STORES,RETURNS
from oracle_music_playback import MusicPlayback,platform,HELPERS as MUSIC_HELPERS,ARENA as MUSIC_ARENA,API as MUSIC_API
from oracle_crt_startup import exports
from oracle_crt import prepare
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE

WRAPPERS=0x50000020
class BitmapAdapter(BitmapSurface):
 def __init__(self,owner):
  self.owner=owner;self.uc=owner.uc;self.pe=PE(next(DEFAULT_SOURCE.glob('*.exe')).read_bytes());self.resources={r['path'][1]:r for r in self.pe.resources() if r['path'][0]==2};self.assets={};self.api=dict(BITMAP_API)
  self.rs={};self.resource_active=True;self.helpers=[];self.returns_resource=[];self.events=[];self.counts=collections.Counter();self.images={};self.surfaces={};self.dcs={};self.loader_index=-1;self.allocations_resource=[];self.checkpoints=[]
  self.uc.mem_map(ARENA,0x100000);self.uc.mem_map(STOP+0xb000,0x1000)
  for p,name in IATS.items():owner.put(p,next(a for a,n in BITMAP_API.items() if n==name))
  self.memset=exports(PE(prepare().read_bytes()))['memset'];owner.put(0x447160,self.memset);self.object(DEVICE)
 def u32(self,p):return self.owner.u32(p)
 def cstr(self,p):return self.owner.cstr(p)
 def ret(self,*args):return self.owner.ret(*args)
 def blob(self,raw):return self.owner.blob(raw)
 def original(self,u,pc,n):self.owner.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex()
 @property
 def writes(self):return self.owner.writes
 @property
 def stack_known(self):return self.owner.regions[STACK]['mask']
 def resource_output(self,p,b):self.owner.write(p,b)
 def append(self,e):self.events.append(e);self.owner.event('startup',startup=e)
 def resource_request(self,name,words=(),strings=(),record=None,pop=0,default=0):
  self.counts[name]+=1;key=name+'#'+str(self.counts[name]);response=dict(result=self.rs.get('results',{}).get(key,default),writes=[]);q=dict(kind=name,words=[x&0xffffffff for x in words],strings=[list(x) for x in strings])
  if record:q.update(self.frame(*record,self.helpers[-1]['firstStore']))
  e=dict(key=key,request=q,response=response,pc=self.uc.reg_read(UC_X86_REG_EIP),returnPC=self.u32(self.uc.reg_read(UC_X86_REG_ESP)),storeCount=len(self.writes),globals=self.blob(self.uc.mem_read(GLOBAL,GSIZE)))
  self.append(e);return e
 def finish(self,pc):
  sp=self.uc.reg_read(UC_X86_REG_ESP)
  while self.helpers and pc==self.helpers[-1]['returnPC']:
   h=self.helpers.pop();assert sp==h['sp']+4+h['pop'] and h['saved']==[self.uc.reg_read(r) for r in REGISTERS]
   h.update(result=self.uc.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.returns_resource.append(h)
   self.owner.helpers.append(dict(entry=h['entry'],entrySP=h['sp'],pop=h['pop'],returnPC=h['returnPC'],saved=h['saved'],firstStore=h['firstStore'],lastStore=h['lastStore'],eventStart=h['wholeEventStart'],eventEnd=len(self.owner.events),returnSP=sp,result=h['result']))
 def start_helper(self,pc,sp):
  super().start_helper(pc,sp);self.helpers[-1].update(eventStart=len(self.events),wholeEventStart=len(self.owner.events))
 def records(self):
  out=[]
  for a in self.allocations_resource:
   p=a['address']
   if not p:continue
   r=self.owner.regions[p];assert bytes(self.uc.mem_read(p-16,16))==b'\x96'*16 and bytes(self.uc.mem_read(p+r['size'],16))==b'\x69'*16
   out.append(dict(address=p,count=r['size'],kind='bitmap',initial=a['backing'],bytes=self.blob(self.uc.mem_read(p,r['size'])),mask=self.blob(r['mask'])))
  return out
 def snapshot(self):return dict(globals=self.blob(self.uc.mem_read(GLOBAL,GSIZE)),cw=self.uc.reg_read(UC_X86_REG_FPCW),sp=self.uc.reg_read(UC_X86_REG_ESP))
 def checkpoint(self,kind,index=-1):self.checkpoints.append(dict(kind=kind,index=index,snapshot=self.snapshot(),records=self.records(),eventCount=len(self.events),storeCount=len(self.writes)));self.owner.point('resources-'+kind)
 def code(self,u,pc,n,data):
  self.finish(pc);sp=u.reg_read(UC_X86_REG_ESP)
  if pc==0x4450ac:
   index=len(self.allocations_resource);assert index<11 and self.u32(sp+4)==0x1f50
   address=0 if index in self.rs.get('nulls',[]) else WRAPPERS+(10-index if self.rs.get('reverse') else index)*0x2000
   backing=None if address==0 else self.blob(u.mem_read(address,0x1f50))
   if address:self.owner.live[address]=True
   self.allocations_resource.append(dict(address=address,backing=backing));self.append(dict(kind='allocate',index=index,address=address,count=0x1f50,storeCount=len(self.writes)));self.ret(address);return
  if pc==0x43ee50:
   index=len(self.allocations_resource)-1;address=u.reg_read(UC_X86_REG_ECX);path=self.cstr(self.u32(sp+8)).decode()
   assert address==self.allocations_resource[index]['address'] and path==PATHS[index] and self.u32(sp)==RETURNS[index]
   self.append(dict(kind='construct',index=index,address=address,path=path,storeCount=len(self.writes)))
  super().code(u,pc,n,data)

class MusicAdapter(MusicPlayback):
 def __init__(self,owner):
  self.owner=owner;self.uc=owner.uc;self.music_api_address=MUSIC_API;self.music_arena=MUSIC_ARENA;self.music_tokens=[MUSIC_ARENA+0x2000+i*0x100 for i in range(5)]
  self.uc.mem_map(MUSIC_ARENA,0x400000);self.uc.mem_map(MUSIC_API,0x1000);self.bind_music();owner.put(0x447174,SPRINT)
  self.music_running=True;self.music_pending=[];self.music_calls=[];self.music_events=[];self.music_formats=[];self.music_allocations=[];self.music_end=-1
 def put(self,p,v):
  if self.owner.running:self.owner.write(p,struct.pack('<I',v&0xffffffff))
  else:self.owner.put(p,v)
 def write_host(self,p,b):self.owner.write(p,b)
 def u32(self,p):return self.owner.u32(p)
 def cstr(self,p):return self.owner.cstr(p)
 def ret(self,*a):return self.owner.ret(*a)
 def region(self,p,n):return self.owner.region(p,n)
 def add_backing(self,p,n,kind):
  assert n==26;self.owner.live[p]=True
  return dict(address=p,size=n,kind=kind,initial=bytes(self.uc.mem_read(p,n)))
 def mevent(self,kind,args=(),strings=(),result=0,pointer=None,raw=None):
  if self.owner.startup_done:self.owner.event(kind,args,strings);return
  super().mevent(kind,args,strings,result,pointer,raw);self.owner.graphics.append(dict(kind='music',music=self.music_events[-1],globals=self.owner.blob(self.uc.mem_read(GLOBAL,GSIZE)),storeCount=len(self.owner.writes)))
 def finish(self,pc):
  sp=self.uc.reg_read(UC_X86_REG_ESP)
  while self.music_pending and pc==self.music_pending[-1]['returnAddress']:
   h=self.music_pending.pop();assert sp==h['entrySP']+4 and h['saved']==[self.uc.reg_read(r) for r in REGISTERS]
   h.update(returnSP=sp,returned=self.uc.reg_read(UC_X86_REG_EAX),lastStore=len(self.owner.writes),eventEnd=len(self.owner.graphics.events));self.music_calls.append(h)
   self.owner.helpers.append(dict(entry=h['entry'],entrySP=h['entrySP'],pop=0,returnPC=h['returnAddress'],saved=h['saved'],firstStore=h['firstStore'],lastStore=h['lastStore'],eventStart=h['wholeEventStart'],eventEnd=len(self.owner.events),returnSP=sp,result=h['returned']))
 def code(self,u,pc,n,data):
  before=len(self.music_pending);first=len(self.owner.writes);start=len(self.owner.events)
  self.music_code(u,pc,n,data)
  if len(self.music_pending)>before:self.music_pending[-1].update(firstStore=first,eventStart=len(self.owner.graphics.events)-1,wholeEventStart=start)
  if pc not in self.music_imports and pc!=0x4450c8:self.owner.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex()

class FreshMenu(MenuContinuation):
 def memset(self,u,pc,n,data):
  # The inherited constructor-only adapter is inapplicable here. Let the
  # original4450a0 import thunk and pinned VC80 memset execute normally.
  assert pc==0x4450a0
 def __init__(self,control=False):
  super().__init__(control);self.startup_done=False;self.graphics=BitmapAdapter(self);self.music=MusicAdapter(self);self.current_graph=None
  message=next(p for p,n in BITMAP_API.items() if n=='message');self.put(0x4471c8,message);self.music.music_imports[message]='message'
  self.uc.mem_map(WRAPPERS&~0xffff,0x20000)
  for p,n in [(WRAPPERS+i*0x2000,0x1f50) for i in range(11)]+[(MUSIC_ARENA+0x10020,26)]:
   self.uc.mem_write(p-16,b'\x96'*16);self.uc.mem_write(p+n,b'\x69'*16);raw=bytes(i%256 for i in range(n)) if control else b'\xa5'*n;self.add_region(p,raw,False);self.live[p]=False
  for lo,hi in [(WRAPPERS&~0xffff,(WRAPPERS&~0xffff)+0x1ffff),(MUSIC_ARENA+0x10000,MUSIC_ARENA+0x3fffff)]:self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=lo,end=hi)
 def code(self,u,pc,n,data):
  if not self.running or self.prologue:return super().code(u,pc,n,data)
  self.graphics.finish(pc);self.music.finish(pc);sp=u.reg_read(UC_X86_REG_ESP)
  if self.current_graph and pc==self.current_graph['returnPC']:
   h=self.current_graph;self.current_graph=None;assert sp==h['entrySP']+4
   raw=self.cstr(h['destination']);assert len(raw)==u.reg_read(UC_X86_REG_EAX)
   h.update(returnSP=sp,result=len(raw),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h);self.music.mevent('format',[len(raw)],[b'%s\\graph.log',raw])
  if pc==0x4297ae:
   assert not self.music.music_pending and self.current_graph is None;self.point('musicReturned');self.music_boundary=dict(snapshot=self.graphics.snapshot(),allocations=self.music_records(),eventCount=len(self.graphics.events))
  if pc==0x4297e1:self.graphics.checkpoint('prefix')
  if pc in STORES:self.graphics.checkpoint('bitmap',STORES.index(pc))
  if pc==0x429b21:
   self.graphics.checkpoint('seats')
   if u.reg_read(UC_X86_REG_EAX)==0:self.end='nullSpark';u.emu_stop();return
  if pc==0x429c56:self.graphics.checkpoint('flag')
  if pc==0x429e5a:
   self.graphics.checkpoint('complete');self.startup_done=True;self.startup_after=self.graphics.snapshot();self.startup_record=self.graphics.records();self.point('startupReturned')
  if pc==SPRINT and not self.startup_done:
   fmt=self.cstr(self.u32(sp+8));assert fmt==b'%s\\graph.log'
   self.current_graph=dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events),destination=self.u32(sp+4));self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  if self.current_graph:
   if pc in self.crt.boundaries:return
   assert 0x78130000<=pc<0x78230000;self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  if self.startup_done and pc in self.music.music_imports:return self.music.music_api(self.music.music_imports[pc])
  if not self.startup_done and ((pc in self.music.music_imports and (pc not in self.graphics.api or self.music.music_pending)) or pc==0x4450c8 or 0x401c90<=pc<=0x401e85 or 0x401f30<=pc<=0x4020f6 or self.music.music_pending and 0x4450b2<=pc<=0x4450ba):return self.music.code(u,pc,n,data)
  if pc in self.graphics.api or pc in (0x4450ac,0x43ee50,0x43ed10,0x4013d0,self.graphics.memset) or self.graphics.helpers and (0x43ed10<=pc<=0x43ef41 or 0x4013d0<=pc<=0x4014d1 or 0x78130000<=pc<0x78230000 or 0x4450b2<=pc<=0x4450ba or pc==0x4450a0):return self.graphics.code(u,pc,n,data)
  if 0x4297ae<=pc<0x429e5a:self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  return super().code(u,pc,n,data)
 def music_records(self):
  out=[]
  for a in self.music.music_allocations:
   p,n=a['address'],a['size'];assert bytes(self.uc.mem_read(p-16,16))==b'\x96'*16 and bytes(self.uc.mem_read(p+n,16))==b'\x69'*16
   out.append(dict(address=p,count=n,kind='music-wide',initial=self.blob(a['initial']),bytes=self.blob(self.uc.mem_read(p,n)),mask=self.blob(self.regions[p]['mask'])))
  return out
 def probe(self,spec):
  self.graphics.rs=dict(kind='fresh',ramp=spec['control'],reverse=spec['control'],**spec.get('resources',{}));self.music.music_input=platform(**spec.get('music',{}))
  c=super().probe(spec);g=self.graphics
  c['startup']=dict(spec=dict(label=spec['label'],ramp=spec['control'],reverse=spec['control'],**spec.get('resources',{})),before=dict(globals=next(x['storage']['bytes'] for x in c['before'] if x['address']==GLOBAL),cw=0x23f,sp=SP),after=g.snapshot() if not self.startup_done else self.startup_after,allocations=g.allocations_resource,checkpoints=g.checkpoints,records=g.records(),events=g.events,helpers=g.returns_resource,images=g.images,surfaces=g.surfaces,dcs=g.dcs,end='ready' if self.startup_done else 'nullSpark',musicBoundary=self.music_boundary,musicAllocations=self.music_records(),musicInput=self.music.music_input,musicCalls=self.music.music_calls)
  return c

def specs():
 variations=[('nominal',{}),('confirm-release',dict(buttons=[(2,0xd1,1)])),('network-overlay',dict(globals={0x44d058:2,0x44f1af:1,0x450b70:3})),('volume-up',dict(volumeKeys=[0x75,0x64])),('help',dict(globals={0x4513c0:1})),('panel-click',dict(globals={0x4546f0:591,0x453cdc:200,0x457580:1})),('playback',dict(globals={0x451160:6},buttons=[(2,0xd1,1)])),('surface-last-positive',dict(resources=dict(results={'createSurface#11':1}))),('retained-missing-rface',dict(resources=dict(missing=[9],results={'description#10':-1}))),('create-graph-negative',dict(music=dict(createResult=-1,createPointer=0))),('render-negative',dict(music=dict(renderResult=-1))),('null-wide',dict(music=dict(nullAllocation=True))),('null-spark',dict(resources=dict(nulls=[10])))]
 for control in (False,True):
  for label,fields in variations:
   g={0x44d07c:1,0x4512cc:0,0x457578:DEVICE,0x4546f4:0x73000001,**{0x44f040+i*4:MUSIC_ARENA+0x2000+i*0x100 for i in range(4)}};g.update(fields.get('globals',{}))
   yield dict(label=label+('-control' if control else ''),control=control,**{k:v for k,v in fields.items() if k!='globals'},globals=g,strings={0x44ef04:'old.wma',0x44ef38:'C:\\NTSD'},output=dict(queriedAudio=MUSIC_ARENA+0x2400))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();items=list(specs())
 if a.manifest_only:a.output.write_text(json.dumps(items,indent=2)+'\n');print('Finite cases',len(items));raise SystemExit(0)
 parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={}
 for i,s in enumerate(items):
  if a.limit is not None and i>=a.limit:break
  vm=FreshMenu(s['control']);vm.capture_path=a.output;c=vm.probe(s);temp=parts/f'{i:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(c);blobs.update(vm.blobs);installations.append(vm.installation);assets.update(vm.graphics.assets);print('completed',i,s['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,installations=installations,assets=assets,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
