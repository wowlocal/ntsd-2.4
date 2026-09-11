#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""INCOMPLETE own catalog join from actual4450ac after common sound loading.
Guarded allocation revision: reserve both32-byte research red zones around
ordinary WAV temporary/lock buffers. The prior candidate1 failed a harness
sentinel assertion for SNDDATA_2144.wav because its20440-byte temporary's trailing
red zone overlapped24 bytes of the next leading red zone. Preserve the original
error, complete prior checkpoints and every guard assertion. This separate
fresh capture changes only that declared allocation geometry; it is not a
retry for silence, source-fault bypass or a native/Windows success claim.

Pinned NTSD/lib/VC80 and original assets, Unicorn2.1.4. Preserve the application
CPU/stack/CRT/resources; execute normal SEH/cookie, catalog and real bitmap/CRT
children. New disjoint allocation/FILE backing and GDI/COM/_read responses are
declared research boundaries. Stop unknown children at actual entry, without
fabricating a return, importing expected/private native storage, corrupting
control/protective structures, bypassing safeguards or continuing after faults.
No Windows/device/full-catalog/native-success claim. APPLICATION_CATALOG_PLAN.md.
"""
import argparse,bisect,copy,json,os,shutil,struct,time,zlib,traceback
from pathlib import Path
from collections import Counter
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import *
from oracle_application_loading_prefix import ApplicationLoadingPrefix,specs as prefix_specs
from oracle_application_menu_input import MSG
from oracle_application_screen_body import ApplicationScreenBody,HELPERS as DRAW_HELPERS,BODY_API,LIB
from oracle_bitmap_surface_loading import BitmapSurface,TRACE_STACK,TRACE_SIZE,REGS
from oracle_application_dispatch_entry import BASE,FULL_SIZE,STACK
from oracle_application_settings import key
from oracle_settings_loading import OPEN,CLOSE,SCAN,GETS,EOF
from oracle_menu_info_writing import FPRINT,FCLOSE,WRITE,CLOSE as CLOSE_FILE,ISATTY,GETPTD
from oracle_menu_sound_startup import MenuSoundStartup
from oracle_wave_loader import WaveLoader,platform,data_size,VTABLE
from oracle_crt import CRT,PTD,STOP,DLL_SHA256
from oracle_lib_initialization import LIB_SHA256
from oracle_bitmap_drawing import digest,signed
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
CATALOG,SIZE=0x70000020,0x4d823a8
WRAPPERS,FILE_BASE=0x50000020,0x54000000
OBJECT_BASE=0x48000020
FRAME_BASE=0x42000020
VOLUME_API=STOP+0xe040
MIRROR_API=STOP+0xe050
MALLOC_API=STOP+0xe060
FREE_API=STOP+0xe070

class TraceLog:
 """Lossless ordered JSON-array parts; only transport compression, no sampling."""
 def __init__(self,folder,label,limit=50000):
  self.folder=folder;self.label=label;self.limit=limit;self.rows=[];self.parts=[];self.count=0
 def __len__(self):return self.count
 def append(self,row):
  self.rows.append(row);self.count+=1
  if len(self.rows)>=self.limit:self.flush()
 def flush(self):
  if not self.rows:return
  raw=(json.dumps(self.rows,separators=(',',':'))+'\n').encode();packed=zlib.compress(raw,6);name=f'{self.label}-{len(self.parts):06d}.json.zlib';p=self.folder/name
  with p.with_suffix('.tmp').open('xb') as f:f.write(packed)
  os.replace(p.with_suffix('.tmp'),p)
  self.parts.append(dict(path=name,first=self.count-len(self.rows),count=len(self.rows),rawBytes=len(raw),rawSHA256=digest(raw),packedBytes=len(packed),packedSHA256=digest(packed)));self.rows=[]
  index=self.folder/(self.label+'-index.json');temp=index.with_suffix('.tmp');temp.write_text(json.dumps(self.manifest(),separators=(',',':'))+'\n');os.replace(temp,index)
 def manifest(self):return dict(encoding='ordered-json-array-zlib-parts-v1',directory=self.folder.name,count=self.count,parts=self.parts)
 def export(self):self.flush();return self.manifest()
 def __getitem__(self,key):
  if not isinstance(key,slice):
   i=key+self.count if key<0 else key;assert 0<=i<self.count;return self[i:i+1][0]
  lo,hi,step=key.indices(self.count);assert step==1;out=[]
  for p in self.parts:
   if p['first']+p['count']<=lo or p['first']>=hi:continue
   packed=(self.folder/p['path']).read_bytes();assert digest(packed)==p['packedSHA256'];raw=zlib.decompress(packed);assert digest(raw)==p['rawSHA256'];rows=json.loads(raw);out.extend(rows[max(0,lo-p['first']):min(p['count'],hi-p['first'])])
  first=self.count-len(self.rows);out.extend(self.rows[max(0,lo-first):max(0,hi-first)]);return out

def trace_json(value):
 if isinstance(value,TraceLog):return value.export()
 raise TypeError(type(value).__name__)

class ApplicationCatalog(ApplicationLoadingPrefix):
 def __init__(self):
  self.catalog_active=False;super().__init__();self.uc.hook_add(UC_HOOK_MEM_READ,self.catalog_read)
 def refresh_region_index(self):
  if getattr(self,'region_index_count',-1)==len(self.regions):return
  self.region_index=sorted(self.regions,key=lambda r:r['address']);self.region_addresses=[r['address'] for r in self.region_index]
  assert all(a['address']+a['count']<=b['address'] for a,b in zip(self.region_index,self.region_index[1:]))
  self.region_index_count=len(self.regions)
 def record(self,p,b,pc):
  if not self.catalog_active:return super().record(p,b,pc)
  self.writes.append(dict(pc=pc,address=p,bytes=bytes(b).hex(),eventIndex=len(self.events)))
  self.refresh_region_index();i=bisect.bisect_right(self.region_addresses,p)-1
  if i>=0:
   r=self.region_index[i]
   if r['address']<=p<p+len(b)<=r['address']+r['count']:
    r['mask'][p-r['address']:p-r['address']+len(b)]=b'\1'*len(b);self.dirty_records.add(r['address'])
 def state(self):
  if getattr(self,'record_tables',None) is None:return super().state()
  s=self.menu_state();updates=[]
  for r in self.regions:
   p=r['address'];prior=self.record_cache.get(p);live=p not in self.freed
   if prior is None or p in self.dirty_records:
    current=dict(address=p,live=live,bytes=self.blob(self.uc.mem_read(p,r['count'])),mask=self.blob(r['mask']))
   else:current={**prior,'live':live}
   if current!=prior:updates.append(current);self.record_cache[p]=current
  self.dirty_records.clear()
  if updates or self.record_snapshot is None:
   index=len(self.record_tables);self.record_tables.append(dict(index=index,previous=self.record_snapshot,count=len(self.regions),updates=updates));self.record_snapshot=index
  s.update(message=self.blob(self.uc.mem_read(MSG,28)),messageMask=self.blob(self.msg_mask),random=self.random_state,records=dict(encoding='addressed-record-table-delta-v1',snapshot=self.record_snapshot))
  return s
 def asset(self,path):
  if self.catalog_active and path not in self.assets:
   key=''.join(chr(ord(c)-32) if 'a'<=c<='z' else c for c in path)
   if key in self.resources:
    r=self.resources[key];raw=self.pe.data[r['fileOffset']:r['fileOffset']+r['size']];width,height=struct.unpack_from('<ii',raw,4);planes,bpp=struct.unpack_from('<HH',raw,12)
    self.assets[path]=dict(path=path,kind='embedded',raw=self.blob(raw),width=width,height=abs(height),planes=planes,bpp=bpp,resourceName=key)
  return super().asset(path)
 def object(self,address):
  super().object(address)
  if self.catalog_active:
   at=address+0x100+0x14;before=self.u32(at);self.uc.mem_write(at,struct.pack('<I',MIRROR_API));self.catalog_bindings.append(dict(address=at,before=before,after=MIRROR_API))
 def boundary(self,u,pc,n,data):
  if not self.catalog_active:return super().boundary(u,pc,n,data)
  if pc in (OPEN,CLOSE):return
  if self.boundaries.get(pc)=='_read':
   sp=u.reg_read(UC_X86_REG_ESP);fd,dst,count=[self.u32(sp+i) for i in (4,8,12)]
   h=next((h for h in self.file_handles.values() if h['buffer']==dst),None)
   assert h is not None and fd==0xffffffff and not h['closed']
   raw=h['data'][h['read']:h['read']+min(count,4096)];h['read']+=len(raw)
   self.catalog_event('readFile',[fd,dst,count,len(raw)],bytes=raw.hex());self.resource_output(dst,raw);self.ret(len(raw));return
  if pc in self.boundaries:return CRT.boundary(self,u,pc,n,data)
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if not self.catalog_active:return
  pc=u.reg_read(UC_X86_REG_EIP);raw=(v&((1<<(8*n))-1)).to_bytes(n,'little');self.record(p,raw,pc)
  if BASE<=p<p+n<=BASE+FULL_SIZE:self.front_mask[p-BASE:p-BASE+n]=b'\1'*n
  if CATALOG<=p<p+n<=CATALOG+SIZE:self.catalog_mask[p-CATALOG:p-CATALOG+n]=b'\1'*n
  if self.wave.current is not None and STACK<=p<p+n<=STACK+0x10000:self.wave.stack_written(u,access,p,n,v,data)
 def catalog_read(self,u,access,p,n,v,data):
  if not self.catalog_active:return
  pc=u.reg_read(UC_X86_REG_EIP)
  if self.current_bitmap is not None and 0x43f010<=pc<=0x43f2fe and self.current_bitmap<=p<p+n<=self.current_bitmap+0x1f50:
   assert n==4;r=next(r for r in self.regions if r['address']==self.current_bitmap);o=p-r['address'];self.front_event('read',read=dict(offset=o,value=self.u32(p),defined=all(r['mask'][o:o+n])))
  if TRACE_STACK<=p<p+n<=TRACE_STACK+TRACE_SIZE:
   self.catalog_reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,count=n,bytes=bytes(u.mem_read(p,n)).hex(),known=list(self.stack_known[p-STACK:p-STACK+n]),storeCount=len(self.writes)))
  if CATALOG<=p<p+n<=CATALOG+SIZE:
   self.catalog_accesses.append(dict(pc=u.reg_read(UC_X86_REG_EIP),offset=p-CATALOG,count=n,bytes=bytes(u.mem_read(p,n)).hex(),defined=list(self.catalog_mask[p-CATALOG:p-CATALOG+n]),storeCount=len(self.writes)))
 def catalog_event(self,kind,arguments=(),**kw):
  e=dict(kind=kind,arguments=list(arguments),pc=self.uc.reg_read(UC_X86_REG_EIP),globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)),storeCount=len(self.writes),**kw);self.events.append(e);return e
 def file_position(self,h):return h['read']-self.u32(h['address']+4)
 def begin_catalog_wave(self,sp):
  w=self.wave;index=self.u32(0x458438);dst=self.uc.reg_read(UC_X86_REG_ECX);assert dst==0x452948+index*4 and self.u32(sp) in (0x40be1d,0x410a4d)
  w.path=self.cstr(self.u32(sp+4));f=DEFAULT_SOURCE/w.path.decode('latin1').replace('\\','/');assert f.resolve().is_relative_to(DEFAULT_SOURCE.resolve());w.raw=f.read_bytes();count=data_size(w.raw)
  w.p=platform(w.raw,1000+len(w.loads),destination=dst,device=self.u32(0x44eecc));w.wave_entry_sp=sp
  def storage(n):
   p=self.wave_next;size=(max(n,1)+64+4095)&~4095;self.uc.mem_map(p,size);self.wave_next+=size;assert self.wave_next<0xc0000000;return p+32
  w.allocation=storage(count);w.p['firstPointer']=storage(w.p['firstCount'])
  if w.p['secondPointer']:w.p['secondPointer']=storage(w.p['secondCount'])
  w.put(w.p['buffer'],VTABLE);w.current=dict(label=w.path.decode('latin1'),path=list(w.path),file=self.blob(w.raw),input=w.p,entrySP=sp,returnPC=self.u32(sp),saved=[self.uc.reg_read(r) for r in REGS],outputBefore=self.u32(dst),beforeGlobals=w.state(),registryIndex=index)
  w.regions={};w.events=[];w.device_format=w.descriptor=None;w.descents=w.reads=w.locks=0;w.stack_mask=bytearray(0x10000)
  w.region('first',w.p['firstPointer'],w.p['firstCount'])
  if w.p['secondPointer']:w.region('second',w.p['secondPointer'],w.p['secondCount'])
  self.wave_event('load',[dst],[w.path])
 def code(self,u,pc,n,data):
  if not self.catalog_active:return super().code(u,pc,n,data)
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  if self.wave.current is not None and pc==self.wave.current['returnPC']:
   q=self.wave.current;assert sp==q['entrySP']+8 and [u.reg_read(r) for r in REGS]==q['saved'];self.wave.finish_wave('returned',u.reg_read(UC_X86_REG_EAX))
  if pc==0x4014e0:self.begin_catalog_wave(sp)
  if self.wave.current is not None:
   if pc in self.wave.imports:return WaveLoader.imported(self.wave,u,pc,n,data)
   if pc in (0x4450ac,0x4450a6,0x4450c2):return self.wave.crt(u,pc,n,data)
   assert 0x4014e0<=pc<=0x40195e or 0x4450b2<=pc<=0x4450ba or pc==0x43f384,hex(pc);self.original(u,pc,n);return
  if pc==VOLUME_API:
   q=self.wave.loads[-1];assert [arg(0),arg(1)]==[q['outputAfter'],0xffffd8f0] and self.u32(0x458438)==q['registryIndex'];self.catalog_event('registeredVolume',[arg(0),arg(1)],result=-1);q['volume']=[arg(0),arg(1)];self.ret(-1,8);return
  if pc==MIRROR_API:
   assert arg(0) in self.surfaces and arg(2) in self.surfaces and arg(4)==0x1000800
   effects=bytes(u.mem_read(arg(5),100));assert struct.unpack_from('<I',effects)[0]==100
   self.catalog_event('mirrorBlt',[arg(i) for i in range(6)],destination=None if arg(1)==0 else bytes(u.mem_read(arg(1),16)).hex(),source=None if arg(3)==0 else bytes(u.mem_read(arg(3),16)).hex(),effects=effects.hex(),effectsKnown=list(self.stack_known[arg(5)-STACK:arg(5)-STACK+100]),result=0);self.ret(0,24);return
  if pc==FREE_API:
   token=arg(0);assert self.u32(sp)==0x40c125 and token in {r['address'] for r in self.new_bitmaps} and token not in self.freed
   assert self.surfaces[self.u32(token)]['released'];self.catalog_event('freeBitmap',[token]);self.freed.add(token);self.ret();return
  while self.body_helpers and pc==self.body_helpers[-1]['returnPC']:
   h=self.body_helpers.pop();assert sp==h['sp']+4+h['pop'] and [u.reg_read(r) for r in REGS]==h['saved'];h.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.body_returns.append(h)
   if h['entry']==0x43f010:self.current_bitmap=None
  if self.clip_pending and pc==self.clip_pending['returnPC']:
   q=self.clip_pending;self.clip_pending=None;self.front_event('clip',clip=dict(beforeSource=q['source'],beforeDestination=q['destination'],source=[signed(self.u32(p)) for p in q['sourcePointers']],destination=[signed(self.u32(p)) for p in q['destinationPointers']],visible=u.reg_read(UC_X86_REG_EAX)==1))
  if self.scan_pending and pc==self.scan_pending['returnPC']:
   q=self.scan_pending;self.scan_pending=None;assert sp==q['entrySP']+4 and [u.reg_read(r) for r in REGS]==q['saved'];h=self.file_handles[q['file']]
   q.update(result=u.reg_read(UC_X86_REG_EAX),position=self.file_position(h),eof=bool(self.u32(h['address']+12)&16),returnSP=sp,eventEnd=len(self.events),storeEnd=len(self.writes));self.scan_returns.append(q)
   if q['kind']=='scan':
    self.scan_count+=1
    if self.scan_limit is not None and self.scan_count>=self.scan_limit:
     self.dependency=dict(kind='probeScanLimit',pc=pc,count=self.scan_count,file=h['path']);u.emu_stop();return
  if self.output_pending and pc==self.output_pending['returnPC']:
   q=self.output_pending;self.output_pending=None;assert sp==q['entrySP']+4 and [u.reg_read(r) for r in REGS]==q['saved'];h=self.file_handles[q['file']]
   q.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),storeEnd=len(self.writes),fileState=bytes(u.mem_read(h['address'],32)).hex());self.output_returns.append(q)
   if q['kind']=='close':h['closed']=True;h['raw']=self.blob(self.virtual_files[h['path']]);h['logical']=self.blob(h['output'])
  if self.decoder_pending and pc==self.decoder_pending['returnPC']:
   q=self.decoder_pending;self.decoder_pending=None;assert sp==q['sp']+4 and [u.reg_read(r) for r in REGS]==q['saved'];q.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),eventEnd=len(self.events),storeEnd=len(self.writes));self.decoder_returns.append(q)
   if self.decoder_limit is not None and len(self.decoder_returns)>=self.decoder_limit:self.dependency=dict(kind='probeDecoderLimit',pc=pc,count=len(self.decoder_returns));u.emu_stop();return
  if self.object_pending and pc==self.object_pending['returnPC']:
   q=self.object_pending;self.object_pending=None;assert sp==q['sp']+20 and [u.reg_read(r) for r in REGS]==q['saved'] and u.reg_read(UC_X86_REG_EAX)==q['address'];q.update(returnSP=sp,eventEnd=len(self.events),storeEnd=len(self.writes),after=self.state());self.object_returns.append(q)
   if self.object_limit is not None and len(self.object_returns)>=self.object_limit:self.dependency=dict(kind='probeObjectLimit',pc=pc,count=len(self.object_returns));u.emu_stop();return
   if self.checkpoint_every and (len(self.object_returns)==1 or len(self.object_returns)%self.checkpoint_every==0):self.save_catalog_checkpoint()
  if self.catalog_child_pending and pc==self.catalog_child_pending['returnPC']:
   q=self.catalog_child_pending;self.catalog_child_pending=None
   assert sp==q['sp']+4+q['pop'] and [u.reg_read(r) for r in REGS]==q['saved']
   q.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),eventEnd=len(self.events),storeEnd=len(self.writes),after=self.state());self.catalog_child_returns.append(q)
  if self.progress_pending and pc==self.progress_pending['returnPC']:
   q=self.progress_pending;self.progress_pending=None;assert sp==q['sp']+4 and [u.reg_read(r) for r in REGS]==q['saved'];q.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),eventEnd=len(self.events),after=self.state());self.progress_returns.append(q)
  if self.helpers and pc==self.helpers[-1]['returnPC'] and sp==self.helpers[-1]['sp']+4+self.helpers[-1]['pop']:
   h=self.helpers.pop();assert [u.reg_read(r) for r in REGS]==h['saved'];h.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.returns_resource.append(h)
  if pc==0x4450ac:
   count=arg(0);caller=self.u32(sp)
   if caller==0x41bff5:
    assert count==SIZE and self.catalog_allocation is None
    self.uc.mem_map(CATALOG&~4095,(SIZE+0x40+4095)&~4095);initial=b'\xa5'*SIZE;self.uc.mem_write(CATALOG,initial);self.catalog_allocation=dict(address=CATALOG,count=SIZE,initial=self.blob(initial),caller=caller)
    self.catalog_event('allocateCatalog',[count,CATALOG]);self.ret(CATALOG);return
   if count==0x1f50:
    token=WRAPPERS+0x2000*len(self.new_bitmaps);backing=b'\xa5'*count;self.uc.mem_write(token,backing);self.regions.append(dict(address=token,count=count,mask=bytearray(count)));a=dict(address=token,count=count,initial=self.blob(backing),caller=caller);self.new_bitmaps.append(a);self.catalog_event('allocateBitmap',[count,token]);self.ret(token);return
   if count==0x25360 and caller==0x41266a:
    token=OBJECT_BASE+0x40000*len(self.objects);backing=b'\xa5'*count;self.uc.mem_write(token,backing);self.regions.append(dict(address=token,count=count,mask=bytearray(count)));self.objects.append(dict(address=token,count=count,initial=self.blob(backing),caller=caller));self.catalog_event('allocateObject',[count,token]);self.ret(token);return
   self.dependency=dict(kind='allocation',pc=pc,count=count,caller=caller);u.emu_stop();return
  if pc==self.catalog_malloc:
   count=arg(0);caller=self.u32(sp)
   if not (0x40ef70<=caller<=0x4122ec and 0<count<=0x1f50):self.dependency=dict(kind='malloc',pc=pc,count=count,caller=caller);u.emu_stop();return
   token=self.frame_next;self.frame_next+=((count+15)&~15)+32;assert self.frame_next<FRAME_BASE+0x2000000;backing=b'\xa5'*count;u.mem_write(token,backing);self.regions.append(dict(address=token,count=count,mask=bytearray(count)));self.frame_allocations.append(dict(address=token,count=count,initial=self.blob(backing),caller=caller));self.catalog_event('allocateFrame',[count,token]);self.ret(token);return
  if pc==0x4122f0:
   assert u.reg_read(UC_X86_REG_ECX)==CATALOG;self.catalog_entry=dict(sp=sp,returnPC=self.u32(sp),arguments=[arg(0),arg(1)],fileName=self.cstr(arg(0)).decode(),saved=[u.reg_read(r) for r in REGS]);self.catalog_event('catalogEntry',[CATALOG,arg(0),arg(1)])
  if pc==0x41c018:
   assert self.catalog_entry and sp==self.catalog_entry['sp']+12 and [u.reg_read(r) for r in REGS]==self.catalog_entry['saved'] and u.reg_read(UC_X86_REG_EAX)==CATALOG;self.catalog_end='returned';u.emu_stop();return
  if pc==self.catalog_timer:
   value=self.clock_next;self.clock_next+=20;self.catalog_event('time',[value]);self.ret(value);return
  if self.loop_imports.get(pc)=='sleep':self.catalog_event('sleep',[arg(0)]);self.ret(0,4);return
  if pc==0x4242e0:
   assert self.progress_pending is None;self.progress_pending=dict(sp=sp,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGS],arguments=[arg(0),arg(1)],eventStart=len(self.events),before=self.state())
  if pc in (0x4148a0,0x414a30):
   assert self.decoder_pending is None;self.decoder_pending=dict(sp=sp,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGS],path=self.cstr(arg(0)).decode('latin1'),eventStart=len(self.events),storeStart=len(self.writes))
   if pc==0x414a30:self.decoder_pending['outputPath']=self.cstr(arg(1)).decode('latin1')
  if pc==0x40ef70:
   assert self.object_pending is None;self.object_pending=dict(sp=sp,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGS],address=u.reg_read(UC_X86_REG_ECX),arguments=[arg(i) for i in range(4)],eventStart=len(self.events),storeStart=len(self.writes))
  if pc in (0x40c160,0x40c910):
   assert self.catalog_child_pending is None and u.reg_read(UC_X86_REG_ECX)==CATALOG
   self.catalog_child_pending=dict(kind='background' if pc==0x40c160 else 'stages',sp=sp,returnPC=self.u32(sp),pop=12 if pc==0x40c160 else 0,saved=[u.reg_read(r) for r in REGS],arguments=[arg(i) for i in range(3)] if pc==0x40c160 else [],eventStart=len(self.events),storeStart=len(self.writes))
  if pc==OPEN:
   path=self.cstr(arg(0)).decode('latin1');mode=self.cstr(arg(1)).decode('latin1')
   assert mode in ('r','w'),(path,mode)
   f=DEFAULT_SOURCE/path.replace('\\','/');assert f.resolve().is_relative_to(DEFAULT_SOURCE.resolve())
   if mode=='r':raw=bytes(self.virtual_files[path]) if path in self.virtual_files else f.read_bytes()
   else:raw=b'';self.virtual_files[path]=bytearray()
   logical=raw.split(b'\x1a',1)[0].replace(b'\r\n',b'\n');token=FILE_BASE+0x20000*len(self.file_handles);buffer=token+0x1000
   h=dict(address=token,buffer=buffer,path=path,mode=mode,raw=self.blob(raw),logical=self.blob(logical),data=logical,read=0,closed=False);self.file_handles[token]=h
   initial=b'\xa5'*0x11000;u.mem_write(token,initial);self.regions.append(dict(address=token,count=len(initial),mask=bytearray(len(initial))));h['initial']=self.blob(initial)
   if mode=='w':h['output']=bytearray()
   self.catalog_event('openFile',[token],path=path,mode=mode);self.resource_output(token,struct.pack('<8I',buffer,0 if mode=='r' else 0x10000,buffer,9 if mode=='r' else 0x102,0xffffffff,0,0x10000,0));self.ret(token);return
  if pc==CLOSE:
   h=self.file_handles[arg(0)];assert not h['closed']
   if h['mode']=='w':u.reg_write(UC_X86_REG_EIP,FCLOSE);return
   h['closed']=True;self.catalog_event('closeReadFile',[arg(0)]);self.ret();return
  if pc==GETPTD:self.ret(PTD);return
  if pc==ISATTY:assert arg(0)==0xffffffff;self.ret(0);return
  if pc==WRITE:
   h=next((h for h in self.file_handles.values() if h['buffer']==arg(1)),None);assert h is not None and h['mode']=='w' and not h['closed'] and arg(0)==0xffffffff and 0<arg(2)<=0x10000
   raw=bytes(u.mem_read(arg(1),arg(2)));h['output'].extend(raw);self.virtual_files[h['path']].extend(raw.replace(b'\n',b'\r\n'));self.catalog_event('writeFile',[arg(0),arg(1),arg(2)],bytes=raw.hex());self.ret(arg(2));return
  if pc==CLOSE_FILE:
   assert arg(0)==0xffffffff and self.output_pending['kind']=='close';self.catalog_event('closeOutputDescriptor',[arg(0),self.output_pending['file']]);self.ret();return
  if pc in (FPRINT,FCLOSE):
   h=self.file_handles[arg(0)];assert not h['closed'] and h['mode']=='w' and self.output_pending is None
   q=dict(kind='print' if pc==FPRINT else 'close',file=arg(0),entrySP=sp,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGS],storeStart=len(self.writes),eventStart=len(self.events))
   if pc==FPRINT:q['format']=self.cstr(arg(1)).decode('latin1');q['argument']=arg(2)
   self.output_pending=q
  if pc in (SCAN,EOF):
   h=self.file_handles[arg(0)];assert not h['closed'] and self.scan_pending is None
   q=dict(kind='scan' if pc==SCAN else 'eof',file=arg(0),entrySP=sp,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGS],position=self.file_position(h),storeStart=len(self.writes),eventStart=len(self.events))
   if pc==SCAN:q['format']=self.cstr(arg(1)).decode('latin1')
   self.scan_pending=q
  if pc in (0x4028a0,0x43e940,0x43d230,0x415160):self.body_helpers.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),pop=0,firstStore=len(self.writes),eventStart=len(self.events),saved=[u.reg_read(r) for r in REGS]))
  if pc==0x415160:self.fill_start=len(self.writes);self.catalog_event('fillEntry',[arg(i) for i in range(5)],backing=self.blob(u.mem_read(sp-100,100)),known=self.blob(self.stack_known[sp-100-STACK:sp-STACK]))
  if self.window.com_methods.get(pc,('','',0))[1]=='blt':
   ret=self.u32(sp)
   if ret==0x4151bf:
    effects=self.frame(arg(5),100,self.fill_start);self.front_event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=effects['bytes'],defined=effects['defined']));self.ret(self.repeat_spec['drawResult'],24);return
   if ret==0x43e975:self.front_event('method',[arg(0),0x14,*[arg(i) for i in range(1,6)]],[bytes(u.mem_read(arg(1),16))]);self.ret(self.repeat_spec['presentResult'],24);return
  if self.loop_imports.get(pc)=='peek':
   assert [arg(i) for i in range(1,5)]==[0]*4;self.catalog_event('peekMessage',[arg(i) for i in range(5)],result=0);self.ret(0,20);return
  if pc in self.boundaries:return
  if pc in DRAW_HELPERS or pc in BODY_API or pc in self.library_api or LIB+0x1298<=pc<=LIB+0x1309 or pc in (LIB+0x1c7e,LIB+0x1c84,LIB+0x1c8a,LIB+0x1c90) or 0x43ef70<=pc<=0x43f2fe or self.window.com_methods.get(pc,('','',0))[1]=='blt':
   self.body_active=True
   try:return ApplicationScreenBody.code(self,u,pc,n,data)
   finally:self.body_active=False
  if pc in self.api or 0x43ed10<=pc<=0x43ef41 or 0x4013d0<=pc<=0x4014d1 or pc==0x4450a0 or 0x78130000<=pc<0x781c0000:
   self.resource_active=True
   try:return BitmapSurface.code(self,u,pc,n,data)
   finally:self.resource_active=False
  if any(a<=pc<=b for a,b in ((0x4122f0,0x4127fc),(0x41bff5,0x41c018),(0x4450b2,0x4450ba),(0x4242e0,0x4246ad),(0x40ef70,0x4122ec),(0x40bbf0,0x40c903),(0x40c910,0x40d09d),(0x4148a0,0x414b6f),(LIB+0x1236,LIB+0x1297),(0x4028a0,0x402a5f),(0x43e940,0x43e99e),(0x43d230,0x43d276),(0x415160,0x4151c2))):self.original(u,pc,n);return
  self.dependency=dict(kind='child',pc=pc,sp=sp,returnPC=self.u32(sp),ecx=u.reg_read(UC_X86_REG_ECX),arguments=[arg(i) for i in range(4)]);u.emu_stop()
 def capture_catalog(self,parents,prefix,index,before,crt):
  c=dict(parent=key(prefix),parentIndex=index,before=before,after=self.state(),crtBefore=crt,crtAfter=self.snapshot(),events=self.events,writes=self.writes,helpers=self.returns_resource,pendingHelpers=self.helpers,localReads=self.catalog_reads,catalogReads=self.catalog_accesses,catalog=self.catalog_allocation,catalogBytes=self.blob(self.uc.mem_read(CATALOG,SIZE)),catalogMask=self.blob(self.catalog_mask),bitmaps=self.new_bitmaps,objects=self.objects,progressReturns=self.progress_returns,decoders=self.decoder_returns,pendingDecoder=self.decoder_pending,entry=self.catalog_entry,scans=self.scan_returns,outputCalls=self.output_returns,pendingOutput=self.output_pending,files=[{k:v for k,v in h.items() if k not in ('data','output')} for h in self.file_handles.values()],virtualFiles={p:self.blob(b) for p,b in self.virtual_files.items()},dependency=self.dependency,end=self.catalog_end or 'dependency',instructions=self.call_pcs)
  c.update(stackStores=self.stack_stores,crtStores=self.stores,globalStores=self.global_stores,outputHelpers=self.body_returns,pendingOutputHelpers=self.body_helpers,mappings=[list(r) for r in self.uc.mem_regions()],frameAllocations=self.frame_allocations,objectReturns=self.object_returns,pendingObject=self.object_pending,registeredWaves=self.wave.loads,bindings=self.catalog_bindings)
  c.update(catalogChildReturns=self.catalog_child_returns,pendingCatalogChild=self.catalog_child_pending)
  if self.record_tables is not None:c['recordTables']=self.record_tables
  return parents,prefix,c
 def save_catalog_checkpoint(self):
  parents,prefix,index,before,crt=self.catalog_capture_args
  _,_,c=self.capture_catalog(parents,prefix,index,before,crt);c['end']='continuingCheckpoint'
  count=len(self.object_returns);target=self.capture_path.with_name(self.capture_path.stem+f'.object-{count:06d}.json');assert not target.exists()
  d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,libSHA256=LIB_SHA256,parents=parents,prefix=prefix,case=c,blobs=self.blobs,assets=self.assets,nativeCompared=False,windowsVerified=False,checkpoint=dict(completedObjects=count,sourceContinues=True))
  raw=(json.dumps(d,separators=(',',':'),default=trace_json)+'\n').encode();temp=target.with_suffix('.tmp')
  with temp.open('xb') as f:f.write(raw)
  os.replace(temp,target);print(dict(checkpoint=target.name,bytes=len(raw),sha256=digest(raw)),flush=True)
 def run_catalog(self,index):
  parents,prefix=super().run_loading(list(prefix_specs())[index]);parents=copy.deepcopy(parents);prefix=copy.deepcopy(prefix);assert prefix['end']=='catalogAllocation'
  # Only new disjoint storage; preserve all actual parent bindings and memory.
  self.uc.mem_map(WRAPPERS&~4095,0x1000000);self.uc.mem_map(FILE_BASE,0x8000000);self.uc.mem_map(0x32100000,0x500000);self.uc.mem_map(OBJECT_BASE&~4095,0x2400000);self.uc.mem_map(FRAME_BASE&~4095,0x2000000)
  self.events=[];self.writes=[];self.stack_stores=[];self.stores=[];self.global_stores=[];self.global_mask=bytearray(0xb440);self.front_mask=bytearray(FULL_SIZE);self.call_pcs={};self.local_mask=bytearray(0xc0);self.helpers=[];self.returns_resource=[];self.catalog_mask=bytearray(SIZE);self.catalog_reads=[];self.catalog_accesses=[];self.new_bitmaps=[];self.catalog_allocation=None;self.catalog_entry=None;self.dependency=None;self.catalog_end=None;self.scan_pending=None;self.scan_returns=[];self.file_handles={}
  self.clock_next=123457000;self.progress_pending=None;self.progress_returns=[];self.objects=[]
  self.virtual_files={};self.output_pending=None;self.output_returns=[];self.decoder_pending=None;self.decoder_returns=[];self.scan_count=0
  self.body_helpers=[];self.body_returns=[];self.current_bitmap=None;self.clip_pending=None
  self.frame_next=FRAME_BASE;self.frame_allocations=[];self.object_pending=None;self.object_returns=[];self.wave_next=0x80000000
  self.catalog_child_pending=None;self.catalog_child_returns=[]
  w=self.wave=MenuSoundStartup.__new__(MenuSoundStartup);w.uc=self.uc;w.blobs=self.blobs;w.blob=self.blob;w.put=self.put;w.ret=self.ret;w.imports=self.input.imports.copy();w.imports[self.u32(0x4471c8)]='message';w.running=True;w.prefix=False;w.regions={};w.loads=[];w.current=None;w.stack_mask=bytearray(0x10000);w.event=self.wave_event
  def output(p,raw):WaveLoader.host_write(w,p,raw);self.resource_output(p,raw)
  w.host_write=output
  self.catalog_bindings=[]
  for at,to in ((VTABLE+0x3c,VOLUME_API),(0x447194,MALLOC_API),(0x44717c,FREE_API)):
   self.catalog_bindings.append(dict(address=at,before=self.u32(at),after=to));self.put(at,to)
  self.catalog_malloc=self.u32(0x447194);self.catalog_timer=self.u32(0x447250)
  folder=self.capture_path.with_suffix('.traces');folder.mkdir()
  for field in ('writes','stack_stores','stores','global_stores','catalog_reads','catalog_accesses','scan_returns','output_returns'):setattr(self,field,TraceLog(folder,field))
  self.dirty_records=set();self.region_index_count=-1;self.record_cache={};self.record_snapshot=None;self.record_tables=TraceLog(folder,'record_tables',limit=200) if self.compact_states else None
  self.rs=dict(kind='catalog',results={});before=self.state();crt=self.snapshot();self.active=self.catalog_active=True;self.phase='applicationCatalog'
  self.catalog_capture_args=(parents,prefix,index,before,crt)
  try:
   start=0x4450ac;began=time.monotonic();chunks=0
   while self.dependency is None and self.catalog_end is None:
    self.uc.emu_start(start,0,count=1_000_000);start=self.uc.reg_read(UC_X86_REG_EIP);chunks+=1
    print(dict(chunks=chunks,pc=hex(start),scans=self.scan_count,decoders=len(self.decoder_returns),objects=len(self.object_returns),catalogChildren=len(self.catalog_child_returns),stores=len(self.writes),seconds=round(time.monotonic()-began,2)),flush=True)
    if self.dependency is None and self.catalog_end is None:
     if chunks>=self.max_chunks:self.dependency=dict(kind='researchInstructionLimit',pc=start,chunks=chunks)
     elif shutil.disk_usage(self.capture_path.parent).free<6*1024**3:self.dependency=dict(kind='researchStorageLimit',pc=start,reservedBytes=6*1024**3)
  except Exception as e:
   failure=dict(error=repr(e),errorText=str(e),traceback=traceback.format_exc(),parents=parents,prefix=prefix,before=before,state=self.state(),crtBefore=crt,crtAfter=self.snapshot(),events=self.events,traces={k:v for k,v in vars(self).items() if isinstance(v,TraceLog)},helpers=self.helpers,returnedHelpers=self.returns_resource,bodyHelpers=self.body_helpers,returnedOutputHelpers=self.body_returns,progressReturns=self.progress_returns,pendingProgress=self.progress_pending,decoderReturns=self.decoder_returns,pendingDecoder=self.decoder_pending,objectReturns=self.object_returns,pendingObject=self.object_pending,catalogChildReturns=self.catalog_child_returns,pendingCatalogChild=self.catalog_child_pending,pendingWave=self.wave.current,pendingScan=self.scan_pending,pendingOutput=self.output_pending,catalog=self.catalog_allocation,catalogBytes=self.blob(self.uc.mem_read(CATALOG,SIZE)),catalogMask=self.blob(self.catalog_mask),bitmaps=self.new_bitmaps,objects=self.objects,frameAllocations=self.frame_allocations,registeredWaves=self.wave.loads,files=[{k:v for k,v in h.items() if k not in ('data','output')} for h in self.file_handles.values()],virtualFiles={p:self.blob(b) for p,b in self.virtual_files.items()},bindings=self.catalog_bindings,mappings=[list(r) for r in self.uc.mem_regions()],instructions=self.call_pcs,blobs=self.blobs,assets=self.assets,nativeCompared=False)
   target=self.capture_path.with_suffix('.failure.json');temp=target.with_suffix('.tmp');temp.write_text(json.dumps(failure,separators=(',',':'),default=trace_json)+'\n');os.replace(temp,target);raise
  finally:self.active=self.catalog_active=False
  assert self.dependency is not None or self.catalog_end=='returned',hex(self.uc.reg_read(UC_X86_REG_EIP))
  assert self.u32(0x447194)==self.catalog_malloc and self.u32(0x447250)==self.catalog_timer
  for load in prefix['loads']:
   for r in load['storage']:assert self.blob(self.uc.mem_read(r['address'],self.blobs[r['bytes']]['count']))==r['bytes']
  return self.capture_catalog(parents,prefix,index,before,crt)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--parent-index',type=int,default=0);p.add_argument('--scan-limit',type=int);p.add_argument('--decoder-limit',type=int);p.add_argument('--object-limit',type=int);p.add_argument('--compact-states',action='store_true');p.add_argument('--max-chunks',type=int,default=1000);p.add_argument('--checkpoint-every',type=int,default=0);a=p.parse_args();assert not a.output.exists() and 0<a.max_chunks<=20000 and 0<=a.checkpoint_every<=137;vm=ApplicationCatalog();vm.capture_path=a.output;vm.scan_limit=a.scan_limit;vm.decoder_limit=a.decoder_limit;vm.object_limit=a.object_limit;vm.compact_states=a.compact_states;vm.max_chunks=a.max_chunks;vm.checkpoint_every=a.checkpoint_every;parents,prefix,c=vm.run_catalog(a.parent_index)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,libSHA256=LIB_SHA256,parents=parents,prefix=prefix,case=c,blobs=vm.blobs,assets=vm.assets,nativeCompared=False,windowsVerified=False);raw=(json.dumps(d,separators=(',',':'),default=trace_json)+'\n').encode();tmp=a.output.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,a.output);print(dict(end=c['end'],dependency=c['dependency'],bytes=len(raw),sha256=digest(raw)),flush=True)
