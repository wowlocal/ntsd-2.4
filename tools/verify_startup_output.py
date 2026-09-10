#!/usr/bin/env python3
"""Read-only reconstruction of whole startup dates/music/cursor evidence.
Pinned EXE/VC80 on controlled Unicorn CPU; audit actual bytes and stores, signed
expiry wrap, own time-to-tm stack provenance and distinct stopped NULL/invalid
parameter boundaries. No source execution, Windows, device or full app claim.
"""
import argparse,json,base64,zlib,hashlib,struct,subprocess,re
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack,DLL_SHA256
from verify_calendar_time import RANGES as CALENDAR_RANGES
H=lambda b:hashlib.sha256(b).hexdigest()
BASE,SIZE,PTD,MEM=0x44d000,0xb440,0x20000000,0x26000000
RANGES=[(0x43cfb4,0x43d078),(0x401c90,0x401e86),(0x401f30,0x4020f7),(0x4450b2,0x4450bb)]
def audit(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert raw.endswith(b'\n')
 assert H((ROOT/'tools/oracle_startup_output.py').read_bytes())==H(path.with_name(path.stem+'-source.py').read_bytes())==d['producerSHA256']
 for p,h in d['dependencies'].items():assert H((ROOT/'tools'/p).read_bytes())==h,p
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes();assert H(exe)==d['exeSHA256']==EXE_SHA256 and H(dll)==d['dllSHA256']==DLL_SHA256
 ep,cp=PE(exe),PE(dll);sec=next(s for s in cp.sections if s['name']=='.data');db=cp.base+sec['rva'];ds=sec['virtualSize'];assert (db,ds)==(d['dataAddress'],d['dataCount'])
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
 def literal(offset):return bytes(pebytes[offset:pebytes.index(0,offset)])
 assert literal(0x47744)==b'bgm\\main.wma' and literal(0x4a014)==b'%04d/%02d/%02d/%02d/%02d/%02d'
 blobs={}
 for h,b in d['blobs'].items():
  v=zlib.decompress(base64.b64decode(b['deflate']),-15);assert H(v)==h==b['sha256'] and len(v)==b['count'];blobs[h]=v
 _,lib=unpack(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-lib-initialization.json');assert len(lib['cases'][0]['patches'])==13
 for p in lib['cases'][0]['patches']:assert all(p['address']+p['count']<=a or p['address']>=b for a,b in RANGES)
 pcs={};counts=Counter();events=Counter();helpers=Counter();stops=[];musicReturns=Counter()
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==len(d['cases'])==51
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i+1:04d}.json').read_bytes());assert part['case']==c and all(d['blobs'][h]==b for h,b in part['blobs'].items())
  assert blobs[c['initialGlobals']]==initialGlobals
  data=bytearray(initial);thread=bytearray(ptd);alloc={};masks={};globals=bytearray(initialGlobals);music={};musicMasks={}
  for j,s in enumerate(c['steps']):
   assert s['input']==c['spec']['steps'][j]
   for w in s['stimulus']:
    b=bytes.fromhex(w['bytes']);o=w['address']-BASE;assert 0<=o<o+len(b)<=SIZE;globals[o:o+len(b)]=b
   assert blobs[s['beforeGlobals']]==globals and blobs[s['before']['data']]==data and blobs[s['before']['ptd']]==thread
   for p,h in s['instructions'].items():
    a=int(p,16);pe,image=(cp,dll) if a>=cp.base else (ep,exe);o=pe.offset(a-pe.base);b=bytes.fromhex(h);assert image[o:o+len(b)]==b,(p,h);pcs[p]=h
   for a in s['after']['allocations']:
    address=a['address']
    if address not in alloc:
     assert any(e['kind']=='allocate' and e['address']==address and e['count']==a['count'] for e in s['events'])
     alloc[address]=bytearray(blobs[a['backing']]);masks[address]=bytearray(a['count']);counts['calendarAllocations']+=1
     assert alloc[address]==(bytes(n%256 for n in range(a['count'])) if c['spec'].get('ramp') else b'\xa5'*a['count'])
   for store in s['stores']:
    address=store['address'];b=bytes.fromhex(store['bytes']);n=len(b)
    if store['pc'] is not None:assert hex(store['pc']) in s['instructions'];counts['originalCRTStores']+=1
    else:counts['CRTAdapterWrites']+=1
    if db<=address<address+n<=db+ds:data[address-db:address-db+n]=b
    elif PTD<=address<address+n<=PTD+len(thread):thread[address-PTD:address-PTD+n]=b
    elif any(a<=address<address+n<=a+len(v) for a,v in alloc.items()):
     a=next(a for a,v in alloc.items() if a<=address<address+n<=a+len(v));alloc[a][address-a:address-a+n]=b;masks[a][address-a:address-a+n]=b'\1'*n
    else:assert store['pc'] is None and 0x10000000<=address<address+n<=0x10010000
   after=s['after'];assert blobs[after['data']]==data and blobs[after['ptd']]==thread
   assert after['timezone']==list(struct.unpack('<3I',data[0x781c1e10-db:0x781c1e1c-db])) and after['cache']==list(struct.unpack('<6I',data[0x781c1f64-db:0x781c1f7c-db]))
   assert blobs[after['names']]==data[0x781c1e20-db:0x781c1ea0-db]
   assert after['tmPointer']==int.from_bytes(thread[0x44:0x48],'little') and after['errno']==int.from_bytes(thread[8:12],'little')
   assert after['initialized']==int.from_bytes(data[0x781c44ac-db:0x781c44b0-db],'little') and after['osZone']==int.from_bytes(data[0x781c44a4-db:0x781c44a8-db],'little')
   for a in after['allocations']:assert blobs[a['bytes']]==alloc[a['address']] and blobs[a['mask']]==masks[a['address']]
   gm=bytearray(SIZE)
   for w in s['globalStores']:
    o=w['address']-BASE;b=bytes.fromhex(w['bytes']);assert 0<=o<o+len(b)<=SIZE and 0<=w['eventIndex']<=len(s['events'])
    if w['pc'] is not None:assert hex(w['pc']) in s['instructions'];counts['originalGlobalStores']+=1
    else:counts['globalAdapterWrites']+=1
    globals[o:o+len(b)]=b;gm[o:o+len(b)]=b'\1'*len(b)
   assert blobs[s['globals']]==globals and blobs[s['globalMask']]==gm
   for w in s['stackStores']:
    if w['pc'] is not None:assert hex(w['pc']) in s['instructions'];counts['originalStackStores']+=1
    else:counts['stackAdapterWrites']+=1
   clock=next(e for e in s['provenance'] if e['kind']=='timeReturn');time=((s['input']['filetime']-116444736000000000)%(2**64))//10000000
   assert clock['ecx']==0 and clock['eax']+(clock['edx']<<32)==time and s['localInputs'][0]==time
   period=struct.unpack('<i',globals[0x44d788-BASE:0x44d78c-BASE])[0];delta=(period*86400)%(2**32);delta-=2**32 if delta>=2**31 else 0
   if len(s['localInputs'])>1:assert s['localInputs'][1]==time+delta
   if c['spec'].get('allocationFail'):
    p=next(e for e in s['provenance'] if e['kind']=='knownAllocatorReturn');entry=next(e for e in s['provenance'] if e['kind']=='tmEntry')
    assert entry['ecx']==0 and p['address']==entry['reserved']==0x1000efe4 and p['bytes']=='00000000'
    writes=[w for w in s['stackStores'] if w['address']==p['address']];assert writes[-1]['pc']==0x78181971 and writes[-1]['bytes']=='00000000'
    assert any(r['kind']=='local' and r['eax']==0 and r['returnPC']==0x43cfd3 for r in s['returns'])
   for f in s['formats']:
    fmt=bytes(f['format']);b=bytes(f['bytes']);assert f['result']==len(b)-1 and b[-1]==0
    if f['values']:
     assert fmt==b'%04d/%02d/%02d/%02d/%02d/%02d' and len(f['values'])==6
     assert b==(('%04d/%02d/%02d/%02d/%02d/%02d'%tuple(f['values'])).encode()+b'\0')
     index=0 if f['address']==0x451d48 else 1;tm=struct.unpack('<9i',bytes(s['calendarResults'][index]['bytes']))
     assert f['values']==[tm[5]+1900,tm[4]+1,tm[3],tm[2],tm[1],tm[0]]
    else:assert fmt==b'%s\\graph.log' and b.endswith(b'\\graph.log\0')
    counts['formats']+=1
   for e in s['events']:
    events[e['kind']]+=1
    if e['kind']=='music':
     m=e['music'];events['music-'+m['kind']]+=1
     if m['kind']=='allocate' and m['response']['pointer']:
      a=m['response']['pointer'];assert a not in music;music[a]=bytearray(m['response']['bytes']);musicMasks[a]=bytearray(len(music[a]));counts['musicAllocations']+=1
     if m['kind']=='convert' and m['response']['bytes']:
      a=m['arguments'][3];b=bytes(m['response']['bytes']);music[a][:len(b)]=b;musicMasks[a][:len(b)]=b'\1'*len(b)
   for a in s['musicAllocations']:assert blobs[a['bytes']]==music[a['address']] and blobs[a['mask']]==musicMasks[a['address']]
   for h in s['returns']:
    assert hex(h['entry']) in s['instructions'] and (hex(h['returnPC']) in s['instructions'] or h['returnPC']==s['endPC']);helpers[h['kind']]+=1
   for h in s['musicCalls']:
    assert hex(h['entry']) in s['instructions'] and hex(h['returnAddress']) in s['instructions'] and h['returnSP']==h['entrySP']+4;musicReturns[hex(h['entry'])]+=1
   assert s['controlWord']==0x37f;counts[s['end']]+=1
   if s['end']=='returned':
    assert s['endPC']==0x43d078 and s['endSP']==0x1000effc
    assert s['registers']==[0x78182153,0x7817775d,0x33445566,0x44556677]
    assert s['events'][-2]['kind']=='loadCursor' and s['events'][-2]['arguments']==[0,0x7f00]
    assert s['events'][-1]['kind']=='setCursor' and s['events'][-1]['arguments']==[s['events'][-2]['result']]
   else:
    assert j==len(c['steps'])-1
    if s['end']=='invalidParameter':assert s['boundaryPC']==0x78138a70 and after['errno']==22
    else:assert s['end']=='nullCalendarRead' and s['boundaryPC'] in (0x43cfd3,0x43d028) and s['calendarResults'][-1]['pointer']==0
    assert hex(s['boundaryPC']) not in s['instructions'];stops.append(dict(case=c['spec']['label'],inputs=s['localInputs'],end=s['end'],pc=s['boundaryPC']))
 assert pcs==d['instructions'] and counts['returned']==49 and len(stops)==9
 static={}
 for a,b in RANGES+CALENDAR_RANGES:
  image=ROOT/'build/original/crt/msvcr80.dll' if a>=0x78100000 else DEFAULT_SOURCE/'NTSD 2.4.exe'
  text=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel','--start-address='+hex(a),'--stop-address='+hex(b),str(image)],text=True)
  for line in text.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
   if m:static[hex(int(m[1],16))]=dict(bytes=bytes.fromhex(m[2]).hex(),assembly=m[3])
 for p,h in pcs.items():
  if p in static:assert static[p]['bytes']==h
 pins=json.loads((ROOT/'build/research/startup-output-prior-pins.json').read_bytes());assert len(pins)==233
 for f,h in pins.items():assert H((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/f).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for f,m in v['files'].items():assert H((vendor/'vendor'/f).read_bytes())==m['vendoredSHA256']
 report=dict(sourceBytes=len(raw),sourceSHA256=H(raw),producerSHA256=d['producerSHA256'],cases=len(d['cases']),counts=dict(counts),events=dict(events),helperReturns=dict(helpers),musicReturns=dict(musicReturns),sourceStops=stops,blobs=len(blobs),actualCRT=sum(int(p,16)>=0x78100000 for p in pcs),actualEXE=sum(int(p,16)<0x78100000 for p in pcs),staticStarts=len(static),executedStaticStarts=sum(p in pcs for p in static),callerStarts=sum(0x43cfb4<=int(p,16)<0x43d078 for p in static),executedCallerStarts=sum(0x43cfb4<=int(p,16)<0x43d078 for p in pcs),unexecutedStatic=[dict(address=p,**s) for p,s in static.items() if p not in pcs],fullGlobalDataPTDOwnedBufferReconstruction=True,oldFixturesUnchanged=233,vendorFiles=10,libPatchSitesDisjoint=13)
 if fixture:
  full,value=unpack(fixture);assert full==raw[:-1] and value==d;report.update(fixtureBytes=Path(fixture).stat().st_size,fixtureSHA256=H(Path(fixture).read_bytes()),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();report=audit(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k!='unexecutedStatic'},indent=2))
