#!/usr/bin/env python3
"""Read-only continuous WinMain compatibility evidence verification.
Reconstruct pinned EXE/VC80 global, CRT/PTD, stack and owned allocation bytes
from recorded instructions/stores on one controlled Unicorn2.1.4 CPU. Preserve
ordinary failure stops and unknown private CRT stack provenance. No execution,
protection mutation, Windows/device behavior or full application claim.
"""
import argparse,json,base64,zlib,hashlib,struct,subprocess,re
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack,DLL_SHA256
H=lambda b:hashlib.sha256(b).hexdigest()
BASE,SIZE,PTD,MEM,STACK=0x44d000,0xb440,0x20000000,0x26000000,0x10000000

def audit(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert raw.endswith(b'\n')
 assert H((ROOT/'tools/oracle_winmain_startup.py').read_bytes())==H(path.with_name(path.stem+'-source.py').read_bytes())==d['producerSHA256']
 for p,h in d['dependencies'].items():assert H((ROOT/'tools'/p).read_bytes())==h,p
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes();assert H(exe)==d['exeSHA256']==EXE_SHA256 and H(dll)==d['dllSHA256']==DLL_SHA256
 ep,cp=PE(exe),PE(dll);sec=next(s for s in cp.sections if s['name']=='.data');db=cp.base+sec['rva'];ds=sec['virtualSize']
 initial=bytearray(ds);initial[:sec['fileSize']]=dll[sec['fileOffset']:sec['fileOffset']+sec['fileSize']]
 for address in [0x781c13d8,0x781c19f8,0x781c1f5c]:
  o=address-db;initial[o:o+4]=(int.from_bytes(initial[o:o+4],'little')+1).to_bytes(4,'little')
 initial[0x781c37e0-db:0x781c37e4-db]=(MEM+0x1000).to_bytes(4,'little')
 ptd=bytearray(0x200)
 for o,v in [(0x5c,0x781c1958),(0x14,1),(0x70,1),(0x68,0x781c13d8),(0x6c,0x781c19f8)]:ptd[o:o+4]=v.to_bytes(4,'little')
 ptd[0xc8]=ptd[0x14b]=0x43
 pebytes=bytearray(0x100000)
 for s in ep.sections:
  if s['name']!='.rsrc':pebytes[s['rva']:s['rva']+s['fileSize']]=exe[s['fileOffset']:s['fileOffset']+s['fileSize']]
 initialGlobals=pebytes[BASE-0x400000:BASE-0x400000+SIZE]
 assert pebytes[0x4ef38]==0
 blobs={}
 for h,b in d['blobs'].items():
  v=zlib.decompress(base64.b64decode(b['deflate']),-15);assert H(v)==h==b['sha256'] and len(v)==b['count'];blobs[h]=v
 assert len(d['sources'])==5
 for s in d['sources']:
  b=(DEFAULT_SOURCE/s['path'].replace('\\','/')).read_bytes();assert len(b)==s['count'] and H(b)==s['sha256'] and blobs[s['sha256']]==b
 resource=next(s for s in ep.resources() if s['path']==[2,'MENU_BACK1',1028]);dib=exe[resource['fileOffset']:resource['fileOffset']+resource['size']]
 assert blobs[d['panelDIB']['dib']]==dib and struct.unpack_from('<ii',dib,4)==(d['panelDIB']['width'],d['panelDIB']['height'])
 originalInfo=(DEFAULT_SOURCE/'data/adinfo.txt').read_bytes();assert bytes(d['cases'][0]['spec']['panel']['info'])==originalInfo and not (DEFAULT_SOURCE/'data/ad0.txt').exists()
 pcs={};counts=Counter();events=Counter();helpers=Counter();stops=[];unknown=[];privateCaps=[];stageCounts=Counter();parts=path.with_suffix('.parts')
 assert len(list(parts.glob('*.json')))==len(d['cases'])==35
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i+1:04d}.json').read_bytes());assert part['case']==c and all(d['blobs'][h]==b for h,b in part['blobs'].items())
  assert blobs[c['initialGlobals']]==initialGlobals
  data=bytearray(initial);thread=bytearray(ptd);globals=bytearray(initialGlobals);alloc={};masks={}
  for w in c['stimulus']:
   o=w['address']-BASE;b=bytes.fromhex(w['bytes']);assert 0<=o<o+len(b)<=SIZE;globals[o:o+len(b)]=b
  assert blobs[c['beforeGlobals']]==globals and blobs[c['before']['data']]==data and blobs[c['before']['ptd']]==thread
  for p,h in c['instructions'].items():
   a=int(p,16);pe,image=(cp,dll) if a>=cp.base else (ep,exe);o=pe.offset(a-pe.base);b=bytes.fromhex(h);assert image[o:o+len(b)]==b,(p,h);pcs[p]=h
  for a in c['after']['allocations']:
   address=a['address'];assert any(e['kind']=='allocate' and e['address']==address and e['count']==a['count'] for e in c['events'])
   alloc[address]=bytearray(blobs[a['backing']]);masks[address]=bytearray(a['count']);counts['calendarAllocations']+=1
   assert alloc[address]==b'\xa5'*a['count']
  for w in c['stores']:
   address=w['address'];b=bytes.fromhex(w['bytes']);n=len(b)
   if w['pc'] is not None:assert hex(w['pc']) in c['instructions'];counts['originalCRTStores']+=1
   else:counts['CRTAdapterWrites']+=1
   if db<=address<address+n<=db+ds:data[address-db:address-db+n]=b
   elif PTD<=address<address+n<=PTD+len(thread):thread[address-PTD:address-PTD+n]=b
   elif any(a<=address<address+n<=a+len(v) for a,v in alloc.items()):
    a=next(a for a,v in alloc.items() if a<=address<address+n<=a+len(v));alloc[a][address-a:address-a+n]=b;masks[a][address-a:address-a+n]=b'\1'*n
   else:assert w['pc'] is None and STACK<=address<address+n<=STACK+0x10000
  after=c['after'];assert blobs[after['data']]==data and blobs[after['ptd']]==thread
  assert int.from_bytes(thread[0x14:0x18],'little')==c['spec']['milliseconds']
  assert after['timezone']==list(struct.unpack('<3I',data[0x781c1e10-db:0x781c1e1c-db])) and after['cache']==list(struct.unpack('<6I',data[0x781c1f64-db:0x781c1f7c-db]))
  assert blobs[after['names']]==data[0x781c1e20-db:0x781c1ea0-db]
  assert after['tmPointer']==int.from_bytes(thread[0x44:0x48],'little') and after['errno']==int.from_bytes(thread[8:12],'little')
  assert after['initialized']==int.from_bytes(data[0x781c44ac-db:0x781c44b0-db],'little') and after['osZone']==int.from_bytes(data[0x781c44a4-db:0x781c44a8-db],'little')
  for a in after['allocations']:assert blobs[a['bytes']]==alloc[a['address']] and blobs[a['mask']]==masks[a['address']]
  gm=bytearray(SIZE);prefix=[H(globals)]
  for w in c['globalStores']:
   o=w['address']-BASE;b=bytes.fromhex(w['bytes']);assert 0<=o<o+len(b)<=SIZE and 0<=w['eventIndex']<=len(c['events'])
   if w['pc'] is not None:assert hex(w['pc']) in c['instructions'];counts['originalGlobalStores']+=1
   else:counts['globalAdapterWrites']+=1
   globals[o:o+len(b)]=b;gm[o:o+len(b)]=b'\1'*len(b);prefix.append(H(globals))
  assert blobs[c['globals']]==globals and blobs[c['globalMask']]==gm
  # Every stage hash occurs in the continuous store prefix; exact event-side
  # ordering is separately compared natively. Same-index instructions are not
  # silently assigned to the earlier snapshot.
  for s in c['stages']:
   assert s['globals'] in prefix and int.from_bytes(blobs[s['crt']['ptd']][0x14:0x18],'little')==c['spec']['milliseconds'];stageCounts[s['name']]+=1
  stack=bytearray(0x10000);stack[0x8000:]=b'\xa5'*0x8000
  stack[0xf038:0xf04c]=struct.pack('<5I',0x30000000,c['spec'].get('instance',0x400000),0,0,c['spec'].get('show',10)&0xffffffff)
  checkpoints={s['stackStoreCount']:s for s in c['stages'] if s['name'] in ('panel-entry','panel-return')}
  for j,w in enumerate(c['stackStores']):
   if j in checkpoints:
    field='stackInitial' if checkpoints[j]['name']=='panel-entry' else 'stackAtReturn'
    assert bytes(stack[0xebac:0xeffc])==blobs[c['panel'][field]]
   if w['pc'] is not None:assert hex(w['pc']) in c['instructions'];counts['originalStackStores']+=1
   else:counts['stackAdapterWrites']+=1
   o=w['address']-STACK;b=bytes.fromhex(w['bytes']);assert 0<=o<o+len(b)<=len(stack);stack[o:o+len(b)]=b
  assert bytes(stack[0xebac:0xeffc])==blobs[c['panel']['stackAtStartupEnd']]
  # Platform WNDCLASS cursor is never written before fullscreen registration.
  for e in c['window']['events']:
   assert c['events'][e['rootEventIndex']]==dict(kind='window',event=e)
   r=e['request']
   if r['kind']=='registerClass' and not all(r['defined'][24:28]):
    address=0x1000efd8;prior=c['stackStores'][:e['stackStoreCount']]
    assert r['bytes'][24:28]==[0xa5]*4 and all(w['address']>=address+4 or w['address']+len(bytes.fromhex(w['bytes']))<=address for w in prior)
    unknown.append(dict(case=c['spec']['label'],kind='fullscreenCursor',rootEvents=e['rootEventIndex'],address=address,precedingWrites=0))
  for family in ('panel','input'):
   part=c[family]
   if part and part['ownBoundary']:
    b=part['ownBoundary'];assert prefix[b['globalStoreCount']]==b['rootGlobals']
    unknown.append(dict(case=c['spec']['label'],kind=family,offset=b['offset'],count=b['count'],rootEvents=b['rootEventCount']))
  if c['input']:
   for r in c['input']['capsReads']:
    assert hex(r['pc']) in c['instructions']
    if not r['known']:
     assert r['actualEarlierWriteMask']==[1]*r['count'] and r['count']==4
     last=r['lastStores'][-1];assert last in c['stackStores']
     producers={36:(0x78141727,'CRT security-cookie store'),40:(0x78141712,'saved CRT frame'),44:(0x781777b0,'CRT return address'),48:(0x781777a1,'private CRT FILE pointer')}
     pc,meaning=producers[r['offset']];assert last['pc']==pc and last['bytes']==r['bytes']
     privateCaps.append(dict(case=c['spec']['label'],reader=r['pc'],offset=r['offset'],bytes=r['bytes'],lastStore=last,provenance=meaning,nativeOwned=False))
   for l in c['input']['loads']:
    assert l['file']==next(s['sha256'] for s in d['sources'] if bytes(l['path']).decode()==s['path'])
    assert l['input']['destination']==0x45560c+4*c['input']['loads'].index(l)
    counts['waveCalls']+=1;counts['waveReturns']+=l['returned'] is not None
   for r in c['input']['helperReturns']:assert hex(r['entry']) in c['instructions'] and r['returnSP']==r['sp']+{0x401970:4,0x4014e0:8}[r['entry']];helpers['input']+=1
  if c['localInputs']:
   time=((c['spec']['filetime']-116444736000000000)%(2**64))//10000000;assert c['localInputs'][0]==time
   clock=next(e for e in c['provenance'] if e['kind']=='timeReturn');assert clock['ecx']==0 and clock['eax']+(clock['edx']<<32)==time
   period=struct.unpack('<i',globals[0x44d788-BASE:0x44d78c-BASE])[0];delta=(period*86400)%(2**32);delta-=2**32 if delta>=2**31 else 0
   if len(c['localInputs'])>1:assert c['localInputs'][1]==time+delta
  for f in c['formats']:
   fmt=bytes(f['format']);b=bytes(f['bytes']);assert f['result']==len(b)-1 and b[-1]==0
   if f['values']:
    assert fmt==b'%04d/%02d/%02d/%02d/%02d/%02d';assert b==(('%04d/%02d/%02d/%02d/%02d/%02d'%tuple(f['values'])).encode()+b'\0')
   else:assert fmt==b'%s\\graph.log' and b==b'\\graph.log\0'
   counts['formats']+=1
  music={};musicMasks={}
  for e in c['events']:
   events[e['kind']]+=1
   if e['kind']=='music':
    m=e['music']
    if m['kind']=='allocate' and m['response']['pointer']:
     a=m['response']['pointer'];assert a not in music;music[a]=bytearray(m['response']['bytes']);musicMasks[a]=bytearray(len(music[a]));counts['musicAllocations']+=1
    if m['kind']=='convert' and m['response']['bytes']:
     a=m['arguments'][3];b=bytes(m['response']['bytes']);music[a][:len(b)]=b;musicMasks[a][:len(b)]=b'\1'*len(b)
  for a in c['music']['allocations']:assert blobs[a['bytes']]==music[a['address']] and blobs[a['mask']]==musicMasks[a['address']]
  for h in c['returns']:assert hex(h['entry']) in c['instructions'];helpers[h['kind']]+=1
  for h in c['music']['calls']:assert hex(h['entry']) in c['instructions'] and h['returnSP']==h['entrySP']+4;helpers['music']+=1
  for h in c['window']['helpers']:assert hex(h['address']) in c['instructions'];helpers['window']+=1
  for h in c['panel']['children']:assert h['completed'] and hex(h['entry']) in c['instructions'];helpers['panel']+=1
  assert c['controlWord']==0x37f;counts[c['end']]+=1
  if c['end']=='startupBoundary':
   assert c['endPC']==0x43d100 and c['endSP']==0x1000effc and c['stages'][-1]['registers']==[0x78182153,0x7817775d,c['spec']['milliseconds'],0x30007500]
  else:
   if c['end']=='invalidParameter':assert c['boundaryPC']==0x78138a70 and after['errno']==22
   elif c['end']=='nullCalendarRead':assert c['boundaryPC'] in (0x43cfd3,0x43d028) and c['calendarResults'][-1]['pointer']==0
   else:assert c['end']=='invalidCreateContinuation' and c['boundaryPC']==0x40187a
   stops.append(dict(case=c['spec']['label'],end=c['end'],pc=c['boundaryPC']))
 assert pcs==d['instructions'] and counts['startupBoundary']==30 and len(stops)==5 and len(unknown)==7
 _,lib=unpack(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-lib-initialization.json');patches=lib['cases'][0]['patches'];assert len(patches)==13
 for p in patches:assert all(int(a,16)+len(bytes.fromhex(h))<=p['address'] or int(a,16)>=p['address']+p['count'] for a,h in pcs.items())
 static={}
 text=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel','--start-address=0x43cf40','--stop-address=0x43d100',str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True)
 for line in text.splitlines():
  m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
  if m:static[hex(int(m[1],16))]=dict(bytes=bytes.fromhex(m[2]).hex(),assembly=m[3])
 for p,h in pcs.items():
  if p in static:assert static[p]['bytes']==h
 pins=json.loads((ROOT/'build/research/winmain-startup-prior-pins.json').read_bytes());assert len(pins)==234
 for f,h in pins.items():assert H((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/f).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for f,m in v['files'].items():assert H((vendor/'vendor'/f).read_bytes())==m['vendoredSHA256']
 report=dict(sourceBytes=len(raw),sourceSHA256=H(raw),producerSHA256=d['producerSHA256'],cases=len(d['cases']),counts=dict(counts),events=dict(events),helperReturns=dict(helpers),stages=dict(stageCounts),sourceStops=stops,unknownProvenance=unknown,blobs=len(blobs),actualCRT=sum(int(p,16)>=0x78100000 for p in pcs),actualEXE=sum(int(p,16)<0x78100000 for p in pcs),callerStarts=len(static),executedCallerStarts=sum(p in pcs for p in static),unexecutedCaller=[dict(address=p,**s) for p,s in static.items() if p not in pcs],fullGlobalCRTPTDReconstruction=True,declaredPanelStackWindowReconstruction=True,calendarMusicAllocationReconstruction=True,privateCapabilityReads=privateCaps,oldFixturesUnchanged=234,vendorFiles=10,libPatchSitesDisjoint=13)
 if fixture:
  full,value=unpack(fixture);assert full==raw[:-1] and value==d;report.update(fixtureBytes=Path(fixture).stat().st_size,fixtureSHA256=H(Path(fixture).read_bytes()),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();report=audit(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
