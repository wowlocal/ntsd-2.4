#!/usr/bin/env python3
"""Independently audit whole startup-panel source bytes, stores and provenance.
Pinned game EXE/VC80/DIB and controlled file/device boundaries; no execution or
Windows claim. Unknown/private stack reads remain explicit native rejections.
"""
import argparse,base64,json,re,subprocess,zlib,hashlib
from pathlib import Path
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from verify_menu_info_reading import unpack,DLL_SHA256
H=lambda b:hashlib.sha256(b).hexdigest()
BASE,SIZE,LOCAL,LSIZE=0x44d000,0xb440,0x1000ebac,0x450
RANGES=[(0x43cf94,0x43cfb4),(0x43c4a0,0x43c686),(0x43c780,0x43cc54),(0x43cc60,0x43cf3b),(0x43c690,0x43c709),(0x43ee50,0x43ef69),(0x4450b2,0x4450bc)]
def audit(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert raw.endswith(b'\n')
 assert H(path.with_name(path.stem+'-source.py').read_bytes())==H((ROOT/'tools/oracle_startup_panel.py').read_bytes())==d['producerSHA256']
 for p,h in d['dependencies'].items():assert H((ROOT/'tools'/p).read_bytes())==h,p
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes();assert H(exe)==d['exeSHA256']==EXE_SHA256 and H(dll)==d['dllSHA256']==DLL_SHA256
 pe=PE(exe);images=[(exe,pe),(dll,PE(dll))];initial=bytearray(0x100000)
 for s in pe.sections:
  if s['name']!='.rsrc':initial[s['rva']:s['rva']+s['fileSize']]=exe[s['fileOffset']:s['fileOffset']+s['fileSize']]
 initial[0x457578-0x400000:0x45757c-0x400000]=(0x22003000).to_bytes(4,'little');initial=bytes(initial[BASE-0x400000:BASE-0x400000+SIZE])
 blobs={}
 for h,b in d['blobs'].items():
  v=zlib.decompress(base64.b64decode(b['deflate']),-15);assert H(v)==h==b['sha256'] and len(v)==b['count'];blobs[h]=v
 _,lib=unpack(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-lib-initialization.json');assert len(lib['cases'][0]['patches'])==13
 for p in lib['cases'][0]['patches']:assert all(p['address']+p['count']<=a or p['address']>=b for a,b in RANGES)
 counts=Counter();events=Counter();pcs={};unknown=[];returns=Counter();nativeChildren=Counter();nativeEvents=Counter()
 def code(mapping):
  for p,h in mapping.items():
   a=int(p,16);image,ip=images[1 if a>=0x78100000 else 0];o=ip.offset(a-ip.base);b=bytes.fromhex(h);assert image[o:o+len(b)]==b,(p,h);pcs[p]=h
 def gcheck(h,state):assert blobs[h]==state;counts['sourceGlobalSnapshotBytes']+=SIZE
 parts=path.with_suffix('.parts');assert len(d['cases'])==188 and len(list(parts.glob('*.json')))==188
 for ci,c in enumerate(d['cases']):
  part=json.loads((parts/f'{ci+1:04d}.json').read_bytes());assert part['case']==c and all(d['blobs'][h]==b for h,b in part['blobs'].items())
  assert blobs[c['initialGlobals']]==initial
  dib=c['dib'];r=next(s for s in pe.resources() if s['path']==[2,'MENU_BACK1',1028]);b=exe[r['fileOffset']:r['fileOffset']+r['size']];assert blobs[dib['dib']]==b
  assert dib['path']=='MENU_BACK1' and dib['width']==int.from_bytes(b[4:8],'little',signed=True) and dib['height']==int.from_bytes(b[8:12],'little',signed=True)
  previous=c['initialGlobals'];prior_records=[]
  for st in c['steps']:
   assert st['beforeGlobals']==previous;previous=st['globals'];code(st['instructions']);counts['sourceCallers']+=1;counts['nativeRejected' if st['ownBoundary'] else 'nativeWholeCallers']+=1
   assert st['end']=='returned' and st['endPC']==0x43cfb4 and st['endSP']==0x1000f004 and st['controlWord']==0x37f
   state=bytearray(blobs[st['beforeGlobals']]);mask=bytearray(SIZE);stack=bytearray(blobs[st['stackInitial']]);sm=bytearray(LSIZE)
   grouped={};sgroup={}
   for s in st['stores']:grouped.setdefault((s['child'],s['eventIndex']),[]).append(s)
   for s in st['stackWrites']:sgroup.setdefault(s['child'],[]).append(s)
   expected_parent=[];last_info_mask=None
   for i,ch in enumerate(st['children']):
    kind=ch['kind'];counts[kind+'Calls']+=1;returns[hex(ch['returnPC'])]+=1
    assert ch['entrySP']==0x1000f000 and ch['endSP']==0x1000f004 and ch['completed'] and ch['saved']==[0x11223344,0x22334455,0x33445566,0x44556677]
    assert ch['endPC']==ch['returnPC']=={'info':0x43cf99,'content':0x43cfa2,'bitmap':0x43cfab,'defaults':0x43cfb4}[kind]
    expected_parent += [dict(kind='call',arguments=[ch['entry']]),dict(kind='return',arguments=[ch['entry'],ch['result']])]
    gcheck(ch['beforeGlobals'],state)
    if kind in ('info','content'):
     offset=0x398 if kind=='info' else 0;extent=184 if kind=='info' else LSIZE;assert blobs[ch['backing']]==stack[offset:offset+extent]
     expected_mask=bytearray(extent)
     if kind=='content':expected_mask[0x398:0x450]=last_info_mask
     assert blobs[ch['initialLocalMask']]==expected_mask
    for ei in range(len(ch['events'])+1):
     for s in grouped.get((i,ei),[]):
      b=bytes.fromhex(s['bytes']);o=s['address']-BASE;assert 0<=o<o+len(b)<=SIZE and hex(s['pc']) in st['instructions'];state[o:o+len(b)]=b;mask[o:o+len(b)]=b'\1'*len(b);counts['globalStores']+=1
     if ei<len(ch['events']):
      e=ch['events'][ei];events[kind+'-'+e['kind']]+=1
      if e.get('globals'):gcheck(e['globals'],state)
      if e.get('state'):gcheck(e['state']['globals'],state)
      if e.get('file'):assert len(blobs[e['file']])==32
      if e.get('buffer'):assert len(blobs[e['buffer']['bytes']])==len(blobs[e['buffer']['defined']])==st['spec']['capacity']
      if e.get('returnPC'):assert hex(e['returnPC']) in st['instructions'];counts['crtReturns']+=1
    gcheck(ch['globals'],state)
    child_stack_mask=bytearray(LSIZE)
    for s in sgroup.get(i,[]):
     b=bytes.fromhex(s['bytes']);o=s['address']-LOCAL;assert 0<=o<o+len(b)<=LSIZE and hex(s['pc']) in st['instructions'];stack[o:o+len(b)]=b;sm[o:o+len(b)]=b'\1'*len(b);child_stack_mask[o:o+len(b)]=b'\1'*len(b);counts['sharedStackStores']+=1
    if kind=='info':
     q=ch['localState'];assert blobs[q['local']]==stack[0x398:0x450] and blobs[q['localMask']]==child_stack_mask[0x398:0x450];last_info_mask=blobs[q['localMask']]
    elif kind=='content':
     q=ch['scratch'];expected_mask=bytearray(LSIZE);expected_mask[0x398:0x450]=last_info_mask
     expected_mask=bytes(a|b for a,b in zip(expected_mask,child_stack_mask));assert blobs[q['bytes']]==stack and blobs[q['defined']]==expected_mask
    elif kind=='bitmap':
     recs=ch['records'];a=ch['allocation'];assert len(recs)==len(prior_records)+(a['address']!=0)
     if prior_records:assert all(not q['live'] for q in recs[:-1] if a['address']!=0) if a['address'] else all(not q['live'] for q in recs)
     for q in recs:
      b=blobs[q['storage']['bytes']];m=blobs[q['storage']['defined']];assert len(b)==len(m)==0x1f50 and set(m)<={0,1}
     assert int.from_bytes(state[0x458420-BASE:0x458424-BASE],'little')==a['address'];prior_records=recs
    if st['ownBoundary'] is None or i<st['ownBoundary']['child']:nativeChildren[kind]+=1
    limit=st['ownBoundary']['eventCount'] if st['ownBoundary'] and i==st['ownBoundary']['child'] else len(ch['events'])
    if st['ownBoundary'] is None or i<=st['ownBoundary']['child']:
     for e in ch['events'][:limit]:nativeEvents[kind+'-'+e['kind']]+=1
   assert st['events']==expected_parent and st['eax']==st['children'][-1]['result']
   gcheck(st['globals'],state);assert mask==blobs[st['globalMask']]
   assert stack==blobs[st['stackFinal']] and sm==blobs[st['stackMask']]
   assert st['records']==prior_records
   # Actual caller selection, using the immediately preceding child's result.
   kinds=[q['kind'] for q in st['children']];expected=['info']
   if st['children'][0]['result']:
    expected.append('content')
    if st['children'][1]['result']:expected.append('bitmap')
   if st['children'][len(expected)-1]['result']==0:expected.append('defaults')
   assert kinds==expected
   if st['ownBoundary']:
    b=st['ownBoundary'];assert b['count']==1 and (b['kind'],b['offset']) in [('info',28),('content',604),('content',104)];unknown.append(dict(case=c['spec']['label'],kind=b['kind'],offset=b['offset'],count=1,sourceReturn=st['eax']))
 assert counts['sourceCallers']==220 and counts['nativeWholeCallers']==212 and counts['nativeRejected']==8 and pcs==d['instructions']
 static={}
 for a,b in RANGES:
  out=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel','--start-address='+hex(a),'--stop-address='+hex(b),str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True)
  for line in out.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
   if m:static[hex(int(m[1],16))]=dict(bytes=bytes.fromhex(m[2]).hex(),assembly=m[3])
 boundaries={0x43ed10,0x4450ac}
 for p,h in pcs.items():
  if int(p,16)<0x78100000:assert p in static and static[p]['bytes']==h,(p,h)
 pins=json.loads((ROOT/'build/research/startup-panel-prior-pins.json').read_bytes());assert len(pins)==230
 for f,h in pins.items():assert H((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/f).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for f,m in v['files'].items():assert H((vendor/'vendor'/f).read_bytes())==m['vendoredSHA256']
 report=dict(sourceBytes=len(raw),sourceSHA256=H(raw),producerSHA256=d['producerSHA256'],counts=dict(counts),events=dict(events),nativeChildren=dict(nativeChildren),nativeChildEvents=dict(nativeEvents),childReturnPCs=dict(returns),blobs=len(blobs),unknownBoundaries=unknown,actualEXE=sum(int(p,16)<0x78100000 for p in pcs),actualCRT=sum(int(p,16)>=0x78100000 for p in pcs),staticEXE=len(static),unexecutedStatic=[dict(address=p,**b) for p,b in static.items() if p not in pcs],oldFixturesUnchanged=230,vendorFiles=10,fullGlobalAndSharedStackStoreReconstruction=True)
 if fixture:
  full,value=unpack(fixture);assert full==raw[:-1] and value==d;report.update(fixtureBytes=Path(fixture).stat().st_size,fixtureSHA256=H(Path(fixture).read_bytes()),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();r=audit(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps(r,indent=2))
