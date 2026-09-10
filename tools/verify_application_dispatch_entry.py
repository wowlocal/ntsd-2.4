#!/usr/bin/env python3
"""Read-only own dispatcher/staticWorld evidence verification.
Pinned NTSD EXE/VC80/resources, recorded Unicorn2.1.4 and declared Win32/COM.
Reconstruct full globals and original stack from continuous startup/loop stores;
keep native owned fields separate from opaque private stack bytes. Verify the
unreturned allocation boundary and normal SEH prologues, without mutation or
execution. No full dispatcher, CRT loader, Windows/device or game claim.
"""
import argparse,base64,hashlib,json,struct,zlib
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack

def digest(b):return hashlib.sha256(b).hexdigest()
BASE,SIZE,FULL,OUTER,OSIZE,STACK,SSIZE=0x44d000,0xb440,0xc3a8,0x458440,0x854,0x1000e800,0x900

def validate(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert raw.endswith(b'\n') and len(d['cases'])==8
 producer=(ROOT/'tools/oracle_application_dispatch_entry.py').read_bytes();assert producer==path.with_name(path.stem+'-source.py').read_bytes()
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(exe)==d['exeSHA256']==EXE_SHA256;pe=PE(exe);image=bytearray(0x100000)
 for s in pe.sections:
  if s['name']!='.rsrc':image[s['rva']:s['rva']+s['fileSize']]=exe[s['fileOffset']:s['fileOffset']+s['fileSize']]
 initial=bytes(image[BASE-pe.base:BASE-pe.base+FULL]);initialOuter=initial[SIZE:SIZE+OSIZE]
 assert initial[SIZE:]==bytes(FULL-SIZE) and d['stackAddress']==STACK and d['stackCount']==SSIZE
 blobs={}
 for h,b in d['blobs'].items():
  value=zlib.decompress(base64.b64decode(b['deflate']),-15);assert len(value)==b['count'] and digest(value)==h==b['sha256'];blobs[h]=value
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
 _,startup=unpack(fixtures/'original-winmain-startup.json');_,accepted=unpack(fixtures/'original-application-message-loop.json')
 assert len(d['parents'])==1 and d['parents']==accepted['parents'] and len(d['loops'])==2
 for h,p in d['parents'].items():
  assert digest(json.dumps(p,sort_keys=True,separators=(',',':')).encode())==h and p==startup['cases'][0]
 def retained(v,old):
  if isinstance(v,dict):
   for x in v.values():retained(x,old)
  elif isinstance(v,list):
   for x in v:retained(x,old)
  elif isinstance(v,str) and v in old['blobs']:assert d['blobs'][v]==old['blobs'][v]
 retained(d['parents'],startup)
 own=next(c for c in accepted['cases'] if c['spec']['label']=='own-required-dispatch')
 assert own in d['loops'].values();retained(own,accepted)
 allpcs={};newpcs={};counts=Counter()
 def instructions(pcs):
  for a,h in pcs.items():
   pc=int(a,16);b=bytes.fromhex(h);off=pe.offset(pc-pe.base);assert exe[off:off+len(b)]==b,(a,h);allpcs[a]=h
 def apply(record,mask,w,base):
  b=bytes.fromhex(w['bytes']);off=w['address']-base;assert 0<=off<off+len(b)<=len(record)
  record[off:off+len(b)]=b;mask[off:off+len(b)]=b'\1'*len(b)
 for lkey,l in d['loops'].items():
  assert digest(json.dumps(l,sort_keys=True,separators=(',',':')).encode())==lkey
  assert not l['stimulus'] and len(l['iterations'])==2 and l['end']=='requiredDispatcher' and l['controlWord']==0x37f
  p=d['parents'][l['parent']];g=bytearray(blobs[p['globals']]);o=bytearray(initialOuter);gm=bytearray(SIZE);om=bytearray(OSIZE)
  assert blobs[l['initialOuter']]==o and blobs[l['before']['globals']]==g and blobs[l['before']['outer']]==o
  assert l['before']['baseline']==p['spec']['milliseconds'] and l['before']['counter']==0
  msg=bytearray(b'\xa5'*28);mm=bytearray(28);gi=oi=0
  assert blobs[l['before']['message']]==msg and blobs[l['before']['messageMask']]==mm
  instructions(l['instructions'])
  def stores(at):
   nonlocal gi,oi
   for field,b,m,base,index in [('globalStores',g,gm,BASE,gi),('outerStores',o,om,OUTER,oi)]:
    while index<len(l[field]) and l[field][index]['eventIndex']<=at:
     w=l[field][index];assert hex(w['pc']) in l['instructions'];apply(b,m,w,base);index+=1
    if field=='globalStores':gi=index
    else:oi=index
  for index,e in enumerate(l['events']):
   stores(index);assert blobs[e['globals']]==g and blobs[e['outer']]==o
   q=e['request']
   if q['message'] is not None:assert bytes(q['message'])==msg and bytes(q['defined'])==mm
   if q['kind'] in ('peek','get'):
    for w in e['response']['writes']:
     off=w['offset'];b=bytes(w['bytes']);msg[off:off+len(b)]=b;mm[off:off+len(b)]=b'\1'*len(b)
   if e['response'] is None:assert index==len(l['events'])-1 and q['kind']=='gameDispatch'
   stores(index+1)
   for step in l['iterations']:
    if step['after']['events']==index+1:
     a=step['after'];assert blobs[a['globals']]==g and blobs[a['outer']]==o and blobs[a['message']]==msg and blobs[a['messageMask']]==mm
  assert gi==len(l['globalStores']) and oi==len(l['outerStores']) and blobs[l['globalMask']]==gm and blobs[l['outerMask']]==om
  a=l['after'];assert blobs[a['globals']]==g and blobs[a['outer']]==o and a['pc']==0x43e9a0 and a['sp']==0x1000eff4 and a['counter']==1 and a['baseline']==123456822
  assert len(l['callbacks'])==1;cb=l['callbacks'][0];assert cb['input']['message']==5 and cb['input']['wParam'] in (0,1)
  assert cb['returnSP']==cb['dispatchSP']==cb['entrySP']+20 and cb['registers']==cb['saved']
  assert l['events'][-1]['request']['arguments']==[0 if cb['input']['wParam']==1 else 1]
  assert l['iterations'][0]['end']=='continued' and l['iterations'][1]['before']==l['iterations'][0]['after']
  counts['distinctLoopStackStores']+=len(l['stackStores'])
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==8
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i:04d}.json').read_bytes());assert part['case']==c and part['parent']==d['parents'][c['parent']] and part['loop']==d['loops'][c['loop']]
  assert all(d['blobs'][h]==b for h,b in part['blobs'].items())
  p=d['parents'][c['parent']];l=d['loops'][c['loop']];before=c['before'];after=c['after'];instructions(c['instructions']);newpcs.update(c['instructions'])
  assert c['crtAfter']==p['after'] and before['cw']==after['cw']==0x37f
  g=bytearray(blobs[l['after']['globals']]+initial[SIZE:]);g[SIZE:SIZE+OSIZE]=blobs[l['after']['outer']];gm=bytearray(FULL)
  assert blobs[before['globals']]==g and before['pc']==0x43e9a0 and before['sp']==0x1000eff4
  assert before['registers']['esi']==l['after']['baseline'] and blobs[before['world']]==bytes(0x7d8)
  si=0
  for index,e in enumerate(c['events']):
   while si<len(c['stores']) and c['stores'][si]['eventIndex']<=index:
    w=c['stores'][si];assert hex(w['pc']) in c['instructions'];apply(g,gm,w,BASE);si+=1
   snapshot=e['event']['fullGlobals'] if e['kind']=='surface' else e['fullGlobals'];assert blobs[snapshot]==g
  assert si==len(c['stores'])==6 and blobs[after['globals']]==g and blobs[c['mask']]==gm
  assert [(w['address'],int.from_bytes(bytes.fromhex(w['bytes']),'little'),w['eventIndex']) for w in c['stores']]==[(0x450bec,0,0),(0x4593a4,0,0),(0x458440,1,3),(0x44dce4,2,3),(0x4593a0,0,3),(0x4511f8,1,4)]
  # These are the harness's declared initial caller bytes, never native inputs.
  stack=bytearray(b'\xa5'*SSIZE);known=bytearray(SSIZE);off=0x1000f038-STACK;stack[off:off+20]=struct.pack('<5I',0x30000000,0x400000,0,0,10)
  def stackwrite(w):
   b=bytes.fromhex(w['bytes']);lo=max(w['address'],STACK);hi=min(w['address']+len(b),STACK+SSIZE)
   if lo<hi:stack[lo-STACK:hi-STACK]=b[lo-w['address']:hi-w['address']];known[lo-STACK:hi-STACK]=b'\1'*(hi-lo)
  for w in p['stackStores']+l['stackStores']:stackwrite(w)
  assert stack==blobs[before['stack']] and known==blobs[before['knownStack']],'parent stack provenance'
  frames={f['stageStackStoreCount']:f for f in c['frames']};requests={e['event']['stackStoreCount']:e['event'] for e in c['events'] if e['kind']=='surface' and e['event']['request'].get('bytes') is not None}
  active=None
  for index in range(len(c['stackStores'])+1):
   if index in frames:
    f=frames[index];off=f['address']-STACK;assert stack[off:off+f['count']]==blobs[f['bytes']] and list(known[off:off+f['count']])==f['known'];active=f
   if index in requests:
    e=requests[index];q=e['request'];off=active['address']-STACK;assert stack[off:off+active['count']]==bytes(q['bytes'])
    expected=bytearray(active['count']);expected[:4]=b'\1'*4
    if q['kind']=='blt':expected[80:84]=b'\1'*4
    assert bytes(q['defined'])==expected;counts['ownedRequestBytes']+=sum(expected);counts['opaqueRequestBytes']+=len(expected)-sum(expected)
   if index<len(c['stackStores']):
    w=c['stackStores'][index]
    if w['pc'] is not None:assert hex(w['pc']) in c['instructions'];counts['originalStackStores']+=1
    else:counts['adapterStackWrites']+=1
    stackwrite(w)
  assert stack==blobs[after['stack']] and known==blobs[after['knownStack']]
  surfaces=[e['event'] for e in c['events'] if e['kind']=='surface'];assert [e['key'] for e in surfaces]==['pixelFormat#1','blt#1','debug#1','blt#2']
  assert [e['request']['words'][0] for e in surfaces if e['request']['words']]==[0x31002000,0x31003000,0x31003000]
  for e in surfaces:assert e['response']['result']==c['spec']['results'].get(e['key'],0)
  for f,e in zip(c['frameReturns'],[surfaces[1],surfaces[0],surfaces[3]]):
   q=e['request'];output=e['response'].get('bytes');assert blobs[f['bytes']]==bytes(output if output is not None else q['bytes'])
   # Frame masks observe original CPU stores only; API query output is
   # retained separately in stackStores and the lifetime knownStack mask.
   assert blobs[f['mask']]==bytes(q['defined'])
  assert [h['eax'] for h in c['helperReturns']]==[surfaces[1]['response']['result']&0xffffffff,int(surfaces[1]['response']['result']>=0),surfaces[3]['response']['result']&0xffffffff]
  assert before['seh']==0xffffffff and len(c['sehStores'])==2 and after['seh']==0x1000ee8c
  for w,value in zip(c['sehStores'],[0x1000efe8,0x1000ee8c]):assert w['address']==0 and hex(w['pc']) in c['instructions'] and bytes.fromhex(w['bytes'])==struct.pack('<I',value)
  we=c['worldEntry'];assert we==dict(address=0x4246b0,world=0x458b00,target=0x31003000,sp=0x1000ee98,returnPC=0x43ecbf,bytes=before['world'])
  req=c['required'];assert req==dict(kind='frontBitmapAllocation',address=0x4450ac,returnPC=0x424784,count=0x1f50,sp=0x1000ea6c,world=0x458b00,target=0x31003000)
  assert after['pc']==req['address'] and after['sp']==req['sp'] and hex(req['address']) not in c['instructions'] and blobs[after['world']]==bytes(0x7d8)
  assert struct.unpack_from('<2I',stack,req['sp']-STACK)==(req['returnPC'],req['count'])
  for k in ['events','stores','frames','frameReturns','helperReturns','sehStores']:counts[k]+=len(c[k])
 _,lib=unpack(fixtures/'original-lib-initialization.json');patches=lib['cases'][0]['patches'];assert len(patches)==13
 for p in patches:assert all(int(a,16)+len(bytes.fromhex(h))<=p['address'] or int(a,16)>=p['address']+p['count'] for a,h in allpcs.items())
 static=json.loads((ROOT/'docs/evidence/application-dispatch-static.json').read_bytes())['instructions'];coverage={}
 for name,items in static.items():
  if isinstance(items,list):
   matches=[v for v in items if hex(v['address']) in newpcs]
   for v in matches:assert v['bytes']==newpcs[hex(v['address'])]
   coverage[name]=dict(static=len(items),executed=len(matches))
 pins=json.loads((ROOT/'build/research/application-dispatch-entry-prior-pins.json').read_bytes());assert len(pins)==238
 for f,h in pins.items():assert digest((fixtures/f).read_bytes())==h,f
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for f,m in v['files'].items():assert digest((vendor/'vendor'/f).read_bytes())==m['vendoredSHA256']
 report=dict(sourceBytes=len(raw),sourceSHA256=digest(raw),producerSHA256=digest(producer),cases=8,parents=1,loops=2,fullStartupReproduced=True,acceptedRequiredLoopReproduced=True,fullGlobalsStackMasksReconstructed=True,staticWorldPEZeroFill=True,sourceFullGlobalBytes=8*FULL,sourceStackBytes=8*SSIZE,sourceWorldBytes=8*0x7d8,counts=dict(counts),actualEXE=len(newpcs),actualDLL=0,staticCoverage=coverage,blobs=len(blobs),atomicParts=8,priorFixturesUnchanged=238,vendorFiles=len(v['files']),libPatchSpansDisjoint=13,requiredAddress=0x4450ac,requiredCount=0x1f50,wholeDispatcherReturns=0,windowsVerified=False)
 if fixture:
  payload,value=unpack(fixture);assert payload+b'\n'==raw and value==d;packed=Path(fixture).read_bytes();report.update(fixtureBytes=len(packed),fixtureSHA256=digest(packed),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();r=validate(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps(r,indent=2))
