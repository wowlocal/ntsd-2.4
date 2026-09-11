#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Read-only verification of controlled original pool/UI surface evidence.
Verify every full blob/DIB and original instruction byte, merge operand reads
with prior actual/API writes and reconstruct all retained states/records/masks.
The declared allocator/outer/catalog/API inputs remain controlled boundaries;
no source execution, expected-state mutation or native/Windows coverage claim.
"""
import argparse,base64,bisect,hashlib,json,pathlib,struct,sys,time,zlib
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256
from oracle_crt import DLL_SHA256,prepare
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source',type=pathlib.Path);parser.add_argument('--output',type=pathlib.Path,required=True);args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];path=args.source;start=time.monotonic()
d=json.loads(path.read_text());assert d['exeSHA256']==EXE_SHA256 and d['crtSHA256']==DLL_SHA256
blobs={}
for key,v in d['blobs'].items():
 raw=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(raw)==v['count'] and hashlib.sha256(raw).hexdigest()==key==v['sha256'];blobs[key]=raw
exe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());crt=PE(prepare().read_bytes());assert hashlib.sha256(exe.data).hexdigest()==EXE_SHA256 and hashlib.sha256(crt.data).hexdigest()==DLL_SHA256
resources={str(r['path'][1]):exe.data[r['fileOffset']:r['fileOffset']+r['size']] for r in exe.resources() if r['path'][0]==2}
for name,a in d['assets'].items():
 raw=blobs[a['raw']];assert a['kind']=='embedded' and raw==resources[name]
 width,height=struct.unpack_from('<ii',raw,4);planes,bpp=struct.unpack_from('<HH',raw,12)
 assert [a[k] for k in ('width','height','planes','bpp')]==[width,abs(height),planes,bpp]
def code_bytes(pc,count):
 pe,base=(crt,0x78130000) if pc>=0x78130000 else (exe,0x400000)
 rva=pc-base
 for s in pe.sections:
  if s['rva']<=rva<rva+count<=s['rva']+s['fileSize']:
   offset=s['fileOffset']+rva-s['rva'];return pe.data[offset:offset+count]
 raise AssertionError(hex(pc))
reports=[];allpcs=set()
for c in d['cases']:
 assert c['end']=='interfaceBoundary' and c['after']['pc']==0x41c581 and c['after']['sp']==0x1000f000
 assert c['initial']['cw']==c['beforePool']['cw']==c['beforeInterface']['cw']==c['after']['cw']==0
 assert c['constructorSlots']==list(range(400))+list(range(8));assert len(c['allocations'])==10 and len(c['checkpoints'])==10
 for k,v in c['instructions'].items():
  pc=int(k,16);raw=bytes.fromhex(v);assert code_bytes(pc,len(raw))==raw,(k,v);allpcs.add(pc)
 records=sorted(c['records'],key=lambda r:r['address']);addresses=[r['address'] for r in records]
 state={r['address']:bytearray(blobs[r['initial']]) for r in records};masks={r['address']:bytearray(r['count']) for r in records}
 live={c['worldAddress']:0}
 for index,e in enumerate(c['events']):
  if e.get('kind') in ('allocateActor','allocate') and e['address']:
   assert e['address'] not in live;live[e['address']]=index+1
 global_base,stack_base=0x44d000,0x1000d000
 globals_=bytearray(blobs[c['initial']['globals']]);stack=bytearray(blobs[c['initial']['stack']]);known=bytearray(blobs[c['initial']['knownStack']])
 points={}
 def add_point(index,label,snapshot):points.setdefault(index,[]).append((label,snapshot))
 selector=next(e for e in c['events'] if e.get('kind')=='declaredSelector')
 add_point(selector['storeCount']+2,'beforePool',c['beforePool'])
 ui=[i for i,w in enumerate(c['writes']) if w['pc']==0x41c2f5];assert len(ui)==1;add_point(ui[0],'beforeInterface',c['beforeInterface'])
 for cp in c['checkpoints']:add_point(cp['storeCount'],'global'+str(cp['index']),cp)
 add_point(len(c['writes']),'after',c['after'])
 for index,e in enumerate(c['events']):
  if 'request' in e:add_point(e['storeCount'],e['key'],e)
 reads={}
 for q in c['reads']:reads.setdefault(q['storeCount'],[]).append(q)
 def record_at(p,n):
  i=bisect.bisect_right(addresses,p)-1
  if i>=0 and p+n<=addresses[i]+len(state[addresses[i]]):return addresses[i]
 checked=0;read_bytes=0
 for index in range(len(c['writes'])+1):
  for label,snap in points.get(index,[]):
   assert globals_==blobs[snap['globals']],(c['spec']['label'],label,'globals')
   if 'stack' in snap:assert stack==blobs[snap['stack']] and known==blobs[snap['knownStack']],(c['spec']['label'],label,'stack')
   checked+=1
  for q in reads.get(index,[]):
   p,n=q['address'],q['count'];expected=bytes.fromhex(q['bytes'])
   if stack_base<=p<p+n<=stack_base+len(stack):actual=stack[p-stack_base:p-stack_base+n];mask=known[p-stack_base:p-stack_base+n]
   elif p==c['catalogAddress'] and n==4:actual=struct.pack('<I',c['objectAddress']);mask=b'\1'*4
   elif p==c['objectAddress']+0x90 and n==4:actual=struct.pack('<I',c['firstObjectWord90']);mask=b'\1'*4
   else:
    address=record_at(p,n);assert address is not None and live[address]<=q['eventIndex'];offset=p-address;actual=state[address][offset:offset+n];mask=masks[address][offset:offset+n]
   assert actual==expected and list(mask)==q['known'],(c['spec']['label'],index,q)
   read_bytes+=n
  if index==len(c['writes']):break
  w=c['writes'][index];p=w['address'];raw=bytes.fromhex(w['bytes']);n=len(raw)
  if global_base<=p<p+n<=global_base+len(globals_):globals_[p-global_base:p-global_base+n]=raw
  if stack_base<=p<p+n<=stack_base+len(stack):stack[p-stack_base:p-stack_base+n]=raw;known[p-stack_base:p-stack_base+n]=b'\1'*n
  address=record_at(p,n)
  if address is not None:
   assert live[address]<=w['eventIndex'];offset=p-address;state[address][offset:offset+n]=raw;masks[address][offset:offset+n]=b'\1'*n
 for r in records:
  assert state[r['address']]==blobs[r['bytes']] and masks[r['address']]==blobs[r['mask']],(c['spec']['label'],r['kind'],hex(r['address']))
 assert struct.unpack_from('<I',globals_,0x44d05c-global_base)[0]==0
 for h in c['helpers']:
  assert h['returnSP']==h['sp']+4+h['pop']
  if h['kind'] in ('constructor','world'):assert h['result']==h['wrapper']
  if h['kind']=='actor':assert h['result']==0xfffffc18
 reports.append(dict(label=c['spec']['label'],records=len(records),recordBytes=sum(r['count'] for r in records),states=checked,writes=len(c['writes']),writeBytes=sum(len(w['bytes'])//2 for w in c['writes']),reads=len(c['reads']),readBytes=read_bytes,undefinedReadBytes=sum(q['known'].count(0) for q in c['reads']),helpers=len(c['helpers']),events=len(c['events']),originalPCs=len(c['instructions'])))
report=dict(scope=__doc__,source=path.name,sourceSHA256=hashlib.sha256(path.read_bytes()).hexdigest(),sourceBytes=path.stat().st_size,blobs=len(blobs),assets=len(d['assets']),cases=reports,originalPCs=len(allpcs),elapsedSeconds=round(time.monotonic()-start,3))
out=args.output;assert not out.exists();out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
