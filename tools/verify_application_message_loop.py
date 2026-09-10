#!/usr/bin/env python3
"""Read-only verification of original message-loop/own startup evidence.
Pinned NTSD EXE, recorded Unicorn2.1.4 execution and declared Win32 responses.
Reconstruct MSG/global/outer storage and instruction/return provenance; keep
controlled dispatcher results separate from own required-dispatch stop.
No Windows/device execution, fault/control mutation or full-app claim.
"""
import argparse,json,base64,zlib,hashlib,struct,subprocess,re
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack
H=lambda b:hashlib.sha256(b).hexdigest()
BASE,SIZE,OUTER,OUTER_SIZE,MSG=0x44d000,0xb440,0x458440,0x854,0x1000f01c

def audit(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert raw.endswith(b'\n') and len(d['cases'])==64
 assert H((ROOT/'tools/oracle_application_message_loop.py').read_bytes())==H(path.with_name(path.stem+'-source.py').read_bytes())==d['producerSHA256']
 assert H((ROOT/'tools/oracle_winmain_startup.py').read_bytes())==d['parentProducerSHA256']
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert H(exe)==d['exeSHA256']==EXE_SHA256;pe=PE(exe)
 image=bytearray(0x100000)
 for s in pe.sections:
  if s['name']!='.rsrc':image[s['rva']:s['rva']+s['fileSize']]=exe[s['fileOffset']:s['fileOffset']+s['fileSize']]
 initialOuter=bytes(image[OUTER-0x400000:OUTER-0x400000+OUTER_SIZE]);assert initialOuter[0x140:0x144]==b'\0'*4
 blobs={}
 for h,p in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(p['deflate']),-15);assert len(b)==p['count'] and H(b)==h==p['sha256'];blobs[h]=b
 _,accepted=unpack(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-winmain-startup.json');assert len(d['parents'])==1
 for h,p in d['parents'].items():
  assert H(json.dumps(p,separators=(',',':'),sort_keys=True).encode())==h and p==accepted['cases'][0]
  assert all(w['address']>=MSG+28 or w['address']+len(bytes.fromhex(w['bytes']))<=MSG for w in p['stackStores'])
  # Every referenced accepted parent blob is retained byte-for-byte, including
  # its original DIB/WAV/calibration/calendar/state observations.
  def walk(v):
   if isinstance(v,dict):
    for x in v.values():walk(x)
   elif isinstance(v,list):
    for x in v:walk(x)
   elif isinstance(v,str) and v in accepted['blobs']:assert d['blobs'][v]==accepted['blobs'][v]
  walk(p)
 counts=Counter();events=Counter();callbackCodes=Counter();pcs={};sleep=set();stops=[];parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==64
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i+1:04d}.json').read_bytes());assert part['case']==c and part['parent']==d['parents'][c['parent']]
  assert all(d['blobs'][h]==p for h,p in part['blobs'].items())
  assert blobs[c['initialOuter']]==initialOuter;parent=d['parents'][c['parent']]
  g=bytearray(blobs[parent['globals']]);o=bytearray(initialOuter);gm=bytearray(SIZE);om=bytearray(OUTER_SIZE)
  for w in c['stimulus']:
   address=w['address'];b=bytes.fromhex(w['bytes']);assert address in (0x44d02c,0x458580)
   if address<OUTER:g[address-BASE:address-BASE+len(b)]=b
   else:o[address-OUTER:address-OUTER+len(b)]=b
  assert blobs[c['before']['globals']]==g and blobs[c['before']['outer']]==o and c['before']['baseline']==parent['spec']['milliseconds']
  assert blobs[c['before']['message']]==b'\xa5'*28 and blobs[c['before']['messageMask']]==bytes(28)
  for a,h in c['instructions'].items():
   pc=int(a,16);b=bytes.fromhex(h);off=pe.offset(pc-pe.base);assert exe[off:off+len(b)]==b;pcs[a]=h
  gi=oi=0;msg=bytearray(b'\xa5'*28);mm=bytearray(28);counter=c['before']['counter'];previous=c['before']
  def stores(at):
   nonlocal gi,oi
   while gi<len(c['globalStores']) and c['globalStores'][gi]['eventIndex']<=at:
    w=c['globalStores'][gi];gi+=1;b=bytes.fromhex(w['bytes']);off=w['address']-BASE;assert 0<=off<off+len(b)<=SIZE and hex(w['pc']) in c['instructions'];g[off:off+len(b)]=b;gm[off:off+len(b)]=b'\1'*len(b)
   while oi<len(c['outerStores']) and c['outerStores'][oi]['eventIndex']<=at:
    w=c['outerStores'][oi];oi+=1;b=bytes.fromhex(w['bytes']);off=w['address']-OUTER;assert 0<=off<off+len(b)<=OUTER_SIZE and hex(w['pc']) in c['instructions'];o[off:off+len(b)]=b;om[off:off+len(b)]=b'\1'*len(b)
  eventIndex=0
  for step in c['iterations']:
   before=step['before'];after=step['after'];assert before['events']==eventIndex and before['counter']==counter
   assert before['globals']==previous['globals'] and before['outer']==previous['outer'] and before['baseline']==previous['baseline']
   requests=c['events'][eventIndex:after['events']];assert requests[0]['request']['kind']=='peek'
   for e in requests:
    stores(eventIndex);assert blobs[e['globals']]==g and blobs[e['outer']]==o
    q=e['request'];kind=q['kind'];events[kind]+=1
    if q['message'] is not None:assert bytes(q['message'])==msg and q['defined']==[bool(x) for x in mm]
    if kind in ('peek','get'):
     assert q['arguments']==([0]* (4 if kind=='peek' else 3))
     for w in e['response']['writes']:
      b=bytes(w['bytes']);off=w['offset'];assert 0<=off<off+len(b)<=28;msg[off:off+len(b)]=b;mm[off:off+len(b)]=b'\1'*len(b)
    if kind=='sleep':sleep.add(q['arguments'][0])
    if e['response'] is None:assert kind=='gameDispatch' and c['spec'].get('requireDispatcher') and c['end']=='requiredDispatcher'
    eventIndex+=1
   stores(eventIndex);assert blobs[after['globals']]==g and blobs[after['outer']]==o and blobs[after['message']]==msg and blobs[after['messageMask']]==mm
   names=[e['request']['kind'] for e in requests]
   if requests[0]['response']['result']!=0:
    assert names[:2]==['peek','get'] and 'time' not in names and 'gameDispatch' not in names and (step['end']=='quit' or before['baseline']==after['baseline'])
    if requests[1]['response']['result']==0:
     assert names==['peek','get'] and step['end']=='quit' and after['counter']==counter and after['eax']==struct.unpack_from('<I',msg,8)[0]
    else:assert names[2:4]==['translate','dispatchMessage']
   else:assert names[1]=='time'
   if step['end']=='continued':
    counter=(counter+1)&0xffffffff
    if (counter+2**31)%2**32-2**31>60:counter=0
    assert after['counter']==counter and after['sp']==0x1000effc;counts['continuedIterations']+=1
   elif step['end']=='quit':
    assert after['sp']==0x1000f04c and after['registers']==[0x11223344,0x22334455,0x33445566,0x44556677];counts['quitIterations']+=1
   else:assert step['end']=='requiredDispatcher' and after['pc']==0x43e9a0 and after['sp']==0x1000eff4;counts['requiredIterations']+=1
   counts['iterations']+=1;previous=after
  assert eventIndex==len(c['events']) and gi==len(c['globalStores']) and oi==len(c['outerStores'])
  assert blobs[c['after']['globals']]==g and blobs[c['after']['outer']]==o and blobs[c['globalMask']]==gm and blobs[c['outerMask']]==om
  for cb in c['callbacks']:
   assert cb['returnSP']==cb['dispatchSP']==cb['entrySP']+20 and cb['saved']==cb['registers'];callbackCodes[hex(cb['input']['message'])]+=1
  for w in c['stackStores']:
   assert 0x10000000<=w['address']<w['address']+len(bytes.fromhex(w['bytes']))<=0x10010000
   if w['pc'] is not None:assert hex(w['pc']) in c['instructions'];counts['originalStackStores']+=1
   else:counts['adapterStackWrites']+=1
  counts['globalStores']+=len(c['globalStores']);counts['outerStores']+=len(c['outerStores']);counts['callbacks']+=len(c['callbacks']);counts[c['end']]+=1
  assert c['controlWord']==0x37f
  if c['end']=='requiredDispatcher':stops.append(dict(case=c['spec']['label'],pc=c['after']['pc'],baselineBefore=c['iterations'][-1]['before']['baseline'],baselineAtStop=c['after']['baseline'],counter=c['after']['counter'],request=c['events'][-1]['request']))
 assert pcs==d['instructions'] and counts['returned']==63 and len(stops)==1 and 4 in sleep
 _,lib=unpack(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-lib-initialization.json');patches=lib['cases'][0]['patches'];assert len(patches)==13
 for p in patches:assert all(int(a,16)+len(bytes.fromhex(h))<=p['address'] or int(a,16)>=p['address']+p['count'] for a,h in pcs.items())
 static={}
 text=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel','--start-address=0x43d100','--stop-address=0x43d222',str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True)
 for line in text.splitlines():
  m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
  if m:static[hex(int(m[1],16))]=dict(bytes=bytes.fromhex(m[2]).hex(),assembly=m[3])
 for a,s in static.items():
  if a in pcs:assert pcs[a]==s['bytes']
 pins=json.loads((ROOT/'build/research/application-message-loop-prior-pins.json').read_bytes());assert len(pins)==235
 for f,h in pins.items():assert H((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/f).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for f,m in v['files'].items():assert H((vendor/'vendor'/f).read_bytes())==m['vendoredSHA256']
 report=dict(sourceBytes=len(raw),sourceSHA256=H(raw),producerSHA256=d['producerSHA256'],cases=64,parentCount=1,fullParentReproduced=True,parentProducerSHA256=d['parentProducerSHA256'],counts=dict(counts),events=dict(events),callbackMessages=dict(callbackCodes),sleepArguments=sorted(sleep),requiredDispatcherStops=stops,blobs=len(blobs),actualEXE=len(pcs),actualCRT=0,loopStarts=len(static),executedLoopStarts=sum(a in pcs for a in static),unexecutedLoop=[dict(address=a,**s) for a,s in static.items() if a not in pcs],fullGlobalsOuterMSGReconstruction=True,oldFixturesUnchanged=235,vendorFiles=10,libPatchSitesDisjoint=13)
 if fixture:
  full,value=unpack(fixture);assert full==raw[:-1] and value==d;report.update(fixtureBytes=Path(fixture).stat().st_size,fixtureSHA256=H(Path(fixture).read_bytes()),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();report=audit(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
