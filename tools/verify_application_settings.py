#!/usr/bin/env python3
"""Read-only verification of own application settings and scratch provenance.
Pinned NTSD/VC80/control.txt, recorded same-CPU execution and declared file IO.
Reconstruct source globals/private stack, all scratch reads and returned states;
keep private native backing unknown and missing-FILE stop distinct from return.
No executable run, memory mutation, Windows/device or whole dispatcher claim.
"""
import argparse,base64,hashlib,json,re,struct,subprocess,zlib
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack
BASE,FULL,STACK,SSIZE,SCRATCH,SCRATCH_SIZE=0x44d000,0xc3a8,0x1000d000,0x2400,0x1000e878,500

def digest(b):return hashlib.sha256(b).hexdigest()
def key(v):return digest(json.dumps(v,sort_keys=True,separators=(',',':')).encode())
def validate(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert len(d['cases'])==18 and len(d['parents'])==7 and raw.endswith(b'\n')
 assert path.with_name(path.stem+'-source.py').read_bytes()==(ROOT/'tools/oracle_application_settings.py').read_bytes()
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes();assert digest(exe)==d['exeSHA256']==EXE_SHA256 and digest(dll)==d['crtSHA256']
 pe,crt=PE(exe),PE(dll);blobs={}
 for h,v in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and digest(b)==h==v['sha256'];blobs[h]=b
 control=(DEFAULT_SOURCE/'data/control.txt').read_bytes();assert control==blobs[d['source']['raw']] and control.replace(b'\r\n',b'\n')==blobs[d['source']['logical']]
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';_,bitmap=unpack(fixtures/'original-bitmap-surface-loading.json')
 for h,p in d['parents'].items():
  assert h==key(p) and p in bitmap['cases'] and p['end']=='settings'
  # Full parent contains every startup/loop/resource state/event/record. Its
  # blob payloads, not just identifiers, must retain the accepted original bytes.
 for h,v in bitmap['blobs'].items():
  if h in d['blobs']:assert v==d['blobs'][h]
 assert d['assets']=={k:v for k,v in bitmap['assets'].items() if v['kind']=='embedded'}
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==18
 counts=Counter();events=Counter();pcs={};ownedScratch=0;unknownScratch=0
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i:04d}.json').read_bytes());assert part['case']==c and part['parent']==d['parents'][c['parent']] and all(d['blobs'][h]==b for h,b in part['blobs'].items())
  p=d['parents'][c['parent']];before=c['before'];assert c['crtBefore']==p['crtAfter']
  for k in ['globals','stack','knownStack','sp','pc','cw','seh']:assert before[k]==p['after'][k],(i,k)
  assert before['registers'][0]==0 and before['pc']==0x427089 and before['sp']==0x1000ea74
  assert c['after']['cw']==0x37f and c['after']['seh']==before['seh']
  if c['end']=='ready':assert c['after']['pc']==0x42709b and c['after']['sp']==0x1000ea74 and c['after']['registers']==before['registers'][:2]+[0xffffffff,p['parents']['entry']['worldEntry']['target']]
  else:assert c['end']=='nullFile' and c['after']['pc']==0x4234db and c['after']['sp']==0x1000e854
  target=p['parents']['entry']['worldEntry']['target'];targetAddress=0x1000ea94
  history=sum([p['parents'][k]['stackStores'] for k in ('parent','loop','entry')],[])+p['stackStores']+c['stackStores']
  targetWrites=[w for w in history if w['address']<targetAddress+4 and targetAddress<w['address']+len(bytes.fromhex(w['bytes']))]
  assert targetWrites==[dict(pc=0x4246fd,address=targetAddress,bytes=struct.pack('<I',target).hex())]
  off=targetAddress-STACK;assert blobs[before['stack']][off:off+4]==struct.pack('<I',target)
  counts['ownTargetStores']+=1
  counts[c['end']]+=1
  for a,h in c['instructions'].items():
   pc=int(a,16);b=bytes.fromhex(h);binary,q=(dll,crt) if pc>=0x78000000 else (exe,pe);off=q.offset(pc-q.base);assert binary[off:off+len(b)]==b,(i,a);pcs[a]=h
  assert '0x42709b' not in c['instructions']
  if c['end']=='nullFile':assert '0x4234db' not in c['instructions']
  g=bytearray(blobs[before['globals']]);gm=bytearray(FULL);stack=bytearray(blobs[before['stack']]);known=bytearray(blobs[before['knownStack']]);scratchMask=bytearray(SCRATCH_SIZE);wi=0
  def write(w):
   nonlocal wi
   b=bytes.fromhex(w['bytes']);p=w['address'];n=len(b)
   assert hex(w['pc']) in c['instructions'];counts['CPUStores']+=1;counts['CPUStoreBytes']+=n
   if BASE<=p<p+n<=BASE+FULL:g[p-BASE:p-BASE+n]=b;gm[p-BASE:p-BASE+n]=b'\1'*n
   lo=max(STACK,p);hi=min(STACK+SSIZE,p+n)
   if lo<hi:stack[lo-STACK:hi-STACK]=b[lo-p:hi-p];known[lo-STACK:hi-STACK]=b'\1'*(hi-lo)
   if SCRATCH<=p<p+n<=SCRATCH+SCRATCH_SIZE:scratchMask[p-SCRATCH:p-SCRATCH+n]=b'\1'*n
   wi+=1
  def advance(n):
   while wi<n:write(c['stores'][wi])
  def check_state(s):
   nonlocal ownedScratch,unknownScratch
   assert g==blobs[s['globals']] and gm==blobs[s['mask']]
   assert stack==blobs[s['stack']] and known==blobs[s['knownStack']]
   off=SCRATCH-STACK;assert stack[off:off+SCRATCH_SIZE]==blobs[s['scratch']] and scratchMask==blobs[s['scratchMask']]
   assert s['cw']==0x37f
   counts['stateCheckpoints']+=1;counts['fullGlobalBytes']+=FULL;counts['scratchBytes']+=SCRATCH_SIZE;counts['stackBytes']+=SSIZE
   ownedScratch+=sum(scratchMask);unknownScratch+=SCRATCH_SIZE-sum(scratchMask)
  checkpoints=[(e['state']['storeCount'],0,e['state']) for e in c['events'] if 'state' in e]+[(r['storeCount'],1,r) for r in c['reads']]+[(c['after']['storeCount'],0,c['after'])]
  check_state(before)
  for n,kind,v in sorted(checkpoints,key=lambda x:(x[0],x[1])):
   advance(n)
   if kind==0:check_state(v)
   else:
    a=v['address']-STACK;o=v['address']-SCRATCH;count=v['count'];assert stack[a:a+count]==bytes.fromhex(v['bytes']) and known[a:a+count]==bytes(v['parentKnown']) and scratchMask[o:o+count]==bytes(v['written'])
    assert all(v['written']),('Unknown source scratch read',i,v)
    counts['scratchReads']+=1;counts['scratchReadBytes']+=count
  advance(len(c['stores']));assert wi==len(c['stores'])
  assert g[0xb440:]==blobs[before['globals']][0xb440:] # World/outer unchanged.
  assert all(not (r['address']<=w['address']<r['address']+0x1f50) for r in p['records'] for w in c['stores'])
  assert c['crtBefore']==c['crtAfter']
  section=next(s for s in crt.sections if s['name']=='.data');db=crt.base+section['rva'];dataBytes=bytearray(blobs[c['crtBefore']['data']]);ptd=bytearray(blobs[c['crtBefore']['ptd']])
  allStores={(q['pc'],q['address'],q['bytes']) for q in c['stores']}
  for w in c['crtStores']:
   assert (w['pc'],w['address'],w['bytes']) in allStores
   b=bytes.fromhex(w['bytes']);address=w['address']
   if db<=address<address+len(b)<=db+len(dataBytes):dataBytes[address-db:address-db+len(b)]=b
   elif 0x20000000<=address<address+len(b)<=0x20000200:ptd[address-0x20000000:address-0x20000000+len(b)]=b
   else:raise AssertionError(('Unexpected CRT store',w))
   counts['CRTDataStores']+=1
  assert dataBytes==blobs[c['crtAfter']['data']] and ptd==blobs[c['crtAfter']['ptd']]
  for e in c['events']:
   events[e['kind']]+=1
   if e['kind'] in ('scan','gets','eof'):
    assert e['state']['sp']==e['entrySP']+4 and e['state']['registers']==e['saved']
    counts['CRTReturns']+=1
  expectedWrites=[dict(kind='write',arguments=[w['address'],len(bytes.fromhex(w['bytes'])),int.from_bytes(bytes.fromhex(w['bytes']),'little')]) for w in c['stores'] if BASE<=w['address']<BASE+FULL and (0x423480<=w['pc']<0x4236ca or w['pc']==0x427092)]
  assert [e for e in c['events'] if e['kind']=='write']==expectedWrites
  position=0;data=blobs[c['input']]
  for io in c['io']:
   assert io['before']==position and io['count']==0x10000
   b=bytes.fromhex(io['bytes']);assert b==data[position:position+min(io['count'],c['spec'].get('chunk',4096))] and io['result']==len(b);position+=len(b)
   counts['readRequests']+=1;counts['readBytes']+=len(b)
  if c['end']=='ready':assert g[0x44d068-BASE:0x44d068-BASE+4]==bytes(4)
  else:assert g==blobs[before['globals']] and c['events'][0]['arguments']==[0]
 _,lib=unpack(fixtures/'original-lib-initialization.json');patches=lib['cases'][0]['patches']
 for p in patches:assert all(int(a,16)+len(bytes.fromhex(h))<=p['address'] or int(a,16)>=p['address']+p['count'] for a,h in pcs.items())
 coverage={}
 for name,start,end in [('settings',0x423480,0x4236ca),('caller',0x427089,0x42709b)]:
  text=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',f'--start-address={hex(start)}',f'--stop-address={hex(end)}',str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True);items=[]
  for line in text.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
   if m:items.append(dict(address=hex(int(m[1],16)),bytes=bytes.fromhex(m[2]).hex(),instruction=m[3]))
  assert all(v['address'] not in pcs or pcs[v['address']]==v['bytes'] for v in items)
  coverage[name]=dict(static=len(items),executed=sum(v['address'] in pcs for v in items),unexecuted=[v for v in items if v['address'] not in pcs])
 pins=json.loads((ROOT/'build/research/application-settings-prior-pins.json').read_bytes());assert len(pins)==240
 for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for n,m in v['files'].items():assert digest((vendor/'vendor'/n).read_bytes())==m['vendoredSHA256']
 nativeStates=[e['state'] for c in d['cases'] for e in c['events'] if 'state' in e]+[c['after'] for c in d['cases']]
 ownedScratch=sum(sum(blobs[s['scratchMask']]) for s in nativeStates);unknownScratch=len(nativeStates)*SCRATCH_SIZE-ownedScratch
 report=dict(sourceBytes=len(raw),sourceSHA256=digest(raw),producerSHA256=digest((ROOT/'tools/oracle_application_settings.py').read_bytes()),cases=18,parents=7,counts=dict(counts),events=dict(events),coverage=coverage,actualEXE=sum(int(a,16)<0x78000000 for a in pcs),actualCRT=sum(int(a,16)>=0x78000000 for a in pcs),blobs=len(blobs),atomicParts=18,priorFixturesUnchanged=240,vendorFiles=10,libPatchSpansDisjoint=13,fullOriginalStatesReconstructed=True,ownFullParentsUnchanged=True,ownCRTPTDRetained=True,sourceScratchReadsAllProduced=True,nativeComparedStateCheckpoints=len(nativeStates),nativeComparedFullGlobalBytes=len(nativeStates)*FULL,nativeScratchOwnedCheckpointBytes=ownedScratch,nativeScratchUnknownCheckpointBytes=unknownScratch,wholeDispatcherReturns=0,windowsVerified=False)
 if fixture:
  payload,value=unpack(fixture);assert payload+b'\n'==raw and value==d;p=Path(fixture).read_bytes();report.update(fixtureBytes=len(p),fixtureSHA256=digest(p),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();r=validate(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps(r,indent=2))
