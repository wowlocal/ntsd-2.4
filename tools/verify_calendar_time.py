#!/usr/bin/env python3
"""Read-only audit of original startup calendar evidence and native boundaries.
Pinned VC80/EXE, declared environment/PTD/timezone/allocator inputs; reconstruct
all recorded data/PTD/owned-buffer writes. No Windows or private native CRT ABI
claim. Invalid-parameter and unknown allocation-return stops remain separate.
"""
import argparse,json,base64,zlib,hashlib,struct,subprocess,re,datetime
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack,DLL_SHA256
H=lambda b:hashlib.sha256(b).hexdigest()
PTD,MEM=0x20000000,0x26000000
RANGES=[(0x78182857,0x78182893),(0x78182153,0x78182177),(0x78181e8e,0x78182153),(0x781819dd,0x78181c19),(0x78181971,0x781819b9),(0x78148b84,0x78148ecd),(0x78148ecd,0x78149298),(0x78149298,0x781492e7),(0x7814931f,0x78149360)]
def audit(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert raw.endswith(b'\n')
 transitions=d.get('variant')=='transitions';producer='oracle_calendar_transitions.py' if transitions else 'oracle_calendar_time.py'
 assert H((ROOT/'tools'/producer).read_bytes())==H(path.with_name(path.stem+'-source.py').read_bytes())==d['producerSHA256']
 for p,h in d['dependencies'].items():assert H((ROOT/'tools'/p).read_bytes())==h,p
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes();assert H(exe)==d['exeSHA256']==EXE_SHA256 and H(dll)==d['dllSHA256']==DLL_SHA256
 pe=PE(dll);sec=next(s for s in pe.sections if s['name']=='.data');db=pe.base+sec['rva'];ds=sec['virtualSize'];assert (db,ds)==(d['dataAddress'],d['dataCount'])
 initial=bytearray(ds);initial[:sec['fileSize']]=dll[sec['fileOffset']:sec['fileOffset']+sec['fileSize']]
 # _initptd's actual C-locale reference increments, before the studied calls;
 # empty/supplied ASCII environment array is the explicit controlled boundary.
 for address in [0x781c13d8,0x781c19f8,0x781c1f5c]:
  o=address-db;initial[o:o+4]=(int.from_bytes(initial[o:o+4],'little')+1).to_bytes(4,'little')
 initial[0x781c37e0-db:0x781c37e4-db]=(MEM+0x1000).to_bytes(4,'little')
 ptd=bytearray(0x200)
 for o,v in [(0x5c,0x781c1958),(0x14,1),(0x70,1),(0x68,0x781c13d8),(0x6c,0x781c19f8)]:ptd[o:o+4]=v.to_bytes(4,'little')
 ptd[0xc8]=ptd[0x14b]=0x43
 blobs={}
 for h,b in d['blobs'].items():
  v=zlib.decompress(base64.b64decode(b['deflate']),-15);assert H(v)==h==b['sha256'] and len(v)==b['count'];blobs[h]=v
 pcs={};counts=Counter();events=Counter();helpers=Counter();stops=[];definedBytes=0
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==len(d['cases'])==(11 if transitions else 40)
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i+1:04d}.json').read_bytes());assert part['case']==c and all(d['blobs'][h]==b for h,b in part['blobs'].items())
  data=bytearray(initial);thread=bytearray(ptd);alloc={};masks={};output=bytearray(b'\xa5'*8);outmask=bytearray(8)
  for j,s in enumerate(c['steps']):
   assert s['kind']==c['spec']['steps'][j][0] and s['value']==c['spec']['steps'][j][1]
   assert blobs[s['before']['data']]==data and blobs[s['before']['ptd']]==thread
   for p,h in s['instructions'].items():
    a=int(p,16);o=pe.offset(a-pe.base);b=bytes.fromhex(h);assert dll[o:o+len(b)]==b,(p,h);pcs[p]=h
   for a in s['after']['allocations']:
    address=a['address']
    if address not in alloc:
     assert any(e['kind']=='allocate' and e['address']==address and e['count']==a['count'] for e in s['events'])
     alloc[address]=bytearray(blobs[a['backing']]);masks[address]=bytearray(a['count']);counts['allocations']+=1
     assert alloc[address]==(bytes(n%256 for n in range(a['count'])) if c['spec'].get('ramp') else b'\xa5'*a['count'])
   for store in s['stores']:
    address=store['address'];b=bytes.fromhex(store['bytes']);n=len(b)
    if store['pc'] is not None:assert hex(store['pc']) in s['instructions'];counts['originalStores']+=1
    else:counts['adapterWrites']+=1
    if db<=address<address+n<=db+ds:data[address-db:address-db+n]=b
    elif PTD<=address<address+n<=PTD+len(thread):thread[address-PTD:address-PTD+n]=b
    elif MEM+0x200<=address<address+n<=MEM+0x208:
     output[address-MEM-0x200:address-MEM-0x200+n]=b;outmask[address-MEM-0x200:address-MEM-0x200+n]=b'\1'*n
    elif any(a<=address<address+n<=a+len(v) for a,v in alloc.items()):
     a=next(a for a,v in alloc.items() if a<=address<address+n<=a+len(v));alloc[a][address-a:address-a+n]=b;masks[a][address-a:address-a+n]=b'\1'*n
    else:
     assert store['pc'] is None and 0x10000000<=address<address+n<=0x10010000
     counts['privateStackAPIWrites']+=1
   after=s['after'];assert blobs[after['data']]==data and blobs[after['ptd']]==thread
   assert after['timezone']==list(struct.unpack('<3I',data[0x781c1e10-db:0x781c1e1c-db]))
   assert after['cache']==list(struct.unpack('<6I',data[0x781c1f64-db:0x781c1f7c-db]))
   assert blobs[after['names']]==data[0x781c1e20-db:0x781c1ea0-db]
   assert after['tmPointer']==int.from_bytes(thread[0x44:0x48],'little') and after['errno']==int.from_bytes(thread[8:12],'little')
   assert after['initialized']==int.from_bytes(data[0x781c44ac-db:0x781c44b0-db],'little') and after['osZone']==int.from_bytes(data[0x781c44a4-db:0x781c44a8-db],'little')
   for a in after['allocations']:
    assert blobs[a['bytes']]==alloc[a['address']] and blobs[a['mask']]==masks[a['address']]
    definedBytes+=sum(masks[a['address']])
   for e in s['events']:events[e['kind']]+=1
   for h in s['returns']:
    assert hex(h['entry']) in s['instructions'] and (hex(h['returnPC']) in s['instructions'] or h['returnPC']==0x30000000);helpers[h['kind']]+=1
   assert s['controlWord']==0x37f;counts[s['end']]+=1;counts[s['kind']+'Calls']+=1
   if s['end']=='returned':
    assert s['endPC']==0x30000000 and s['endSP']==0x1000f004
    if s['kind']=='time':
     ticks=c['spec']['filetime'];value=((ticks-116444736000000000)%(2**64))//10000000
     assert value==s['eax']+(s['edx']<<32) and bytes.fromhex(s['output'])==output and s['outputMask']==list(outmask)
     assert output==(value.to_bytes(8,'little') if c['spec']['output'] else b'\xa5'*8)
    elif s['eax']:assert s['eax']==after['tmPointer'] and len(alloc[s['eax']])==36 and all(masks[s['eax']])
    else:assert after['errno']==22 and alloc[after['tmPointer']]==b'\xff'*36
   else:
    assert j==len(c['steps'])-1
    if s['end']=='invalidParameter':assert s['boundaryPC']==0x78138a70 and after['errno']==22
    else:assert s['end']=='unknownAllocatorReturn' and s['boundaryPC']==0x781819ad and s['unknown']['count']==4 and after['errno']==12
    stops.append(dict(case=c['spec']['label'],value=s['value'],end=s['end'],pc=s['boundaryPC'],unknown=s['unknown']))
  if transitions:
   assert len(c['boundaries'])==18 and len(c['steps'])==99
   for k,b in enumerate(c['boundaries']):
    yearStart=int((datetime.datetime(b['year'],1,1)-datetime.datetime(1970,1,1)).total_seconds());edge=yearStart+(b['standardMilliseconds']+999)//1000+b['standardOffset']
    assert b['inputSeconds']==[edge+n for n in [-2,-1,0,1,2]]
    baseline=c['steps'][(k//2)*11]['after'];index=b['index'];assert index==k%2
    assert baseline['cache'][index*3]==b['year']-1900 and baseline['cache'][index*3+1]*86400000+baseline['cache'][index*3+2]==b['standardMilliseconds']
    assert (baseline['timezone'][0]-(2**32 if baseline['timezone'][0]>=2**31 else 0))==b['standardOffset']
    rows=c['steps'][(k//2)*11+1+index*5:(k//2)*11+6+index*5];assert [s['value'] for s in rows]==b['inputSeconds']
    outputs=[]
    for s in rows:
     a=next(a for a in s['after']['allocations'] if a['address']==s['eax']);outputs.append(int.from_bytes(blobs[a['bytes']][32:36],'little'))
    assert outputs==b['isDST']==([0,0,1,1,1] if index==0 else [1,1,0,0,0])
 assert pcs==d['instructions'] and counts['returned']==(1089 if transitions else 9755) and len(stops)==(0 if transitions else 3)
 static={}
 for a,b in RANGES:
  text=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel','--start-address='+hex(a),'--stop-address='+hex(b),str(ROOT/'build/original/crt/msvcr80.dll')],text=True)
  for line in text.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
   if m:static[hex(int(m[1],16))]=dict(bytes=bytes.fromhex(m[2]).hex(),assembly=m[3])
 for p,h in pcs.items():
  if p in static:assert static[p]['bytes']==h
 pins=json.loads((ROOT/'build/research/calendar-time-prior-pins.json').read_bytes());assert len(pins)==231
 for f,h in pins.items():assert H((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/f).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for f,m in v['files'].items():assert H((vendor/'vendor'/f).read_bytes())==m['vendoredSHA256']
 report=dict(sourceBytes=len(raw),sourceSHA256=H(raw),producerSHA256=d['producerSHA256'],cases=len(d['cases']),counts=dict(counts),events=dict(events),helperReturns=dict(helpers),sourceStops=stops,blobs=len(blobs),actualCRT=len(pcs),actualEXE=0,staticCalendarStarts=len(static),executedCalendarStarts=sum(p in pcs for p in static),unexecutedStatic=[dict(address=p,**s) for p,s in static.items() if p not in pcs],sourceDefinedAllocationSnapshotBytes=definedBytes,fullDataPTDOwnedBufferReconstruction=True,oldFixturesUnchanged=231,vendorFiles=10)
 if fixture:
  full,value=unpack(fixture);assert full==raw[:-1] and value==d;report.update(fixtureBytes=Path(fixture).stat().st_size,fixtureSHA256=H(Path(fixture).read_bytes()),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();report=audit(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
