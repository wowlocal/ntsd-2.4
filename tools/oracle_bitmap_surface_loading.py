#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole43ed10/4013d0 and own startup/front resources in pinned NTSD/VC80.
Unicorn2.1.4 executes original loading/copy/constructor and CRT memset. Win32,
COM and allocator results are declared platform responses, tied to original
PE/file bitmap bytes. Trace complete bytes/masks, unknown private stack, API
outputs, ownership and cleanup, including ordinary failures; no source control/
protection corruption, bypass, external target, Windows pixels or fullapp claim.
See BITMAP_SURFACE_LOADING_PLAN.md. All executable execution is research only.
"""
import argparse,json,os,struct
from pathlib import Path
from collections import Counter
from unicorn.x86_const import *
from oracle_application_dispatch_entry import DispatchEntry,FULL_SIZE,BASE,STACK
from oracle_front_menu_resources import PATHS,SLOTS,NULLS
from oracle_crt import prepare,DLL_SHA256,STOP
from oracle_crt_startup import exports
from oracle_bitmap_drawing import digest
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
ARENA=0x32000000
TRACE_STACK,TRACE_SIZE=0x1000d000,0x2400
DIRECT_SP,OUT,FORMAT,NAME,DEVICE=0x1000f000,ARENA+0x100,ARENA+0x140,ARENA+0x200,ARENA+0x1000
REGS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]
API_NAMES=['module','image','getObject','deleteObject','createDC','selectObject','stretch','deleteDC','createSurface','restore','description','getDC','releaseDC','colorKey','release','message','debug']
API={STOP+0xb000+i*16:n for i,n in enumerate(API_NAMES)}
IATS={0x447088:'module',0x4471c4:'image',0x447020:'getObject',0x447018:'deleteObject',0x447030:'createDC',0x44701c:'selectObject',0x447024:'stretch',0x447028:'deleteDC',0x4471c8:'message',0x447080:'debug'}
METHODS={0x18:'createSurface',0x6c:'restore',0x58:'description',0x44:'getDC',0x68:'releaseDC',0x74:'colorKey',8:'release'}

class BitmapSurface(DispatchEntry):
 def __init__(self):
  self.resource_active=False;super().__init__();self.uc.mem_map(ARENA,0x100000);self.resources={r['path'][1]:r for r in self.pe.resources() if r['path'][0]==2};self.assets={}
 def boundary(self,u,pc,n,data):
  if self.resource_active:return
  return super().boundary(u,pc,n,data)
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if self.resource_active:self.record(p,(v&((1<<(8*n))-1)).to_bytes(n,'little'),u.reg_read(UC_X86_REG_EIP))
 def record(self,p,b,pc):
  self.writes.append(dict(pc=pc,address=p,bytes=bytes(b).hex(),eventIndex=len(self.events)))
  for r in self.regions:
   if r['address']<=p<p+len(b)<=r['address']+r['count']:r['mask'][p-r['address']:p-r['address']+len(b)]=b'\1'*len(b)
 def resource_output(self,p,b):
  self.record(p,b,None);self.write_host(p,b)
 def bind(self):
  self.api=dict(API)
  for p,name in IATS.items():self.uc.mem_write(p,struct.pack('<I',next(a for a,n in API.items() if n==name)))
  self.memset=exports(PE(prepare().read_bytes()))['memset'];self.uc.mem_write(0x447160,struct.pack('<I',self.memset))
  for pc,item in self.window.com_methods.items():
   if item[1]=='createSurface':self.api[pc]='createSurface'
  self.object(DEVICE)
 def object(self,address):
  v=address+0x100;self.uc.mem_write(address,struct.pack('<I',v))
  for offset,name in METHODS.items():self.uc.mem_write(v+offset,struct.pack('<I',next(a for a,n in API.items() if n==name)))
 def asset(self,path):
  if path not in self.assets:
   f=DEFAULT_SOURCE/path.replace('\\','/')
   if path in self.resources:
    r=self.resources[path];raw=self.pe.data[r['fileOffset']:r['fileOffset']+r['size']];kind='embedded';dib=raw
   elif f.is_file():raw=f.read_bytes();assert raw[:2]==b'BM';dib=raw[14:];kind='file'
   else:return None
   width,height=struct.unpack_from('<ii',dib,4);planes,bpp=struct.unpack_from('<HH',dib,12)
   self.assets[path]=dict(path=path,kind=kind,raw=self.blob(raw),width=width,height=abs(height),planes=planes,bpp=bpp)
  return self.assets[path]
 def frame(self,address,count,first):
  mask=bytearray(count)
  for w in self.writes[first:]:
   b=bytes.fromhex(w['bytes']);lo=max(address,w['address']);hi=min(address+count,w['address']+len(b))
   if lo<hi:mask[lo-address:hi-address]=b'\1'*(hi-lo)
  return dict(bytes=list(self.uc.mem_read(address,count)),defined=[bool(x) for x in mask])
 def resource_request(self,name,words=(),strings=(),record=None,pop=0,default=0):
  self.counts[name]+=1;key=name+'#'+str(self.counts[name]);response=dict(result=self.rs.get('results',{}).get(key,default),writes=[])
  q=dict(kind=name,words=[x&0xffffffff for x in words],strings=[list(x) for x in strings])
  if record:
   a,n=record;h=self.helpers[-1];q.update(self.frame(a,n,h['firstStore']))
  e=dict(key=key,request=q,response=response,pc=self.uc.reg_read(UC_X86_REG_EIP),returnPC=self.u32(self.uc.reg_read(UC_X86_REG_ESP)),storeCount=len(self.writes),globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)))
  self.events.append(e);return e
 def respond(self,e,pop=0,output=None):
  if output is not None and e['key'] not in self.rs.get('noOutputs',[]):
   p,b=output;e['response']['writes'].append(dict(offset=0,bytes=list(b)));self.resource_output(p,b)
  self.ret(e['response']['result'],pop)
 def bitmap_bytes(self,h):
  a=self.images[h]['asset'];return struct.pack('<4iHHI',0,a['width'],a['height'],((a['width']*a['bpp']+31)//32)*4,a['planes'],a['bpp'],0)
 def start_helper(self,pc,sp):
  kind={0x43ee50:'constructor',0x43ed10:'loader',0x4013d0:'copy',self.memset:'memset'}[pc]
  h=dict(entry=pc,kind=kind,sp=sp,returnPC=self.u32(sp),pop=12 if kind=='constructor' else 0,firstStore=len(self.writes),eventStart=len(self.events),saved=[self.uc.reg_read(r) for r in REGS])
  if kind=='loader':
   h.update(path=self.cstr(self.uc.reg_read(UC_X86_REG_EDI)).decode(),args=[self.u32(sp+4+i*4) for i in range(5)],width=self.uc.reg_read(UC_X86_REG_ECX),height=self.uc.reg_read(UC_X86_REG_EAX));self.loader_index+=1;h['index']=self.loader_index
  if kind=='copy':h['args']=[self.u32(sp+4+i*4) for i in range(6)]
  if kind=='constructor':h['wrapper']=self.uc.reg_read(UC_X86_REG_ECX)
  if kind in ('loader','copy'):
   h['stackAddress']=sp-0x200;h['stack']=self.blob(self.uc.mem_read(sp-0x200,0x200));h['knownStack']=self.blob(self.stack_known[sp-0x200-STACK:sp-STACK])
  self.helpers.append(h)
 def code(self,u,pc,n,data):
  if not self.resource_active:return super().code(u,pc,n,data)
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  if self.helpers and pc==self.helpers[-1]['returnPC'] and sp==self.helpers[-1]['sp']+4+self.helpers[-1]['pop']:
   h=self.helpers.pop();assert [u.reg_read(r) for r in REGS]==h['saved'];h.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes))
   if h['kind']=='constructor':assert h['result']==h['wrapper']
   self.returns_resource.append(h)
  if pc==STOP or self.rs['kind']=='own' and pc==0x427089:
   self.end='returned' if pc==STOP else 'settings';u.emu_stop();return
  if self.rs['kind']=='own' and pc in NULLS and self.u32(NULLS[pc])==0:self.end='nullBitmap';self.null_slot=NULLS[pc];u.emu_stop();return
  if pc==0x4450ac:
   assert self.rs['kind']=='own' and arg(0)==0x1f50;i=len(self.allocations_resource);assert i<24
   token=0 if i in self.rs.get('nulls',[]) else self.next_wrapper;backing=None
   if token:
    self.next_wrapper+=0x2000;b=bytes([0xa5])*0x1f50;backing=self.blob(b);self.uc.mem_write(token,b);self.regions.append(dict(address=token,count=len(b),mask=bytearray(len(b))))
   self.allocations_resource.append(dict(address=token,backing=backing));self.events.append(dict(kind='allocate',index=i,address=token,count=0x1f50,storeCount=len(self.writes)));self.ret(token);return
  if pc in (0x43ee50,0x43ed10,0x4013d0,self.memset):self.start_helper(pc,sp)
  if pc in self.api:
   name=self.api[pc]
   if name=='module':
    assert arg(0)==0;e=self.resource_request(name,[0],default=0x400000);self.respond(e,4);return
   if name=='image':
    path=self.cstr(arg(1)).decode();a=self.asset(path);flags=arg(5);present=a is not None and (flags==0x2010 and a['kind']=='file' or flags==0x2000 and a['kind']=='embedded') and self.loader_index not in self.rs.get('missing',[])
    h=0x34000000+16*(len(self.images)+1) if present else 0
    e=self.resource_request(name,[arg(0),arg(2),arg(3),arg(4),flags],[path.encode()],default=h);h=e['response']['result']
    if h:self.images[h]=dict(asset=a,deleted=False)
    self.respond(e,24);return
   if name=='getObject':
    assert arg(1)==24;e=self.resource_request(name,[arg(0),24],record=(arg(2),24),default=24)
    self.respond(e,12,(arg(2),self.bitmap_bytes(arg(0))) if e['response']['result'] else None);return
   if name=='createSurface':
    assert arg(3)==0;e=self.resource_request(name,[arg(0),0],record=(arg(1),108));out=None
    if e['response']['result']>=0:
     token=ARENA+0x10000+0x1000*len(self.surfaces);self.object(token);self.surfaces[token]=dict(description=list(u.mem_read(arg(1),108)),released=False);e['response']['output']=token;out=(arg(2),struct.pack('<I',token))
    # The out surface pointer is not the descriptor record's output.
    if out and e['key'] not in self.rs.get('noOutputs',[]):self.resource_output(*out)
    self.ret(e['response']['result'],16);return
   if name=='restore':e=self.resource_request(name,[arg(0)]);self.respond(e,4);return
   if name=='createDC':e=self.resource_request(name,[arg(0)],default=0x35000000+16*self.counts[name]);self.dcs[e['response']['result']]=False;self.respond(e,4);return
   if name=='selectObject':e=self.resource_request(name,[arg(0),arg(1)],default=0x36000000);self.respond(e,8);return
   if name=='description':
    e=self.resource_request(name,[arg(0)],record=(arg(1),108));self.respond(e,8,(arg(1),bytes(self.surfaces[arg(0)]['description'])) if e['response']['result']>=0 else None);return
   if name=='getDC':
    e=self.resource_request(name,[arg(0)]);out=None
    if e['response']['result']>=0:e['response']['output']=0x37000000+16*self.counts[name];out=(arg(1),struct.pack('<I',e['response']['output']))
    if out and e['key'] not in self.rs.get('noOutputs',[]):self.resource_output(*out)
    self.ret(e['response']['result'],8);return
   if name=='stretch':e=self.resource_request(name,[arg(i) for i in range(11)],default=1);self.respond(e,44);return
   if name=='releaseDC':e=self.resource_request(name,[arg(0),arg(1)]);self.respond(e,8);return
   if name=='deleteDC':e=self.resource_request(name,[arg(0)],default=1);self.dcs[arg(0)]=True;self.respond(e,4);return
   if name=='deleteObject':e=self.resource_request(name,[arg(0)],default=1);self.images[arg(0)]['deleted']=bool(e['response']['result']);self.respond(e,4);return
   if name=='colorKey':
    assert arg(1)==8 and bytes(u.mem_read(arg(2),8))==bytes(8);e=self.resource_request(name,[arg(0),8],[bytes(8)]);self.respond(e,12);return
   if name=='release':e=self.resource_request(name,[arg(0)],default=17);self.surfaces[arg(0)]['released']=True;self.respond(e,4);return
   if name=='message':e=self.resource_request(name,[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))],default=7);self.respond(e,16);return
   if name=='debug':e=self.resource_request(name,strings=[self.cstr(arg(0))]);self.respond(e,4);return
   raise AssertionError(name)
  assert 0x43ed10<=pc<=0x43ef41 or 0x4013d0<=pc<=0x4014d1 or 0x424784<=pc<0x427089 or pc==0x4450a0 or 0x4450b2<=pc<=0x4450ba or 0x78130000<=pc<0x781c0000,hex(pc)
  self.original(u,pc,n)
 def snapshot_resource(self):
  return dict(pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),result=self.uc.reg_read(UC_X86_REG_EAX),globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)),stack=self.blob(self.uc.mem_read(TRACE_STACK,TRACE_SIZE)),knownStack=self.blob(self.stack_known[TRACE_STACK-STACK:TRACE_STACK-STACK+TRACE_SIZE]),output=self.blob(self.uc.mem_read(OUT,8)),cw=self.uc.reg_read(UC_X86_REG_FPCW),seh=self.u32(0))
 def run(self,s):
  parents=None
  if s['kind']=='own':
   p,l,e=super().run_entry(dict(index=0 if s.get('windowParam',0)==0 else 1,windowParam=s.get('windowParam',0),results={}))
   ph=digest(json.dumps(p,sort_keys=True,separators=(',',':')).encode());l['parent']=ph;lh=digest(json.dumps(l,sort_keys=True,separators=(',',':')).encode());e.update(parent=ph,loop=lh)
   parents=dict(parent=json.loads(json.dumps(p)),loop=json.loads(json.dumps(l)),entry=json.loads(json.dumps(e)))
   occupied=[r['address'] for r in self.panel.panel.regions];self.next_wrapper=max(occupied,default=0x2800e020)+0x2000;start=0x4450ac
  else:
   self.uc.mem_write(TRACE_STACK,b'\xa5'*TRACE_SIZE);self.stack_known=bytearray(0x10000);self.reserved=None;self.provenance=[]
   self.uc.mem_write(OUT,b'\x5a'*8);self.uc.mem_write(FORMAT,struct.pack('<8I',32,0x40,0,32,0xff0000,0xff00,0xff,0));self.uc.mem_write(NAME,s.get('path','MENU_CLIP').encode()+b'\0')
   self.uc.reg_write(UC_X86_REG_ESP,DIRECT_SP);self.uc.reg_write(UC_X86_REG_ECX,s.get('width',0)&0xffffffff);self.uc.reg_write(UC_X86_REG_EAX,s.get('height',0)&0xffffffff);self.uc.reg_write(UC_X86_REG_EDI,NAME)
   if s['kind']=='loader':args=[DEVICE,s.get('flags',0x40),FORMAT if s.get('format') else 0,OUT,OUT+4];start=0x43ed10
   else:args=[DEVICE if s.get('surface',True) else 0,0x34000010 if s.get('bitmap',True) else 0,*s.get('copy',[0,0,0,0])];start=0x4013d0
   self.uc.mem_write(DIRECT_SP,struct.pack('<'+'I'*(len(args)+1),STOP,*[a&0xffffffff for a in args]));self.next_wrapper=0
  self.rs=s;self.bind();self.stores=[];self.phase='bitmapSurface';self.events=[];self.writes=[];self.stack_stores=[];self.global_stores=[];self.global_mask=bytearray(0xb440);self.call_pcs={};self.regions=[];self.counts=Counter();self.helpers=[];self.returns_resource=[];self.allocations_resource=[];self.images={};self.surfaces={};self.dcs={};self.loader_index=-1;self.end=None;self.null_slot=None
  if s['kind']=='copy':
   a=self.asset(s.get('path','MENU_CLIP'));self.images[0x34000010]=dict(asset=a,deleted=False);desc=bytearray(108);struct.pack_into('<4I',desc,0,108,7,a['height'],a['width']);self.surfaces[DEVICE]=dict(description=list(desc),released=False)
  before=self.snapshot_resource();crt=self.snapshot();self.active=self.resource_active=True
  try:self.uc.emu_start(start,0,count=2_000_000)
  except Exception as error:
   self.capture_path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(error),spec=s,after=self.snapshot_resource(),events=self.events,writes=self.writes,instructions=self.call_pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.active=self.resource_active=False
  # Unicorn can stop at the already registered caller sentinel without
  # delivering its code hook on a short return path. Observe the actual ret
  # registers/SP after execution; the sentinel remains unexecuted.
  terminal_hook=self.end is not None
  if self.end is None and s['kind']!='own' and self.uc.reg_read(UC_X86_REG_EIP)==STOP:
   assert len(self.helpers)==1;h=self.helpers.pop();sp=self.uc.reg_read(UC_X86_REG_ESP)
   assert h['returnPC']==STOP and sp==h['sp']+4 and [self.uc.reg_read(r) for r in REGS]==h['saved']
   h.update(result=self.uc.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.returns_resource.append(h);self.end='returned'
  assert self.end is not None and not self.helpers,(self.end,self.snapshot_resource(),self.helpers)
  return dict(spec=s,terminalHookObserved=terminal_hook,parents=parents,before=before,after=self.snapshot_resource(),crtBefore=crt,crtAfter=self.snapshot(),events=self.events,writes=self.writes,stackStores=self.stack_stores,helpers=self.returns_resource,allocations=self.allocations_resource,records=[dict(address=r['address'],bytes=self.blob(self.uc.mem_read(r['address'],r['count'])),mask=self.blob(r['mask'])) for r in self.regions],images=self.images,surfaces=self.surfaces,dcs=self.dcs,end=self.end,nullSlot=self.null_slot,instructions=self.call_pcs)

def specs():
 for path in dict.fromkeys(PATHS):yield dict(kind='loader',path=path)
 yield dict(kind='loader',path='bg\\sys\\District\\district3.bmp',width=17,height=23,flags=0x40,format=True)
 yield dict(kind='loader',path='sprite\\sys\\ad0.bmp')
 for kind,values in [('createSurface',[-2147483648,-1,1,2147483647]),('getDC',[-2147483648,-1,1,2147483647]),('restore',[-1,1]),('createDC',[0]),('selectObject',[0,-1]),('stretch',[0,-1]),('releaseDC',[-1,1]),('deleteDC',[0]),('deleteObject',[0]),('description',[-1,1]),('getObject',[0])]:
  yield from (dict(kind='loader',results={kind+'#1':v}) for v in values)
 for flag in [0,1,0x80000000,0xffffffff]:yield dict(kind='loader',format=True,flags=flag)
 for surface,bitmap in [(False,True),(True,False),(False,False)]:yield dict(kind='copy',surface=surface,bitmap=bitmap)
 for rect in [[0,0,0,0],[3,7,9,11],[-1,-2,-3,-4],[0,0,0,19],[0,0,17,0]]:yield dict(kind='copy',copy=rect)
 yield dict(kind='copy',results={'getObject#1':0},copy=[0,0,9,11])
 yield dict(kind='copy',results={'description#1':-1,'getDC#1':-1})
 for wp in [0,1]:yield dict(kind='own',windowParam=wp)
 for changes in [dict(missing=[0]),dict(results={'createSurface#1':-1}),dict(results={'createSurface#24':1}),dict(results={'colorKey#24':-1}),dict(nulls=[0]),dict(nulls=[1])]:yield dict(kind='own',**changes)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--own-only',action='store_true');p.add_argument('--offset',type=int,default=0);a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};assets={}
 for i,s in enumerate([s for s in specs() if not a.own_only or s['kind']=='own'][a.offset:]):
  if a.limit is not None and i>=a.limit:break
  vm=BitmapSurface();vm.capture_path=a.output;c=vm.run(s);cases.append(c);blobs.update(vm.blobs);assets.update(vm.assets)
  part=parts/f'{i:04d}.json';temp=part.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,part);print('completed',i,s,c['end'],hex(c['after']['pc']),len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,assets=assets,stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,nativeCompared=False,windowsVerified=False);raw=(json.dumps(d,separators=(',',':'))+'\n').encode();a.output.write_bytes(raw);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
