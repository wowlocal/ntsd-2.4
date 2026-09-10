#!/usr/bin/env python3
"""Read-only audit of own queued input/repeated menu to actual loading entry.
Pinned original artifacts/Unicorn2.1.4 and declared callbacks/COM/clock responses.
Replay original stores into full globals/stack/masks/library/PTD/bitmap ownership;
verify ordinary SEH/ABI, actual rand, parent provenance and first41bc90 stop.
No source execution, expected edits, private native backing import or Windows/
worker/device/full-loading claim. See APPLICATION_MENU_INPUT_PLAN.md.
"""
import argparse,base64,json,struct,zlib
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack
from verify_application_menu_return import validate as validate_parent,digest,key
BASE,FULL,STACK,SSIZE,LOCAL,LSIZE,LIB,PTD,MSG=0x44d000,0xc3a8,0x1000d000,0x2400,0x1000ea74,0xc0,0x36000000,0x20000000,0x1000f01c

def validate(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert len(d['cases'])==50
 producer=(ROOT/'tools/oracle_application_menu_input.py').read_bytes();assert producer==path.with_name(path.stem+'-source.py').read_bytes()
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';parent_report=validate_parent(ROOT/'build/research/application-menu-return-candidate1.json',fixtures/'original-application-menu-return.json');_,old=unpack(fixtures/'original-application-menu-return.json')
 assert set(d['menuParents'])=={key(c) for c in old['cases'] if c['end']=='iteration'}
 for h,c in d['menuParents'].items():assert h==key(c) and c in old['cases']
 for name in ('bodyParents','frontParents','settingsParents','bitmapParents','assets'):
  for h,v in d[name].items():assert old[name][h]==v
 for name in ('installation','libraryInitial','libraryAllocations','exeSHA256','crtSHA256','libSHA256'):assert d[name]==old[name]
 blobs={}
 for h,v in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and digest(b)==h==v['sha256'];blobs[h]=b
  if h in old['blobs']:assert v==old['blobs'][h]
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes();assert digest(exe)==EXE_SHA256 and digest(dll)==d['crtSHA256'];pe,cp=PE(exe),PE(dll);patched=bytearray(exe)
 for p in d['installation']['patches']:
  off=pe.offset(p['address']-pe.base);assert exe[off:off+p['count']].hex()==p['before'];patched[off:off+p['count']]=bytes.fromhex(p['after'])
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==50
 counts=Counter();events=Counter();pcs={};helperCounts=Counter();ends=Counter();localPCs=Counter()
 for i,c in enumerate(d['cases']):
  parent=d['menuParents'][c['parent']];body=d['bodyParents'].get(parent['parent']);front=d['frontParents'][body['parent'] if body else parent['parent']];settings=d['settingsParents'][front['parent']];bitmap=d['bitmapParents'][settings['parent']]
  part=json.loads((parts/f'{i:04d}.json').read_bytes());assert part['case']==c and part['menuParent']==parent and part['bodyParent']==body and part['frontParent']==front and part['settingsParent']==settings and part['bitmapParent']==bitmap
  for h,v in part['blobs'].items():assert d['blobs'][h]==v
  for h,v in part['assets'].items():assert d['assets'][h]==v
  for k in ('pc','sp','globals','stack','knownStack','cw','seh','registers','local','library','retainedDC','eax','baseline','counter'):assert c['before'][k]==parent['after'][k],(i,k)
  assert c['crtBefore']==parent['crtAfter'];assert c['before']['counter']==2 and c['before']['baseline']==123456822
  assert c['before']['records']==[dict(r,live=True) for r in parent['records']]
  bind={b['address']:b['after'] for b in c['bindings']};assert len(bind)==5 and bind[0x447198]==0x7816d5f0 and bind[0x44717c]==0x3000e030
  assert set(bind.values())=={0x3000e000,0x3000e010,0x3000e020,0x3000e030,0x7816d5f0}
  assert c['soundBuffers']==[603983872+16*n for n in range(5)]
  for a,h in c['instructions'].items():
   pc=int(a,16);b=bytes.fromhex(h)
   if LIB<=pc<LIB+0x5000:expected=blobs[d['libraryInitial']][pc-LIB:pc-LIB+len(b)]
   elif cp.base<=pc<cp.base+0x100000:off=cp.offset(pc-cp.base);expected=dll[off:off+len(b)]
   else:off=pe.offset(pc-pe.base);expected=patched[off:off+len(b)]
   assert b==expected,(i,a);pcs[a]=h
  assert '0x41bc90' not in c['instructions'] and '0x78132e29' not in c['instructions']
  g=bytearray(blobs[c['before']['globals']]);gm=bytearray(FULL);stack=bytearray(blobs[c['before']['stack']]);known=bytearray(blobs[c['before']['knownStack']]);lm=bytearray(LSIZE);lib=bytearray(blobs[c['before']['library']]);ptd=bytearray(blobs[c['crtBefore']['ptd']]);seh=c['before']['seh'];mm=bytearray(blobs[c['before']['messageMask']]);records={v['address']:[bytearray(blobs[v['bytes']]),bytearray(blobs[v['mask']]),True] for v in c['before']['records']};wi=0
  def write(w):
   nonlocal seh
   p=w['address'];b=bytes.fromhex(w['bytes']);n=len(b)
   if w['pc'] is None:counts['APIStores']+=1
   else:assert hex(w['pc']) in c['instructions'];counts['CPUStores']+=1
   counts['storeBytes']+=n
   if BASE<=p<p+n<=BASE+FULL:g[p-BASE:p-BASE+n]=b;gm[p-BASE:p-BASE+n]=b'\1'*n
   elif STACK<=p<p+n<=STACK+SSIZE:
    stack[p-STACK:p-STACK+n]=b;known[p-STACK:p-STACK+n]=b'\1'*n
    if LOCAL<=p<p+n<=LOCAL+LSIZE:lm[p-LOCAL:p-LOCAL+n]=b'\1'*n
    if MSG<=p<p+n<=MSG+28:mm[p-MSG:p-MSG+n]=b'\1'*n
   elif p==0:assert n==4;seh=int.from_bytes(b,'little');counts['SEHStores']+=1
   elif p==LIB+0x306e:assert n==4;lib[p-LIB:p-LIB+n]=b;counts['libraryDCStores']+=1
   elif p==PTD+0x14:assert n==4;ptd[0x14:0x18]=b;counts['CRTSeedStores']+=1
   else:assert p in records and n==4;records[p][0][:4]=b;records[p][1][:4]=b'\1'*4;counts['bitmapSurfaceClears']+=1
  def advance(n):
   nonlocal wi
   assert n>=wi
   while wi<n:write(c['writes'][wi]);wi+=1
  checks=[]
  for e in c['events']:
   kind=e.get('event',{}).get('kind');checks.append((e['storeCount']-(kind in ('write','writeLocal')),'event',e))
  for read in c['localReads']:checks.append((read['storeCount'],'read',read))
  states=[c['before'],c['after']]+[q['state'] for q in c['states']]+[s for q in c['iterations'] for s in (q['before'],q['after'])]+[s for q in c['callbacks'] for s in (q['before'],q['after'])]+[q['after'] for q in c['abiReturns']]
  for s in states:checks.append((s['storeCount'],'state',s))
  current=None
  for n,kind,q in sorted(checks,key=lambda x:x[0]):
   advance(n)
   if kind=='state':
    assert g==blobs[q['globals']] and gm==blobs[q['mask']] and stack==blobs[q['stack']] and known==blobs[q['knownStack']],(i,hex(q['pc']))
    assert lib==blobs[q['library']] and lm==blobs[q['localMask']] and stack[LOCAL-STACK:LOCAL-STACK+LSIZE]==blobs[q['local']]
    assert seh==q['seh'] and q['cw']==0x37f and int.from_bytes(ptd[0x14:0x18],'little')==q['random']
    assert stack[MSG-STACK:MSG-STACK+28]==blobs[q['message']] and mm==blobs[q['messageMask']]
    assert struct.unpack_from('<I',g,0x458580-BASE)[0]==q['counter'] and struct.unpack_from('<I',lib,0x306e)[0]==q['retainedDC']
    for r in q['records']:
     b,m,live=records[r['address']];assert b==blobs[r['bytes']] and m==blobs[r['mask']] and live==r['live'];counts['recordComparisons']+=1;counts['recordBytes']+=len(b)
    counts['stateCheckpoints']+=1
   elif kind=='read':
    p=q['address'];n=q['count'];off=p-LOCAL;assert bytes.fromhex(q['bytes'])==stack[p-STACK:p-STACK+n] and q['written']==list(lm[off:off+n]) and q['known']==list(known[p-STACK:p-STACK+n]);assert hex(q['pc']) in c['instructions'];localPCs[hex(q['pc'])]+=1;counts['localReads']+=1;counts['localReadBytes']+=n
   else:
    assert g==blobs[q['globals']],(i,n,q['kind']);e=q.get('event');name=e['kind'] if e else q['request']['kind'];events[name]+=1
    if e:
     if name=='draw':current=records[e['arguments'][0]]
     elif name=='read':
      r=e['read'];assert struct.unpack_from('<I',current[0],r['offset'])[0]==r['value'] and all(current[1][r['offset']:r['offset']+4])==r['defined'];counts['undefinedBitmapReads']+=not r['defined']
     elif name=='free':assert records[e['arguments'][0]][2];records[e['arguments'][0]][2]=False;counts['freedBackgrounds']+=1
     elif name=='clear':assert sum(e['effects'][0]['defined'])==8;counts['unknownFillBytes']+=92
     elif name=='fill':assert sum(e['fill']['defined'])==8;counts['unknownFillBytes']+=92
     elif name=='soundMethod':assert e['arguments'][0] in c['soundBuffers']
    elif q['request']['message'] is not None:
     assert bytes(q['request']['message'])==stack[MSG-STACK:MSG-STACK+28] and q['request']['defined']==[bool(x) for x in mm]
  advance(len(c['writes']));assert ptd==blobs[c['crtAfter']['ptd']]
  for k,v in c['crtBefore'].items():
   if k!='ptd':assert v==c['crtAfter'][k]
  random=c['before']['random']
  for call in c['randomCalls']:
   assert call['before']==random;random=(random*0x343fd+0x269ec3)&0xffffffff;assert call['after']==random and call['result']==(random>>16)&0x7fff;counts['actualRandomCalls']+=1
  assert random==c['after']['random']
  for h in c['helpers']:assert h['returnSP']==h['sp']+4+h['pop'] and hex(h['entry']) in c['instructions'];helperCounts[hex(h['entry'])]+=1
  for q in c['abiReturns']:
   a,s=q['entry'],q['after'];assert s['sp']==a['sp']+(8 if s['pc']==0x43ecbf else 4) and s['registers']==a['saved'] and s['seh']==a['seh'];counts['actualABIReturns']+=1
  for q in c['callbacks']:assert q['entrySP']==q['dispatchSP']-20 and q['after']['sp']==q['dispatchSP'] and q['after']['registers']==q['saved'] and q['result']==0xffffff85;counts['wholeCallbacks']+=1
  ends[c['end']]+=1;counts['completeIterations']+=sum(q['end']=='continued' for q in c['iterations'])
  if i<47:assert c['end']=='iterations' and c['after']['counter']==3 and len(c['iterations'])==1 and not c['callbacks'] and not c['randomCalls']
  else:
   assert c['end']=='loading' and c['after']['pc']==0x41bc90 and c['after']['sp']==LOCAL-8 and c['after']['counter']==7
   assert len(c['iterations'])==6 and len(c['callbacks'])==3 and len(c['randomCalls'])==3000
   assert struct.unpack_from('<I',g,0x458b00-BASE)[0]==2 and not c['pending'];counts['loadingEntries']+=1
 assert ends=={'iterations':47,'loading':3}
 pins=json.load(open(ROOT/'build/research/application-menu-input-prior-pins.json'));assert len(pins)==244
 for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h
 report=dict(sourceBytes=len(raw),sourceSHA256=digest(raw),producerSHA256=digest(producer),cases=50,menuParents=47,bodyParents=len(d['bodyParents']),frontParents=len(d['frontParents']),settingsParents=len(d['settingsParents']),bitmapParents=len(d['bitmapParents']),counts=dict(counts),events=dict(events),helpers=dict(helperCounts),actualEXE=sum(int(a,16)<LIB for a in pcs),actualDLL=sum(LIB<=int(a,16)<LIB+0x5000 for a in pcs),actualCRT=sum(int(a,16)>0x78000000 for a in pcs),localReadPCs=dict(localPCs),blobs=len(blobs),assets=len(d['assets']),atomicParts=50,priorFixturesUnchanged=244,vendorFiles=10,parentVerificationSHA256=digest(json.dumps(parent_report,sort_keys=True).encode()),fullSourceStatesReconstructed=True,ownParentsRetained=True,workerBodyExecuted=False,loadingBodyExecuted=False,windowsVerified=False)
 if fixture:
  payload,value=unpack(fixture);assert payload+b'\n'==raw and value==d;p=Path(fixture).read_bytes();report.update(fixtureBytes=len(p),fixtureSHA256=digest(p),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();r=validate(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps({k:v for k,v in r.items() if k!='localReadPCs'},indent=2))
