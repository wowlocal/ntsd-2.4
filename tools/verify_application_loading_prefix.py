#!/usr/bin/env python3
"""Read-only own loading-prefix audit against pinned game bytes and parents.
Reconstruct full globals/stack/masks and source reads, normal SEH and WAV ABI;
verify unchanged retained resource/CRT/library/input ownership and ordinary
failure boundaries. No source execution or native/Windows/device/whole-loading
claim. APPLICATION_LOADING_PREFIX_PLAN.md; immutable raw/packed evidence.
"""
import argparse,base64,json,struct,zlib
from pathlib import Path
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from verify_menu_info_reading import unpack
from verify_application_menu_return import digest,key
BASE,FULL,STACK,SSIZE=0x44d000,0xc3a8,0x1000d000,0x2400

def validate(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert len(d['cases'])==12
 producer=(ROOT/'tools/oracle_application_loading_prefix.py').read_bytes();assert producer==path.with_name(path.stem+'-source.py').read_bytes()
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';_,old=unpack(fixtures/'original-application-menu-input.json')
 _,wave_parent=unpack(fixtures/'original-wave-loader.json');wave_pins={p['path']:p['sha256'] for p in wave_parent['sources']}
 assert set(d['parents'])=={key(c) for c in old['cases'][47:]}
 for h,c in d['parents'].items():assert h==key(c) and c in old['cases'][47:]
 for k in ('exeSHA256','crtSHA256','libSHA256'):assert d[k]==old[k]
 blobs={}
 for h,v in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and digest(b)==h==v['sha256'];blobs[h]=b
  if h in old['blobs']:assert v==old['blobs'][h]
 for p,a in d['assets'].items():assert old['assets'][p]==a
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(exe)==EXE_SHA256;pe=PE(exe)
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==12
 counts=Counter();events=Counter();ends=Counter();pcs={};waves=Counter();assets={}
 for i,c in enumerate(d['cases']):
  parent=d['parents'][c['parent']];assert parent==old['cases'][c['spec']['parentIndex']]
  part=json.loads((parts/f'{i:04d}.json').read_bytes());assert part['case']==c and part['parents'][-1]==parent
  bh,b,sh,sc,fh,fc,body,menu,p=part['parents']
  assert old['bitmapParents'][bh]==b and old['settingsParents'][sh]==sc and old['frontParents'][fh]==fc
  assert old['bodyParents'][key(body)]==body and old['menuParents'][key(menu)]==menu
  for h,v in part['blobs'].items():assert v==d['blobs'][h]
  for k in ('pc','sp','globals','stack','knownStack','cw','seh','registers','local','library','retainedDC','eax','baseline','counter','message','messageMask','random','records'):assert c['before'][k]==parent['after'][k],(i,k)
  assert c['crtBefore']==parent['crtAfter']==c['crtAfter']
  assert c['bodySP']==0x1000e43c and c['paused']==0 and all(blobs[h]==bytes(10) for h in c['commands'])
  assert c['before']['pc']==0x41bc90 and c['before']['sp']==0x1000ea6c
  assert c['before']['records']==c['after']['records']
  for k in ('library','retainedDC','counter','message','messageMask','random'):assert c['before'][k]==c['after'][k]
  for a,h in c['instructions'].items():
   pc=int(a,16);code=bytes.fromhex(h);off=pe.offset(pc-pe.base);assert exe[off:off+len(code)]==code,(i,a);pcs[a]=h
  assert '0x4450ac' not in c['instructions']
  # Later failed calls retain this PC from earlier successful waves; only the
  # first-wave rejection has never executed it in this continuation.
  if c['end']=='invalidCreateContinuation' and c['spec']['waveIndex']==0:assert '0x40187a' not in c['instructions']
  g=bytearray(blobs[c['before']['globals']]);gm=bytearray(FULL);stack=bytearray(blobs[c['before']['stack']]);known=bytearray(blobs[c['before']['knownStack']]);seh=c['before']['seh'];wi=0
  def advance(n):
   nonlocal wi,seh
   assert n>=wi
   while wi<n:
    w=c['writes'][wi];wi+=1;p=w['address'];b=bytes.fromhex(w['bytes']);size=len(b)
    if w['pc'] is not None:assert hex(w['pc']) in c['instructions'];counts['CPUStores']+=1
    else:counts['APIStores']+=1
    counts['storeBytes']+=size
    if BASE<=p<p+size<=BASE+FULL:g[p-BASE:p-BASE+size]=b;gm[p-BASE:p-BASE+size]=b'\1'*size
    elif STACK<=p<p+size<=STACK+SSIZE:stack[p-STACK:p-STACK+size]=b;known[p-STACK:p-STACK+size]=b'\1'*size
    elif p==0:assert size==4;seh=int.from_bytes(b,'little');counts['SEHStores']+=1
    else:assert any(base<=p<p+size<=base+0x2400000 for base in (0x60000000,0x64000000,0x68000000));counts['waveAPIBytes']+=size;assert w['pc'] is None
  checks=[(s['storeCount'],'state',s) for s in [c['before'],*[q['state'] for q in c['states']],c['after']]]
  checks += [(r['storeCount'],'read',r) for r in c['localReads']]
  checks += [(e['storeCount']-(e['kind']=='front' and e['event']['kind']=='write'),'event',e) for e in c['events']]
  for n,kind,q in sorted(checks,key=lambda t:t[0]):
   advance(n)
   if kind=='state':
    assert g==blobs[q['globals']] and gm==blobs[q['mask']] and stack==blobs[q['stack']] and known==blobs[q['knownStack']],(i,hex(q['pc']))
    assert seh==q['seh'] and q['cw']==0x37f;counts['states']+=1
    assert blobs[q['local']]==stack[0x1a74:0x1b34] and blobs[q['localMask']]==bytes(192)
    for record in q['records']:counts['bitmapRecords']+=1;counts['bitmapBytes']+=len(blobs[record['bytes']])
   elif kind=='read':
    p=q['address'];size=q['count'];assert bytes.fromhex(q['bytes'])==stack[p-STACK:p-STACK+size] and q['known']==list(known[p-STACK:p-STACK+size]);assert hex(q['pc']) in c['instructions'];counts['localReads']+=1;counts['localReadBytes']+=size
   else:
    assert g==blobs[q['globals']],(i,n,q['event']);events[q['event']['kind']]+=1
  advance(len(c['writes']))
  for wave_index,w in enumerate(c['loads']):
   p=w['input'];file=(DEFAULT_SOURCE/bytes(w['path']).decode().replace('\\','/')).read_bytes();assert blobs[w['file']]==file;assets[bytes(w['path']).decode()]=w['file']
   assert wave_pins[bytes(w['path']).decode()]==w['file']
   before=bytearray(blobs[w['beforeGlobals']]);after=blobs[w['afterGlobals']];off=p['destination']-BASE
   assert struct.unpack_from('<I',before,off)[0]==w['outputBefore'] and struct.unpack_from('<I',before,0x44eecc-BASE)[0]==p['device']
   before[off:off+4]=struct.pack('<I',w['outputAfter']);assert before==after
   if w['exit']=='returned':
    checkpoint=c['states'][wave_index+1]['state'];assert w['stackAfter']==w['entrySP']+8==checkpoint['sp'] and checkpoint['registers']==w['saved'] and checkpoint['pc']==w['returnPC'];counts['wholeWaveReturns']+=1
   else:assert c['end']==w['exit'] and p['createResult']==-1 and w['returned'] is None and not w['temporaryLive'];counts['rejectedCreateBoundaries']+=1
   waves[w['exit']]+=1;counts['retainedTemporaryAllocations']+=w['temporaryLive']
   for name in ('temporary','first','second','format','descriptor'):
    r=w[name]
    if r is None:continue
    b,m=blobs[r['bytes']],blobs[r['defined']];assert len(b)==len(m) and all(v<2 for v in m);counts['waveRecords']+=1;counts['waveBytes']+=len(b)
    if 'initial' in r:
     initial=blobs[r['initial']];assert len(initial)==len(b) and all(m[j] or b[j]==initial[j] for j in range(len(b)))
   for r in w['storage']:
    assert r['bytes'] in blobs and any(base<=r['address']<base+0x2400000 for base in (0x60000000,0x64000000,0x68000000))
  for h in c['helpers']:assert h['returnSP']==h['sp']+4+h['pop'];counts['otherHelperReturns']+=1
  ends[c['end']]+=1
  if c['end']=='catalogAllocation':assert len(c['loads'])==18 and c['after']['pc']==0x4450ac and c['catalogRequest']==dict(count=0x4d823a8,returnPC=0x41bff5,sp=0x1000e430)
  else:assert len(c['loads'])==c['spec']['waveIndex']+1 and c['after']['pc']==0x40187a and c['catalogRequest'] is None
 assert ends=={'catalogAllocation':9,'invalidCreateContinuation':3}
 pins=json.loads((ROOT/'build/research/application-loading-prefix-prior-pins.json').read_text());assert len(pins)==245
 for p,h in pins.items():assert digest((fixtures/p).read_bytes())==h
 report=dict(sourceBytes=len(raw),sourceSHA256=digest(raw),producerSHA256=digest(producer),cases=12,parents=3,ends=dict(ends),waves=dict(waves),counts=dict(counts),events=dict(events),actualEXE=len(pcs),actualDLL=0,actualCRT=0,blobs=len(blobs),bitmapAssets=len(d['assets']),waveAssets=assets,atomicParts=12,priorFixturesUnchanged=245,fullSourceStatesReconstructed=True,nativeCompared=False,windowsVerified=False)
 if fixture:
  payload,value=unpack(fixture);assert payload+b'\n'==raw and value==d;packed=Path(fixture).read_bytes();report.update(fixtureBytes=len(packed),fixtureSHA256=digest(packed),fullRawPackedBytesJSON=True)
 return report

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();r=validate(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps(r,indent=2))
