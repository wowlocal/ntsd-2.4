#!/usr/bin/env python3
"""Read-only artifact/provenance audit for startup adinfo and own roundtrips.
Pinned game EXE/VC80, actual instruction bytes and declared stream boundaries;
no execution or Windows claim. Unknown local source bytes remain source-only.
"""
import argparse,base64,json,re,subprocess,zlib,hashlib
from pathlib import Path
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
DLL_SHA256="c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d"
BASE,SIZE,LOCAL=0x44d000,0xb440,0x1000ef44
H=lambda b:hashlib.sha256(b).hexdigest()
def unpack(path):
 raw=Path(path).read_bytes();d=json.loads(raw)
 if isinstance(d,dict) and 'deflate' in d:
  full=zlib.decompress(base64.b64decode(d['deflate']),-15);assert len(full)==d['count'] and H(full)==d['sha256'];return full,json.loads(full)
 return raw,d

def audit(path,fixture=None,roundtrip=False):
 path=Path(path).resolve();raw,d=unpack(path);assert raw.endswith(b'\n')
 producer='oracle_menu_info_roundtrip.py' if roundtrip else 'oracle_menu_info_reading.py'
 assert H(path.with_name(path.stem+'-source.py').read_bytes())==H((ROOT/'tools'/producer).read_bytes())==d['producerSHA256']
 for p,h in d['dependencies'].items():assert H((ROOT/'tools'/p).read_bytes())==h,p
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes()
 assert H(exe)==d['exeSHA256']==EXE_SHA256 and H(dll)==d['dllSHA256']==DLL_SHA256
 images=[(exe,PE(exe)),(dll,PE(dll))];blobs={}
 for h,b in d['blobs'].items():
  v=zlib.decompress(base64.b64decode(b['deflate']),-15);assert H(v)==h==b['sha256'] and len(v)==b['count'];blobs[h]=v
 if not roundtrip:
  ad=(DEFAULT_SOURCE/d['adinfo']['path']).read_bytes();assert H(ad)==d['adinfo']['sha256'] and ad==b'now 0 4 <end>\r\n'
 _,lib=unpack(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-lib-initialization.json');ranges=[(0x43c4a0,0x43c686),(0x4450b2,0x4450bc)]
 if roundtrip:ranges.extend([(0x43c710,0x43c77f)])
 assert len(lib['cases'][0]['patches'])==13
 for p in lib['cases'][0]['patches']:
  assert all(p['address']+p['count']<=a or p['address']>=b for a,b in ranges)
 pcs={};counts=Counter();events=Counter();unknown=[];readers=[]
 def code(mapping):
  for p,h in mapping.items():
   a=int(p,16);image,pe=images[1 if a>=0x78100000 else 0];o=pe.offset(a-pe.base);b=bytes.fromhex(h);assert image[o:o+len(b)]==b,(p,h);pcs[p]=h
 def state(s,g,l,gm,lm):
  assert blobs[s['globals']]==g and blobs[s['local']]==l and blobs[s['globalMask']]==gm and blobs[s['localMask']]==lm
  counts['globalSnapshotBytes']+=SIZE;counts['localSnapshotBytes']+=184
 def reader(c):
  readers.append(c);code(c['instructions']);assert c['endPC']==0x30000000 and c['endSP']==0x1000f004 and c['saved']==[0x11223344,0x22334455,0x33445566,0x44556677] and c['controlWord']==0x37f
  g=bytearray(blobs[c['before']['globals']]);l=bytearray(blobs[c['before']['local']]);gm=bytearray(SIZE);lm=bytearray(184);state(c['before'],g,l,gm,lm)
  grouped={}
  for s in c['stores']:grouped.setdefault(s['eventIndex'],[]).append(s)
  assert set(grouped)<=set(range(len(c['events'])+1));si=0
  for i in range(len(c['events'])+1):
   for s in grouped.get(i,[]):
    b=bytes.fromhex(s['bytes']);o=s['offset'];target=g if s['region']==0 else l;mask=gm if s['region']==0 else lm
    assert s['region'] in (0,1) and 0<=o<o+len(b)<=len(target) and hex(s['pc']) in c['instructions']
    target[o:o+len(b)]=b;mask[o:o+len(b)]=b'\1'*len(b);si+=1
    counts['globalStores' if s['region']==0 else 'localStores']+=1
    if c['unknown'] and si==c['unknown']['storeCount']:state(c['unknown'],g,l,gm,lm)
   if i<len(c['events']):
    e=c['events'][i];state(e['state'],g,l,gm,lm);events[e['kind']]+=1
    if 'returnPC' in e:assert hex(e['returnPC']) in c['instructions'];counts['readerCRTReturns']+=1
  state(c['after'],g,l,gm,lm)
  for read in c['reads']:
   assert hex(read['pc']) in c['instructions'] and len(bytes.fromhex(read['bytes']))==read['count']
   counts['knownCallerReads' if read['known'] else 'unknownCallerReads']+=1
  if c['unknown']:
   b=c['unknown'];assert c['spec']['input'] is None and b['offset']==28 and b['count']==1 and b['eventCount']==1
   assert not blobs[b['localMask']][28] and any(not r['known'] for r in c['reads']);unknown.append(c['spec']['label'])
  else:assert all(r['known'] for r in c['reads'])
  data=bytes(c['spec']['input'] or []);pos=0
  for i,io in enumerate(c['io']):
   value=bytes.fromhex(io['bytes']);assert io['count']>0
   if i==c['spec']['readFailAt']:assert io['result']==-1 and not value
   else:
    expected=data[pos:pos+min(io['count'],c['spec']['chunk'])];assert value==expected and io['result']==len(value);pos+=len(value)
   assert io['position']==pos
  counts['sourceReaderCalls']+=1
  counts['nativeUnknownRejections' if c['unknown'] else 'nativeSupportedReaders']+=1
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==len(d['cases'])
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i+1:04d}.json').read_bytes());assert part['case']==c and all(d['blobs'][h]==v for h,v in part['blobs'].items())
  if not roundtrip:reader(c)
  else:
   reader(c['first']);reader(c['second']);code(c['writerInstructions']);w=c['writer']
   assert c['first']['result']==1 and c['first']['unknown'] is None and c['second']['unknown'] is None
   # Writer receives the preceding live globals; its input setup writes the same
   # date/words, so first formatting may change only its own path destination.
   before=blobs[c['first']['after']['globals']];index=int.from_bytes(before[0x44d784-BASE:0x44d788-BASE],'little',signed=True);period=int.from_bytes(before[0x44d788-BASE:0x44d78c-BASE],'little',signed=True)
   date=before[0x4527b0-BASE:].split(b'\0',1)[0];assert index==w['index'] and period==w['period'] and date==bytes(w['date'])
   assert w['capacity']==7 and w['available'] and w['mode']=='cache'
   assert w['endPC']==0x30000000 and w['endSP']==0x1000f004
   emitted=b''.join(bytes(e['strings'][0])[:e['result']] for e in w['events'] if e['kind']=='writeFile' and e['result']<0x80000000)
   assert emitted==bytes(c['emitted'])==bytes(c['second']['spec']['input'])
   assert w['globals']==c['second']['before']['globals']
   for e in w['events']:
    events['writer-'+e['kind']]+=1
    if e.get('globals'):assert len(blobs[e['globals']])==SIZE;counts['globalSnapshotBytes']+=SIZE
    if e.get('file'):assert len(blobs[e['file']])==32
    if e.get('buffer'):assert len(blobs[e['buffer']['bytes']])==len(blobs[e['buffer']['defined']])==7 and set(blobs[e['buffer']['defined']])<={0,1}
   counts['acceptedWriteBytes']+=len(emitted);counts['ownRoundtrips']+=1
 if roundtrip:assert len(d['cases'])==16 and counts['sourceReaderCalls']==32 and not unknown
 else:assert len(d['cases'])==196 and len(unknown)==2 and pcs==d['instructions']
 static={}
 for a,b in ranges:
  out=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel','--start-address='+hex(a),'--stop-address='+hex(b),str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True)
  for line in out.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
   if m:static[hex(int(m[1],16))]=dict(bytes=bytes.fromhex(m[2]).hex(),assembly=m[3])
 for p,b in pcs.items():
  if int(p,16)<0x78100000:assert p in static and static[p]['bytes']==b,(p,b)
 pins=json.loads((ROOT/'build/research/menu-info-reading-prior-pins.json').read_bytes());assert len(pins)==228
 for n,h in pins.items():assert H((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/n).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for n,p in v['files'].items():assert H((vendor/'vendor'/n).read_bytes())==p['vendoredSHA256']
 report=dict(sourceSHA256=H(raw),sourceBytes=len(raw),producerSHA256=d['producerSHA256'],counts=dict(counts),events=dict(events),blobs=len(blobs),unknownBoundaries=unknown,actualEXE=sum(int(p,16)<0x78100000 for p in pcs),actualCRT=sum(int(p,16)>=0x78100000 for p in pcs),staticEXE=len(static),unexecutedStatic=[dict(address=p,**v) for p,v in static.items() if p not in pcs],oldFixturesUnchanged=len(pins),vendorFiles=len(v['files']),fullReaderStoreReconstruction=True)
 if fixture:
  full,packed=unpack(fixture);assert full==raw.rstrip(b'\n') and packed==d;report.update(fixtureSHA256=H(Path(fixture).read_bytes()),fixtureBytes=Path(fixture).stat().st_size,fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--roundtrip',action='store_true');p.add_argument('--report');a=p.parse_args();r=audit(a.source,a.fixture,a.roundtrip)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps(r,indent=2))
