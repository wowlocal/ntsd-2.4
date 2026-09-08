#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh World/resources/settings/screen prefix -> actual427127/whole4236d0.
All four content/bitmap/default/cache children execute on the same CPU/stack,
using existing child observers and actual VC80 file functions. Later caller,
worker globals, translated files, DIB/allocator/device, scratch and user-buffered
FILE inputs are explicit. First natural path continues without state restoration.
Stops at42712c or BEFORE unsupported unterminated sscanf. No worker/pixels/W claim.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from oracle_front_screen_prelude import FrontScreenPrelude,PAPI
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,SOURCE,VTABLE,BODY_SP,REGISTERS
from oracle_state import STACK,STOP
from oracle_menu_content import MenuContent,LOCAL_SIZE,OPEN,CLOSE as READ_CLOSE,SCAN
from oracle_menu_panel_bitmap import MenuPanelBitmap,API,SIZE
from oracle_menu_info_writing import MenuInfoWriting,FPRINT,FCLOSE
from oracle_crt import FILE,INPUT,PTD,DLL_SHA256
from oracle_bitmap_drawing import digest,packed,signed
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ESP,UC_X86_REG_EIP
PANEL_HEAP,PANEL_SURFACE=0x2C000000,0x28006900
ENTRIES={0x43C780:'content',0x43CC60:'bitmap',0x43C690:'defaults',0x43C710:'cache'}

