#!/usr/bin/env python3
"""Read-only verification of original bitmap loading/copy and own front evidence.
Pinned EXE/VC80/DIBs, recorded Unicorn execution, declared Win32/COM/allocation
outputs. Reconstruct all original globals, stack, output and wrapper bytes/masks;
verify own parent continuity and source instruction bytes. Opaque native stack
remains unknown; a rejected unknown read is not a successful source match.
No execution, memory mutation, Windows raster/device or full-game claim.
"""
import argparse,base64,hashlib,json,re,struct,subprocess,zlib
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack
BASE,FULL,STACK,SSIZE,OUT=0x44d000,0xc3a8,0x1000d000,0x2400,0x32000100

def digest(b):return hashlib.sha256(b).hexdigest()
def validate(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert len(d['cases'])==69 and raw.endswith(b'\n')
 assert path.with_name(path.stem+'-source.py').read_bytes()==(ROOT/'tools/oracle_bitmap_surface_loading.py').read_bytes()
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes();assert digest(exe)==d['exeSHA256']==EXE_SHA256 and digest(dll)==d['crtSHA256']
 pe,crt=PE(exe),PE(dll);image=bytearray(0x100000)
 for s in pe.sections:
  if s['name']!='.rsrc':image[s['rva']:s['rva']+s['fileSize']]=exe[s['fileOffset']:s['fileOffset']+s['fileSize']]
 initial=bytes(image[BASE-pe.base:BASE-pe.base+FULL]);blobs={}
 for h,v in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and digest(b)==h==v['sha256'];blobs[h]=b
 resources={r['path'][1]:r for r in pe.resources() if r['path'][0]==2}
 for pathName,a in d['assets'].items():
  rawAsset=blobs[a['raw']]
  if a['kind']=='embedded':
   r=resources[pathName];assert rawAsset==exe[r['fileOffset']:r['fileOffset']+r['size']];dib=rawAsset
  else:assert a['kind']=='file' and rawAsset==(DEFAULT_SOURCE/pathName.replace('\\','/')).read_bytes() and rawAsset[:2]==b'BM';dib=rawAsset[14:]
  assert struct.unpack_from('<i',dib,4)[0]==a['width'] and abs(struct.unpack_from('<i',dib,8)[0])==a['height']
  assert struct.unpack_from('<HH',dib,12)==(a['planes'],a['bpp'])
 assert len(d['assets'])==24
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';_,entry=unpack(fixtures/'original-application-dispatch-entry.json')
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==69
 counts=Counter();events=Counter();pcs={};outputMasks=[];sourceFields=Counter()
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i:04d}.json').read_bytes());assert part['case']==c and all(d['blobs'][h]==b for h,b in part['blobs'].items()) and all(d['assets'][k]==v for k,v in part['assets'].items())
  own=c['spec']['kind']=='own';counts[c['spec']['kind']]+=1;counts[c['end']]+=1;counts['terminalCodeHooks']+=c['terminalHookObserved']
  assert c['crtBefore']==c['crtAfter'] and c['before']['cw']==c['after']['cw']==(0x37f if own else 0) and c['before']['seh']==c['after']['seh']
  for a,h in c['instructions'].items():
   pc=int(a,16);b=bytes.fromhex(h);binary,p=(dll,crt) if pc>=0x78000000 else (exe,pe);off=p.offset(pc-p.base);assert binary[off:off+len(b)]==b,(i,a);pcs[a]=h
  assert '0x30000000' not in c['instructions'] and '0x427089' not in c['instructions']
  stack=bytearray(b'\xa5'*SSIZE);known=bytearray(SSIZE)
  def stackwrite(w):
   b=bytes.fromhex(w['bytes']);lo=max(STACK,w['address']);hi=min(STACK+SSIZE,w['address']+len(b))
   if lo<hi:stack[lo-STACK:hi-STACK]=b[lo-w['address']:hi-w['address']];known[lo-STACK:hi-STACK]=b'\1'*(hi-lo)
  if own:
   p,l,e=[c['parents'][k] for k in ('parent','loop','entry')]
   expected=entry['cases'][1 if c['spec'].get('windowParam')==1 else 0]
   assert e==expected and p==entry['parents'][e['parent']] and l==entry['loops'][e['loop']]
   off=0x1000f038-STACK;stack[off:off+20]=struct.pack('<5I',0x30000000,0x400000,0,0,10)
   for w in p['stackStores']+l['stackStores']+e['stackStores']:stackwrite(w)
   g=bytearray(blobs[e['after']['globals']]);assert c['before']['globals']==e['after']['globals'] and c['before']['sp']==0x1000ea6c
   assert c['before']['pc']==0x4450ac and c['after']['sp']==0x1000ea74
   assert c['after']['pc']==(0x427089 if c['end']=='settings' else 0x424ca4)
   assert c['nullSlot']==(0x4511a0 if c['end']=='nullBitmap' else None)
   records=p['panel']['records'];assert not records # Own parent has no bitmap generation.
  else:
   assert c['parents'] is None and blobs[c['before']['globals']]==initial
   g=bytearray(initial);s=c['spec'];off=0x1000f000-STACK
   if s['kind']=='loader':args=[0x32001000,s.get('flags',0x40),0x32000140 if s.get('format') else 0,OUT,OUT+4]
   else:args=[0x32001000 if s.get('surface',True) else 0,0x34000010 if s.get('bitmap',True) else 0,*s.get('copy',[0,0,0,0])]
   stack[off:off+4*(1+len(args))]=struct.pack('<'+'I'*(1+len(args)),0x30000000,*[a&0xffffffff for a in args])
   assert c['after']['pc']==0x30000000 and c['after']['sp']==0x1000f004
  assert stack==blobs[c['before']['stack']] and known==blobs[c['before']['knownStack']],('before stack',i)
  output=bytearray(blobs[c['before']['output']]);assert output==(bytes(8) if own else b'\x5a'*8);om=bytearray(8)
  bitmapRecords={a['address']:(bytearray(blobs[a['backing']]),bytearray(0x1f50)) for a in c['allocations'] if a['address']}
  gm=bytearray(FULL);wi=0
  def write(w):
   b=bytes.fromhex(w['bytes']);p=w['address'];stackwrite(w)
   if BASE<=p<p+len(b)<=BASE+FULL:g[p-BASE:p-BASE+len(b)]=b;gm[p-BASE:p-BASE+len(b)]=b'\1'*len(b)
   elif OUT<=p<p+len(b)<=OUT+8:output[p-OUT:p-OUT+len(b)]=b;om[p-OUT:p-OUT+len(b)]=b'\1'*len(b)
   else:
    for a,(data,mask) in bitmapRecords.items():
     if a<=p<p+len(b)<=a+len(data):data[p-a:p-a+len(b)]=b;mask[p-a:p-a+len(b)]=b'\1'*len(b);break
    else:assert STACK<=p<p+len(b)<=STACK+SSIZE,('unexpected source write',i,w)
   if w['pc'] is not None:assert hex(w['pc']) in c['instructions'];counts['CPUStores']+=1
   else:counts['APIOutputs']+=1
  for ei,e in enumerate(c['events']):
   while wi<e['storeCount']:write(c['writes'][wi]);wi+=1
   if 'request' not in e:
    assert e['kind']=='allocate' and e['count']==0x1f50 and e['address']==c['allocations'][e['index']]['address'];counts['allocationRequests']+=1;continue
   assert blobs[e['globals']]==g;name=e['request']['kind'];events[name]+=1;q=e['request'];response=e['response']
   if 'bytes' in q:
    if name=='getObject':kind,delta=('loader',24) if e['returnPC']==0x43ed6b else ('copy',132)
    elif name=='createSurface':kind,delta='loader',132
    else:assert name=='description';kind,delta='copy',108
    h=next(h for h in c['helpers'] if h['kind']==kind and h['eventStart']<=ei<h['eventEnd']);a=h['sp']-delta;n=len(q['bytes']);o=a-STACK
    assert bytes(q['bytes'])==stack[o:o+n];mask=bytearray(n)
    for w in c['writes'][h['firstStore']:e['storeCount']]:
     b=bytes.fromhex(w['bytes']);lo=max(a,w['address']);hi=min(a+n,w['address']+len(b))
     if lo<hi:mask[lo-a:hi-a]=b'\1'*(hi-lo)
    assert bytes(q['defined'])==mask;sourceFields['owned']+=sum(mask);sourceFields['opaque']+=len(mask)-sum(mask)
    if name=='createSurface':
     assert mask==b'\1'*108 and q['bytes'][:4]==[108,0,0,0]
     assert q['bytes'][72:76]==[0,0,0,0] # Optional format does not copy its size word.
    if name=='description':assert mask[:8]==b'\1'*8 and mask[8:]==bytes(100)
   if name=='image':assert q['words'][-1] in (0x2010,0x2000)
   if name=='getObject' and response['writes']:
    handle=str(q['words'][0]);a=c['images'][handle]['asset'];expected=struct.pack('<4iHHI',0,a['width'],a['height'],((a['width']*a['bpp']+31)//32)*4,a['planes'],a['bpp'],0)
    assert response['writes']==[dict(offset=0,bytes=list(expected))]
  while wi<len(c['writes']):write(c['writes'][wi]);wi+=1
  assert g==blobs[c['after']['globals']] and stack==blobs[c['after']['stack']] and known==blobs[c['after']['knownStack']] and output==blobs[c['after']['output']],('final reconstruction',i)
  for r in c['records']:
   b,m=bitmapRecords[r['address']];assert b==blobs[r['bytes']] and m==blobs[r['mask']]
  assert len(c['records'])==len(bitmapRecords)
  for h in c['helpers']:
   assert h['returnSP']==h['sp']+4+h['pop'] and hex(h['entry']) in c['instructions']
   if h['kind']=='constructor':assert h['result']==h['wrapper'] and h['pop']==12
   counts[h['kind']+'Returns']+=1
  if not own:outputMasks.append(dict(index=i,mask=list(om)))
  counts['fullGlobalBytes']+=FULL;counts['stackBytes']+=SSIZE;counts['wrapperBytes']+=len(bitmapRecords)*0x1f50;counts['wrapperRecords']+=len(bitmapRecords)
  if own:
   tokens=[a['address'] for a in c['allocations'] if a['address']];assert tokens==[0x28010020+0x2000*j for j in range(len(tokens))]
   assert all(blobs[a['backing']]==b'\xa5'*0x1f50 for a in c['allocations'] if a['address'])
   assert g[0x458b00-BASE:0x458b00-BASE+0x7d8]==bytes(0x7d8) and g[0x44d068-BASE:0x44d068-BASE+4]==b'\1\0\0\0'
   if c['end']=='settings':assert len(c['allocations'])==24
   else:assert len(c['allocations'])==11
 assert counts['loader']==51 and counts['copy']==10 and counts['own']==8 and counts['settings']==7 and counts['nullBitmap']==1
 _,lib=unpack(fixtures/'original-lib-initialization.json');patches=lib['cases'][0]['patches']
 for p in patches:assert all(int(a,16)+len(bytes.fromhex(h))<=p['address'] or int(a,16)>=p['address']+p['count'] for a,h in pcs.items())
 coverage={}
 for name,start,end in [('loader',0x43ed10,0x43ee50),('copy',0x4013d0,0x4014d2),('constructor',0x43ee50,0x43ef44)]:
  text=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',f'--start-address={hex(start)}',f'--stop-address={hex(end)}',str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True);items=[]
  for line in text.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
   if m:items.append(dict(address=hex(int(m[1],16)),bytes=bytes.fromhex(m[2]).hex(),instruction=m[3]))
  assert all(v['address'] not in pcs or pcs[v['address']]==v['bytes'] for v in items)
  coverage[name]=dict(static=len(items),executed=sum(v['address'] in pcs for v in items),unexecuted=[v for v in items if v['address'] not in pcs])
 old=ROOT/'build/research/bitmap-surface-loading-candidate1.parts'
 for i in range(24):
  p=json.loads((old/f'{i:04d}.json').read_bytes());c=dict(d['cases'][i]);c.pop('terminalHookObserved');assert p['case']==c and all(d['blobs'][h]==v for h,v in p['blobs'].items())
 pins=json.loads((ROOT/'build/research/bitmap-surface-loading-prior-pins.json').read_bytes());assert len(pins)==239
 for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for n,m in v['files'].items():assert digest((vendor/'vendor'/n).read_bytes())==m['vendoredSHA256']
 nativeFields=Counter();nativeEvents=0;ownMetadata=[]
 for i,c in enumerate(d['cases']):
  limit=next((j+1 for j,e in enumerate(c['events']) if e.get('key')==('getDC#1' if i==44 else 'getObject#1')),len(c['events'])) if i in (44,46) else len(c['events'])
  for e in c['events'][:limit]:
   if 'request' not in e:continue
   nativeEvents+=1;q=e['request']
   if 'defined' in q:nativeFields['owned']+=sum(q['defined']);nativeFields['opaque']+=len(q['defined'])-sum(q['defined'])
  if c['spec']['kind']=='own':
   def metadata(w):
    p=w['address'];return w['pc'] is not None and 0x424784<=w['pc']<0x427089 and (BASE<=p<BASE+FULL or any(r['address']<=p<r['address']+0x1f50 for r in c['records']))
   ownMetadata.append(sum(metadata(w) for w in c['writes']))
 report=dict(sourceBytes=len(raw),sourceSHA256=digest(raw),producerSHA256=digest((ROOT/'tools/oracle_bitmap_surface_loading.py').read_bytes()),cases=69,counts=dict(counts),events=dict(events),platformStructureBytes=dict(sourceFields),coverage=coverage,actualEXE=sum(int(a,16)<0x78000000 for a in pcs),actualCRT=sum(int(a,16)>=0x78000000 for a in pcs),blobs=len(blobs),assets=24,atomicParts=69,priorCompletedCasesUnchanged=24,priorFixturesUnchanged=239,vendorFiles=10,libPatchSpansDisjoint=13,fullOriginalBytesMasksReconstructed=True,ownParentEntryUnchanged=True,directDimensionMasks=outputMasks,nativeUnknownReadCases=[44,46],nativeDirectMatches=59,nativeComparedRequestBytes=dict(nativeFields),nativeComparedAPIRequests=nativeEvents,ownOrderedMetadataWrites=ownMetadata,nativeStagedFullGlobalBytes=67*FULL,ownSettingsBoundaries=7,ownNullMetadataStops=1,wholeDispatcherReturns=0,windowsVerified=False)
 if fixture:
  payload,value=unpack(fixture);assert payload+b'\n'==raw and value==d;p=Path(fixture).read_bytes();report.update(fixtureBytes=len(p),fixtureSHA256=digest(p),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();r=validate(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps({k:v for k,v in r.items() if k!='directDimensionMasks'},indent=2))
