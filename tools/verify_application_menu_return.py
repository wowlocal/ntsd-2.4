#!/usr/bin/env python3
"""Read-only audit of own menus, actual World/dispatcher returns and loop tail.
Pinned original EXE/lib/VC80/DIBs, Unicorn2.1.4 and declared platform boundaries.
Reconstruct full source globals/stack/masks/SEH/library and unchanged resources;
check actual parent provenance and return ABI. Ordinary cookie/SEH instructions
are evidence, not native private-stack imports. NULL cursor stays a separate
pre-read stop. No execution, input mutation, worker/Windows/device claim.
"""
import argparse,base64,json,struct,subprocess,re,zlib
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack
from verify_application_screen_body import digest,key,validate as validate_body
BASE,FULL,STACK,SSIZE,LOCAL,LSIZE,LIB=0x44d000,0xc3a8,0x1000d000,0x2400,0x1000ea74,0xc0,0x36000000

def validate(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert len(d['cases'])==48
 producer=(ROOT/'tools/oracle_application_menu_return.py').read_bytes();assert producer==path.with_name(path.stem+'-source.py').read_bytes()
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
 # Accepted parent verifier also independently checks relocated installer,
 # all original DIB bytes, earlier own parents and native unknown-local masks.
 parent_report=validate_body(ROOT/'build/research/application-screen-body-candidate1.json',fixtures/'original-application-screen-body.json')
 _,old=unpack(fixtures/'original-application-screen-body.json');_,front=unpack(fixtures/'original-application-front-screen.json')
 assert set(d['bodyParents'])=={key(c) for c in old['cases']}
 for h,c in d['bodyParents'].items():assert h==key(c) and c in old['cases']
 for h,c in d['frontParents'].items():assert h==key(c) and c in front['cases'] and c['end'] in ('critical','alternate')
 assert len(d['frontParents'])==40 and set(d['frontParents'])==set(old['frontParents'])|{key(front['cases'][39])}
 for name in ('settingsParents','bitmapParents','assets'):
  for h,v in d[name].items():assert front[name][h]==v
 for name in ('installation','libraryInitial','libraryAllocations','exeSHA256','libSHA256','crtSHA256'):assert d[name]==old[name]
 blobs={}
 for h,v in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and digest(b)==h==v['sha256'];blobs[h]=b
 for h,v in old['blobs'].items():assert d['blobs'][h]==v
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(exe)==EXE_SHA256;pe=PE(exe);patched=bytearray(exe)
 for p in d['installation']['patches']:
  at=pe.offset(p['address']-pe.base);assert exe[at:at+p['count']].hex()==p['before'];patched[at:at+p['count']]=bytes.fromhex(p['after'])
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==48
 counts=Counter();events=Counter();pcs={};helperCounts=Counter();reads=Counter();ends=Counter()
 for i,c in enumerate(d['cases']):
  body=d['bodyParents'].get(c['parent']);fc=d['frontParents'][body['parent'] if body else c['parent']];sc=d['settingsParents'][fc['parent']];bp=d['bitmapParents'][sc['parent']];parent=body or fc
  part=json.loads((parts/f'{i:04d}.json').read_bytes());assert part['case']==c and part['bodyParent']==body and part['frontParent']==fc and part['settingsParent']==sc and part['bitmapParent']==bp
  for h,v in part['blobs'].items():assert d['blobs'][h]==v
  for h,v in part['assets'].items():assert d['assets'][h]==v
  for k in ('pc','sp','globals','stack','knownStack','cw','seh','registers'):assert c['before'][k]==parent['after'][k],(i,k)
  if body:
   for k in ('local','library','retainedDC'):assert c['before'][k]==body['after'][k]
  else:assert c['before']['library']==d['libraryInitial'] and c['before']['retainedDC']==0
  assert c['before']['pc']==0x4275cb and c['before']['sp']==LOCAL and c['before']['eax']==(0 if body else 0xfffffffd)
  assert c['crtBefore']==parent['crtAfter']==c['crtAfter'] and not c['crtStores']
  assert c['records']==fc['records']
  target=bp['parents']['entry']['worldEntry']['target'];assert c['before']['registers'][3]==target
  assert not bp['parents']['entry']['worldEntry'].get('returned',False)
  abi=c['abi'];worldABI=abi[str(0x4246b0)];dispatchABI=abi[str(0x43e9a0)]
  assert worldABI['argument']==target and worldABI['registers'][1:]==[1,0,2]
  # Actual parent producer: retained EBP1/EDI2 is established before World,
  # independent of World's later internal EBP19/202. This is instruction
  # evidence plus measured own entry/return values, not native imported bytes.
  entryPCs=bp['parents']['entry']['instructions']
  assert ('0x43ea8d' in entryPCs and '0x43ea92' in entryPCs) or ('0x43ea6b' in entryPCs and '0x43ea7e' in entryPCs)
  counts['ownDispatcherProducerAudits']+=1
  for a,h in c['instructions'].items():
   pc=int(a,16);b=bytes.fromhex(h);off=pe.offset(pc-pe.base);assert b==patched[off:off+len(b)],(i,a);pcs[a]=h
  assert '0x43d110' not in c['instructions']
  g=bytearray(blobs[c['before']['globals']]);gm=bytearray(FULL);stack=bytearray(blobs[c['before']['stack']]);known=bytearray(blobs[c['before']['knownStack']]);lm=bytearray(LSIZE);lr=blobs[c['before']['library']];seh=c['before']['seh'];wi=0
  def write(w):
   nonlocal seh
   b=bytes.fromhex(w['bytes']);p=w['address'];n=len(b);assert hex(w['pc']) in c['instructions'];counts['CPUStores']+=1;counts['storeBytes']+=n
   if BASE<=p<p+n<=BASE+FULL:g[p-BASE:p-BASE+n]=b;gm[p-BASE:p-BASE+n]=b'\1'*n
   elif STACK<=p<p+n<=STACK+SSIZE:
    stack[p-STACK:p-STACK+n]=b;known[p-STACK:p-STACK+n]=b'\1'*n
    if LOCAL<=p<p+n<=LOCAL+LSIZE:lm[p-LOCAL:p-LOCAL+n]=b'\1'*n
   else:assert p==0 and n==4;seh=int.from_bytes(b,'little');counts['originalSEHStores']+=1
  def advance(n):
   nonlocal wi
   assert n>=wi
   while wi<n:write(c['writes'][wi]);wi+=1
  checks=[]
  for e in c['events']:checks.append((e['storeCount']-(e['event']['kind']=='write'),'event',e))
  for read in c['localReads']:checks.append((read['storeCount'],'read',read))
  for label in ('before','mainEntry','tailEntry','worldReturn','dispatchReturn','after'):
   if c[label]:checks.append((c[label]['storeCount'],'state',c[label]))
  current=None
  for n,kind,q in sorted(checks,key=lambda x:x[0]):
   advance(n)
   if kind=='state':
    assert g==blobs[q['globals']] and gm==blobs[q['mask']] and stack==blobs[q['stack']] and known==blobs[q['knownStack']],(i,q['pc'])
    assert lm==blobs[q['localMask']] and stack[LOCAL-STACK:LOCAL-STACK+LSIZE]==blobs[q['local']] and lr==blobs[q['library']]
    assert seh==q['seh'] and q['cw']==0x37f and struct.unpack_from('<I',g,0x458580-BASE)[0]==q['counter'];assert struct.unpack_from('<I',lr,0x306e)[0]==q['retainedDC'];counts['stateCheckpoints']+=1
   elif kind=='read':
    p=q['address'];size=q['count'];off=p-LOCAL;assert bytes.fromhex(q['bytes'])==stack[p-STACK:p-STACK+size] and q['written']==list(lm[off:off+size]) and q['known']==list(known[p-STACK:p-STACK+size]);reads[hex(q['pc'])]+=1
    assert hex(q['pc']) in c['instructions'] and size==4
    if all(q['written']):assert p==LOCAL+0x10 and q['pc']==0x4450ba and bytes.fromhex(q['bytes'])==struct.pack('<I',0x4287ff);counts['ownCookieCallMarkerReads']+=1
    else:assert q['pc'] in range(0x4287ec,0x4287f1) and p==LOCAL+4*(q['pc']-0x4287ec);counts['retainedPrivateLocalReads']+=1
   else:
    assert g==blobs[q['globals']],(i,n,q['event']['kind']);e=q['event'];events[e['kind']]+=1
    if e['kind']=='draw':
     current=next((r for r in c['records'] if r['address']==e['arguments'][0]),None);assert e['arguments'][6]==target
     if current is None:assert e['arguments'][0]==0 and c['end']=='nullBitmap'
    if e['kind']=='read':
     r=e['read'];b=blobs[current['bytes']];m=blobs[current['mask']];assert struct.unpack_from('<I',b,r['offset'])[0]==r['value'] and bool(r['defined'])==all(m[r['offset']:r['offset']+4]);counts['undefinedBitmapReads']+=not r['defined']
  advance(len(c['writes']));ends[c['end']]+=1
  assert c['after']['library']==c['before']['library']
  if c['end']=='iteration':
   for label,a,pop,pc in [('worldReturn',worldABI,8,0x43ecbf),('dispatchReturn',dispatchABI,4,0x43d187)]:
    s=c[label];assert s['pc']==pc==a['returnPC'] and s['sp']==a['sp']+pop and s['registers']==a['registers'] and s['seh']==a['seh'];counts['actualABIReturns']+=1
   assert c['worldReturn']['eax']==(c['spec']['presentResult']&0xffffffff) and c['dispatchReturn']['eax']==1 and c['after']['eax']==c['after']['counter']==2
   assert c['after']['baseline']==c['dispatchReturn']['baseline']==123456822 and c['after']['sp']==0x1000effc and c['after']['seh']==0xffffffff
   assert c['instructions']['0x43ecd8']=='8bc5' and '0x428805' in c['instructions'] and '0x43ed01' in c['instructions']
   assert not c['pending'] and sum(lm)==4
  else:
   assert i==6 and c['end']=='nullBitmap' and c['after']['pc']==0x43f04b
   assert c['worldReturn'] is None and c['dispatchReturn'] is None and c['after']['counter']==1 and sum(lm)==0
  for h in c['helpers']:assert h['returnSP']==h['sp']+4+h['pop'] and hex(h['entry']) in c['instructions'];helperCounts[hex(h['entry'])]+=1
  counts['helperReturns']+=len(c['helpers']);counts['wrapperRecords']+=len(c['records']);counts['fullRecordBytes']+=len(c['records'])*0x1f50
 assert ends=={'iteration':47,'nullBitmap':1}
 coverage={}
 for name,start,end in [('alternate',0x4275cb,0x427915),('main',0x427915,0x427ca7),('tail',0x42873e,0x428808),('panel',0x423b00,0x423b19),('overlay',0x4028a0,0x402a60),('present',0x43e940,0x43e99f),('dispatchReturn',0x43ecbf,0x43ed02),('loopTail',0x43d187,0x43d210)]:
  output=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',f'--start-address={hex(start)}',f'--stop-address={hex(end)}',str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True);items=[]
  for line in output.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
   if m:items.append(dict(address=hex(int(m[1],16)),bytes=bytes.fromhex(m[2]).hex(),instruction=m[3]))
  coverage[name]=dict(static=len(items),executed=sum(v['address'] in pcs for v in items),unexecuted=[v for v in items if v['address'] not in pcs])
 pins=json.load(open(ROOT/'build/research/application-menu-return-prior-pins.json'));assert len(pins)==243
 for name,h in pins.items():assert digest((fixtures/name).read_bytes())==h
 report=dict(sourceBytes=len(raw),sourceSHA256=digest(raw),producerSHA256=digest(producer),cases=48,wholeIterations=47,preNullCursorStops=1,bodyParents=43,frontParents=40,settingsParents=len(d['settingsParents']),bitmapParents=len(d['bitmapParents']),counts=dict(counts),events=dict(events),helpers=dict(helperCounts),actualEXE=len(pcs),actualDLL=0,actualCRT=0,localReadPCs=dict(reads),coverage=coverage,blobs=len(blobs),assets=len(d['assets']),atomicParts=48,priorFixturesUnchanged=243,vendorFiles=10,installerOriginalPCs=104,installerRelocations=76,installerCopies=13,installerCopyBytes=62,parentVerificationSHA256=digest(json.dumps(parent_report,sort_keys=True).encode()),fullOriginalStatesReconstructed=True,ownParentsRetained=True,workerBodyExecuted=False,windowsVerified=False)
 if fixture:
  payload,value=unpack(fixture);assert payload+b'\n'==raw and value==d;p=Path(fixture).read_bytes();report.update(fixtureBytes=len(p),fixtureSHA256=digest(p),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();r=validate(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps({k:v for k,v in r.items() if k not in ('coverage','localReadPCs')},indent=2))