class MenuPanelUpdate(FrontScreenPrelude):
 def __init__(self,control=False):
  self.update_active=False;super().__init__(control)
  first=self.prefix_step('first-screen-prefix');assert first['continuation']=='critical'
  # Keep the established parent inventory even though this first prefix needs
  # only MENU_BACK1. No extra source calls or replacement parent state.
  sources=[]
  for i in range(1,14):
   name=f'MENU_BACK{i}';r=self.resources[name];raw=self.pe.data[r['fileOffset']:r['fileOffset']+r['size']];w,h=struct.unpack_from('<ii',raw,4)
   sources.append(dict(path=name,width=w,height=h,dib=self.blob(raw)))
  self.screen_parent=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,parent=self.parent,initialGlobals=self.prefix_initial_globals,sources=sources,cases=[first])
  self.update_initial=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));self.caller_saved=[self.uc.reg_read(r) for r in REGISTERS]
  self.old_world=self.world_record();self.old_records=[dict(address=r['address'],storage=self.record(r)) for r in self.regions]
  self.uc.mem_map(PANEL_HEAP,0x200000)
  for i in range(10):self.put(PANEL_SURFACE+16*i,VTABLE)
  self.put(0x447158,SCAN);self.put(0x447180,FPRINT);self.put(0x44717C,API+64)
  for lo,hi in [(GLOBAL,GLOBAL+GLOBAL_SIZE-1),(STACK,STACK+0xFFFF),(INPUT,INPUT+4095),(PANEL_HEAP,PANEL_HEAP+0x1FFFFF)]:
   self.uc.hook_add(UC_HOOK_MEM_WRITE,self.update_write,begin=lo,end=hi)
  self.reader=MenuContent.__new__(MenuContent);self.writer=MenuInfoWriting.__new__(MenuInfoWriting);self.panel=MenuPanelBitmap.__new__(MenuPanelBitmap)
  for child in (self.reader,self.writer,self.panel):child.uc=self.uc;child.blobs=self.blobs;child.active=False;child.control=control
  self.panel.regions=[];self.panel.next_address=0;self.panel.heap_base=PANEL_HEAP;self.panel.device=SOURCE
  self.panel_sources={}
 def update_write(self,uc,access,p,size,value,data):
  if not self.update_active:return
  pc=uc.reg_read(UC_X86_REG_EIP)
  if self.child:
   kind=self.child['kind']
   if kind=='content' and (GLOBAL<=p<GLOBAL+GLOBAL_SIZE or self.reader.local_base<=p and p+size<=self.reader.local_base+LOCAL_SIZE):self.reader.changed(uc,access,p,size,value,data)
   elif kind=='bitmap' and (GLOBAL<=p<GLOBAL+GLOBAL_SIZE or PANEL_HEAP<=p<PANEL_HEAP+0x200000):self.panel.written(uc,access,p,size,value,data)
   elif kind in ('defaults','cache') and (GLOBAL<=p<GLOBAL+GLOBAL_SIZE or INPUT<=p and p+size<=INPUT+self.writer.capacity):self.writer.changed(uc,access,p,size,value,data)
  elif GLOBAL<=p and p+size<=GLOBAL+GLOBAL_SIZE:
   assert 0x4236D0<=pc<=0x4237D3
   self.update_events.append(dict(kind='write',arguments=[p,size,value&((1<<(8*size))-1)]))
 def begin_child(self,entry,sp):
  kind=ENTRIES[entry];item=dict(kind=kind,entry=entry,entrySP=sp,returnPC=self.u32(sp),saved=[self.uc.reg_read(r) for r in REGISTERS]);self.child=item
  self.update_events.append(dict(kind='call',arguments=[entry]))
  if kind=='content':
   r=self.reader;attempt=self.read_index;self.read_index+=1;content=self.texts[attempt] if attempt<len(self.texts) else None
   r.local_base=sp-0x454
   if self.force_scratch:self.uc.mem_write(r.local_base,b'\xa5'*LOCAL_SIZE)
   r.local_mask=bytearray(LOCAL_SIZE);r.present=content is not None;r.closed=False;r.close_result=0;r.pending=None;r.events=[];r.end='returned'
   self.crt.data=content or b'';self.crt.read_position=0;self.crt.chunk=self.chunk;r.read_position=0
   item.update(input=None if content is None else self.blob(content),localAddress=r.local_base,backing=self.blob(self.uc.mem_read(r.local_base,LOCAL_SIZE)),index=signed(self.u32(0x44D784)),chunk=self.chunk,closeResult=0)
   r.active=True
  elif kind=='bitmap':
   p=self.panel;mode=self.bitmap_modes[self.bitmap_index] if self.bitmap_index<len(self.bitmap_modes) else 'missing';self.bitmap_index+=1
   path=self.cstr(0x453D40).decode();name='MENU_BACK1';r=self.resources[name];raw=self.pe.data[r['fileOffset']:r['fileOffset']+r['size']];w,h=struct.unpack_from('<ii',raw,4)
   self.panel_sources[name]=dict(path=name,width=w,height=h,dib=self.blob(raw))
   p.path=path;p.null=mode=='null';p.reuse=True;p.key=-1 if mode=='key' else 0;p.release_result=17;p.allocation=None;p.events=[];p.calls=[];p.pending=None
   p.surface=0 if mode=='missing' else PANEL_SURFACE+16*(1+len(p.regions)%8)
   p.resource=dict(path=path,present=p.surface!=0,width=w if p.surface else None,height=h if p.surface else None)
   item.update(source=name,surface=p.surface,colorKeyResult=p.key,releaseResult=17);p.active=True
  else:
   w=self.writer;w.capacity=self.capacity;w.available=self.available;w.write_mode=self.write_mode;w.fail_at=self.fail_at;w.close_result=self.close_result;w.write_index=0;w.events=[];w.pending=None
   backing=self.backing(w.capacity);w.mask=bytearray(w.capacity);self.uc.mem_write(INPUT,backing)
   self.uc.mem_write(FILE,struct.pack('<8I',INPUT,w.capacity,INPUT,0x102,0xFFFFFFFF,0,w.capacity,0));self.put(PTD+8,0)
   item.update(capacity=w.capacity,available=w.available,writeMode=w.write_mode,failAt=w.fail_at,closeResult=w.close_result,backing=self.blob(backing));w.active=True
 def finish_child(self,returned=True):
  c=self.child;kind=c['kind'];c['completed']=returned;c['endPC']=self.uc.reg_read(UC_X86_REG_EIP);c['endSP']=self.uc.reg_read(UC_X86_REG_ESP)
  c['result']=self.uc.reg_read(UC_X86_REG_EAX) if returned else None
  if returned:
   assert c['endSP']==c['entrySP']+4 and c['saved']==[self.uc.reg_read(r) for r in REGISTERS]
   self.update_events.append(dict(kind='return',arguments=[c['entry'],c['result']]))
  if kind=='content':
   r=self.reader;assert r.pending is None;c.update(events=r.events,globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),scratch=r.scratch());r.active=False
  elif kind=='bitmap':
   p=self.panel;assert p.pending is None;c.update(events=p.events,allocation=p.allocation,resource=None if p.null else p.resource,calls=p.calls,
    globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),records=[dict(address=r['address'],live=r['live'],storage=p.record(r)) for r in p.regions]);p.active=False
  else:
   w=self.writer;assert w.pending is None;c.update(events=w.events,**w.snapshot());w.active=False
  self.children.append(c);self.child=None
 def code(self,uc,pc,size,data):
  if not self.update_active:return super().code(uc,pc,size,data)
  sp=uc.reg_read(UC_X86_REG_ESP)
  if self.child and pc==self.child['returnPC']:self.finish_child()
  if pc==0x42712C:
   assert not self.child and sp==BODY_SP and self.root_saved==[uc.reg_read(r) for r in REGISTERS]
   self.update_end='ready';uc.emu_stop();return
  if pc==0x4236D0:
   assert sp==BODY_SP-4 and self.u32(sp)==0x42712C;self.root_saved=[uc.reg_read(r) for r in REGISTERS]
  if pc in ENTRIES:
   assert self.child is None;self.begin_child(pc,sp)
  if self.child:
   kind=self.child['kind']
   if kind=='content':self.reader.read_position=self.crt.read_position;self.reader.code(uc,pc,size,data)
   elif kind=='bitmap':self.panel.code(uc,pc,size,data)
   else:
    # Existing read fclose boundary tail-enters actual DLL fclose for writers.
    if pc==READ_CLOSE:uc.reg_write(UC_X86_REG_EIP,FCLOSE);return
    self.writer.code(uc,pc,size,data)
   return
  if pc in (PAPI+32,PAPI+48):
   assert self.u32(sp+4)==0x4554A4;self.update_events.append(dict(kind='enter' if pc==PAPI+32 else 'leave',arguments=[0x4554A4]));self.ret(0,4);return
  assert pc==0x427127 or 0x4236D0<=pc<=0x4237D3,hex(pc)
 def update_step(self,label,writes=(),texts=(),bitmaps=(),chunk=4096,capacity=64,available=True,write_mode='full',fail_at=-1,close=0,force_scratch=False):
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  self.texts=texts;self.bitmap_modes=bitmaps;self.chunk=chunk;self.capacity=capacity;self.available=available;self.write_mode=write_mode;self.fail_at=fail_at;self.close_result=close;self.force_scratch=force_scratch
  self.update_events=[];self.children=[];self.child=None;self.update_end=None;self.read_index=0;self.bitmap_index=0
  if label!='first-natural-update':
   self.uc.reg_write(UC_X86_REG_ESP,BODY_SP)
   for r,v in zip(REGISTERS,self.caller_saved):self.uc.reg_write(r,v)
  self.update_active=True
  try:self.uc.emu_start(0x427127,0,count=10_000_000)
  except Exception:
   print('UPDATE FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.update_events[-3:],self.child,flush=True);raise
  finally:self.update_active=False
  if self.child:
   assert self.child['kind']=='content' and self.reader.end=='unterminatedInput';self.update_end='contentBoundary';self.finish_child(False)
  assert self.update_end and self.world_record()==self.old_world
  records=[dict(address=r['address'],storage=self.record(r)) for r in self.regions];assert records==self.old_records
  for r in self.panel.regions:
   assert bytes(self.uc.mem_read(r['address']-16,16))==b'\x96'*16 and bytes(self.uc.mem_read(r['address']+SIZE,16))==b'\x69'*16
  return dict(label=label,stimulus=stimulus,events=self.update_events,children=self.children,continuation=self.update_end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),
   globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),world=self.old_world,records=records,panelRecords=[dict(address=r['address'],live=r['live'],storage=self.panel.record(r)) for r in self.panel.regions])
 def capture_update(self):
  absent=['data/ad0.txt','data/ad1.txt','sprite/sys/ad0.bmp','sprite/sys/ad1.bmp'];assert all(not (DEFAULT_SOURCE/p).exists() for p in absent)
  lines=['123\n']+[f'ba {i+1} {i+2} {i+3} {i+4} ?row{i} bae\n' for i in range(24)]+[f'ta {i+1} {i+2} {i+3} ?text{i} tae\n' for i in range(8)]+['un 7 ?link une\n','y -15 23 ye\n','<end>\n'];valid=''.join(lines).encode()
  def inputs(status=2,old=1,new=2,index=0,date=b'new-date\0'):
   return [(0x458424,status),(0x44D778,old),(0x44D77C,new),(0x44D784,index),(0x44D788,4),(0x4527B0,b'old-date\0'),(0x458350,date)]
  cases=[self.update_step('first-natural-update')]
  for status in (-2147483648,-1,0,1,3,2147483647):cases.append(self.update_step(f'status-{status}',inputs(status=status)))
  for old in (-2147483648,-99,-1,0,1,2147483647):
   for new in (-2147483648,-99,-1,0,1,2147483647):cases.append(self.update_step(f'versions-{old}-{new}',inputs(old=old,new=new)))
  for index in (-2147483648,-99,-2,-1,0,1,2,3,2147483647):cases.append(self.update_step(f'index-{index}',inputs(index=index),texts=(None,None)))
  for first in (None,b'bad\n',valid):
   for second in (None,b'bad\n',valid):
    for mode in ('missing','null','key','live'):
     cases.append(self.update_step(f'files-{len(first) if first is not None else -1}-{len(second) if second is not None else -1}-{mode}',inputs(),texts=(first,second),bitmaps=(mode,'live'),chunk=7))
  for first_mode in ('missing','null','key','live'):
   for second_mode in ('missing','null','key','live'):cases.append(self.update_step(f'bitmap-{first_mode}-{second_mode}',inputs(),texts=(valid,valid),bitmaps=(first_mode,second_mode)))
  for date in (b'\0',b'now\0',b'\x80\xff\0',b'x'*63+b'\0'):
   for capacity in (1,7,4096):cases.append(self.update_step(f'date-{date[:3].hex()}-{capacity}',inputs(old=4,new=4,date=date),capacity=capacity))
  for available,action,close in [(False,'full',0),(True,'error',0),(True,'short',-1),(True,'full',-1)]:
   for path in ('no-new','fallback','first','second'):
    cases.append(self.update_step(f'io-{available}-{action}-{close}-{path}',inputs(new=1 if path=='no-new' else 2),texts=(valid if path=='first' else None,valid if path=='second' else None),bitmaps=('live',),capacity=1,available=available,write_mode=action,fail_at=0 if action!='full' else -1,close=close))
  cases.append(self.update_step('unterminated-content',inputs(),texts=(b'',),force_scratch=True))
  return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=self.screen_parent,initialGlobals=self.update_initial,absentOriginalFiles=absent,
   sources=list(self.panel_sources.values()),cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True);pending=[]
  for suffix in ('','-control'):
   path=ROOT/'docs/evidence'/f'menu-panel-update{suffix}.json';report=json.loads(path.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'menu-panel-update{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-panel-update',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data));pending.append((path,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=MenuPanelUpdate(a.control).capture_update();suffix='-control' if a.control else ''
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'menu-panel-update{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),
  children={kind:sum(child['kind']==kind for c in doc['cases'] for child in c['children']) for kind in ENTRIES.values()},
  events=sum(len(c['events']) for c in doc['cases']),childEvents=sum(len(child['events']) for c in doc['cases'] for child in c['children']),nativeCompared=False)
 (ROOT/'docs/evidence'/f'menu-panel-update{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
