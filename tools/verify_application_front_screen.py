#!/usr/bin/env python3
"""Verify own early-screen original bytes/provenance without executing code.
Pinned NTSD/VC80/DIBs and declared IO/graphics/thread outputs. Reconstruct full
parents, globals/private stack/wrappers, API structures and ordered draw reads.
Native private fill/API fields remain unknown; source NULL stop is separate.
No memory mutation, Windows/device, worker body or whole dispatcher claim.
"""
import argparse,base64,hashlib,json,re,struct,subprocess,zlib
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack
BASE,FULL,STACK,SSIZE=0x44d000,0xc3a8,0x1000d000,0x2400

def digest(b):return hashlib.sha256(b).hexdigest()
def key(v):return digest(json.dumps(v,sort_keys=True,separators=(',',':')).encode())
def validate(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert len(d['cases'])==41 and len(d['settingsParents'])==19 and len(d['bitmapParents'])==7
 assert path.with_name(path.stem+'-source.py').read_bytes()==(ROOT/'tools/oracle_application_front_screen.py').read_bytes()
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes();assert digest(exe)==d['exeSHA256']==EXE_SHA256 and digest(dll)==d['crtSHA256'];pe,crt=PE(exe),PE(dll)
 assert next(v['name'] for v in pe.imports() if int(v['iatVA'],16)==0x447098)=='Sleep'
 blobs={}
 for h,v in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and digest(b)==h==v['sha256'];blobs[h]=b
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';_,old=unpack(fixtures/'original-application-settings.json')
 for h,p in d['bitmapParents'].items():assert h==key(p) and p==old['parents'][h]
 for h,v in old['blobs'].items():
  if h in d['blobs']:assert v==d['blobs'][h]
 control=(DEFAULT_SOURCE/'data/control.txt').read_bytes().replace(b'\r\n',b'\n');parentCounts=Counter();parentPCs={}
 for h,c in d['settingsParents'].items():
  assert h==key(c) and c['end']=='ready';p=d['bitmapParents'][c['parent']]
  if c in old['cases']:parentCounts['retainedExact']+=1
  else:
   setting=1 if c['spec']['label']=='own-setting-1' else -1;assert c['spec']['label']==f'own-setting-{setting}'
   assert blobs[c['input']]==control.replace(b'1 2 3 4\n0\n1\n',b'1 2 3 4\n'+str(setting).encode()+b'\n1\n');parentCounts['newSettingInput']+=1
  assert c['crtBefore']==c['crtAfter']==p['crtAfter']
  for k in ['pc','sp','globals','stack','knownStack','cw','seh']:assert c['before'][k]==p['after'][k]
  g=bytearray(blobs[c['before']['globals']]);gm=bytearray(FULL);stack=bytearray(blobs[c['before']['stack']]);known=bytearray(blobs[c['before']['knownStack']]);sm=bytearray(500);wi=0
  for e in [dict(state=c['before'])]+[e for e in c['events'] if 'state' in e]+[dict(state=c['after'])]:
   s=e['state']
   while wi<s['storeCount']:
    w=c['stores'][wi];wi+=1;b=bytes.fromhex(w['bytes']);a=w['address'];n=len(b)
    if BASE<=a<a+n<=BASE+FULL:g[a-BASE:a-BASE+n]=b;gm[a-BASE:a-BASE+n]=b'\1'*n
    if STACK<=a<a+n<=STACK+SSIZE:stack[a-STACK:a-STACK+n]=b;known[a-STACK:a-STACK+n]=b'\1'*n
    if 0x1000e878<=a<a+n<=0x1000ea6c:sm[a-0x1000e878:a-0x1000e878+n]=b'\1'*n
   assert g==blobs[s['globals']] and gm==blobs[s['mask']] and stack==blobs[s['stack']] and known==blobs[s['knownStack']]
   assert stack[0x1878:0x1878+500]==blobs[s['scratch']] and sm==blobs[s['scratchMask']]
   parentCounts['stateCheckpoints']+=1
  assert c['after']['registers'][2:]==[0xffffffff,p['parents']['entry']['worldEntry']['target']]
  assert g[0xb440:]==blobs[c['before']['globals']][0xb440:] and g[0x68:0x6c]==bytes(4)
  parentPCs.update(c['instructions']);parentCounts['settingsEvents']+=len(c['events'])
 assert parentCounts['retainedExact']==17 and parentCounts['newSettingInput']==2
 resources={r['path'][1]:r for r in pe.resources() if r['path'][0]==2};assert len(d['assets'])==36
 for name,a in d['assets'].items():
  r=resources[name];dib=exe[r['fileOffset']:r['fileOffset']+r['size']];assert a['kind']=='embedded' and blobs[a['raw']]==dib
  assert struct.unpack_from('<i',dib,4)[0]==a['width'] and abs(struct.unpack_from('<i',dib,8)[0])==a['height']
 assert all('MENU_BACK'+str(i) in d['assets'] for i in range(1,14))
 pcs={};events=Counter();counts=Counter();fields=Counter();parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==41
 def instructions(items):
  for a,h in items.items():
   pc=int(a,16);b=bytes.fromhex(h);binary,q=(dll,crt) if pc>=0x78000000 else (exe,pe);off=q.offset(pc-q.base);assert binary[off:off+len(b)]==b,(a,h)
 instructions(parentPCs)
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i:04d}.json').read_bytes());s=d['settingsParents'][c['parent']];p=d['bitmapParents'][s['parent']]
  assert part['case']==c and part['settingsParent']==s and part['bitmapParent']==p and all(d['blobs'][h]==v for h,v in part['blobs'].items())
  for k in ['pc','sp','globals','stack','knownStack','cw','seh','registers']:assert c['before'][k]==s['after'][k],(i,k)
  assert c['crtBefore']==s['crtAfter']==c['crtAfter']
  instructions(c['instructions']);pcs.update(c['instructions']);assert '0x427127' not in c['instructions'] and '0x4275cb' not in c['instructions']
  if c['end']=='nullBitmap':assert c['after']['pc']==0x43f04b and '0x43f04b' not in c['instructions'] and c['allocation']['address']==0
  else:assert c['end'] in ('critical','alternate') and c['after']['sp']==0x1000ea74 and c['after']['pc']==(0x427127 if c['end']=='critical' else 0x4275cb)
  assert c['before']['seh']==c['after']['seh'] and c['after']['cw']==0x37f;counts[c['end']]+=1
  if c['end']!='nullBitmap':assert c['after']['registers']==c['before']['registers'][:2]+[0x30009040,c['before']['registers'][3]]
  g=bytearray(blobs[c['before']['globals']]);gm=bytearray(FULL);stack=bytearray(blobs[c['before']['stack']]);known=bytearray(blobs[c['before']['knownStack']]);wi=0
  records={r['address']:(bytearray(blobs[r['bytes']]),bytearray(blobs[r['mask']])) for r in p['records']}
  frame=c['fillFrame'];prior=bytearray(stack);priorKnown=bytearray(known)
  for w in c['writes'][:frame['firstStore']]:
   b=bytes.fromhex(w['bytes']);a=w['address']
   if STACK<=a<a+len(b)<=STACK+SSIZE:prior[a-STACK:a-STACK+len(b)]=b;priorKnown[a-STACK:a-STACK+len(b)]=b'\1'*len(b)
  off=frame['address']-STACK;assert prior[off:off+100]==blobs[frame['bytes']] and priorKnown[off:off+100]==blobs[frame['known']]
  counts['fillFramesReconstructed']+=1
  allocation=c['allocation'];token=allocation['address'];expected=max(records,default=0x2800e020)+0x2000
  assert token==(0 if c['spec'].get('null') else expected)
  if token:assert blobs[allocation['backing']]==b'\xa5'*0x1f50;records[token]=(bytearray(blobs[allocation['backing']]),bytearray(0x1f50))
  def write(w):
   b=bytes.fromhex(w['bytes']);a=w['address'];n=len(b)
   if w['pc'] is not None:assert hex(w['pc']) in c['instructions'];counts['CPUStores']+=1
   else:counts['APIStores']+=1
   counts['storeBytes']+=n
   if BASE<=a<a+n<=BASE+FULL:g[a-BASE:a-BASE+n]=b;gm[a-BASE:a-BASE+n]=b'\1'*n
   if STACK<=a<a+n<=STACK+SSIZE:stack[a-STACK:a-STACK+n]=b;known[a-STACK:a-STACK+n]=b'\1'*n
   for address,(record,mask) in records.items():
    if address<=a<a+n<=address+0x1f50:record[a-address:a-address+n]=b;mask[a-address:a-address+n]=b'\1'*n
  def advance(n):
   nonlocal wi
   while wi<n:write(c['writes'][wi]);wi+=1
  for ei,e in enumerate(c['events']):
   front=e.get('kind')=='front';q=e['event'] if front else e['request'];isWrite=front and q['kind']=='write'
   # A CPU write hook observes old memory. Its own pending store is already in
   # the ordered log; compare this snapshot before applying that last store.
   n=e['storeCount']-(1 if isWrite else 0);advance(n);assert g==blobs[e['globals']],(i,ei,q['kind'])
   events[q['kind']]+=1;counts['eventGlobalBytes']+=FULL
   if isWrite:
    a,count,v=q['arguments'];w=c['writes'][wi];assert w['address']==a and bytes.fromhex(w['bytes'])==v.to_bytes(count,'little');advance(wi+1)
   if front and q['kind']=='fill':
    f=q['fill'];frame=c['fillFrame'];off=frame['address']-STACK;assert bytes(f['effects'])==stack[off:off+100]
    mask=bytearray(100)
    for w in c['writes'][frame['firstStore']:e['storeCount']]:
     b=bytes.fromhex(w['bytes']);a=w['address']-frame['address']
     if 0<=a<a+len(b)<=100:mask[a:a+len(b)]=b'\1'*len(b)
    assert bytes(f['defined'])==mask==b'\1'*4+bytes(76)+b'\1'*4+bytes(16)
    assert f['target']==struct.unpack_from('<I',g,0x455608-BASE)[0];fields['fillOwned']+=8;fields['fillOpaque']+=92
   if front and q['kind']=='read':
    r=q['read'];b,m=records[token];value=struct.unpack_from('<I',b,r['offset'])[0];assert value==r['value'] and bool(r['defined'])==all(m[r['offset']:r['offset']+4]);counts['undefinedBitmapReads']+=not r['defined']
   if not front and 'bytes' in q:
    name=q['kind']
    if name=='getObject':kind,delta=('loader',24) if e['returnPC']==0x43ed6b else ('copy',132)
    elif name=='createSurface':kind,delta='loader',132
    else:assert name=='description';kind,delta='copy',108
    h=next(h for h in c['helpers'] if h['kind']==kind and h['eventStart']<=ei<h['eventEnd']);a=h['sp']-delta;n=len(q['bytes']);assert bytes(q['bytes'])==stack[a-STACK:a-STACK+n];mask=bytearray(n)
    for w in c['writes'][h['firstStore']:e['storeCount']]:
     b=bytes.fromhex(w['bytes']);lo=max(a,w['address']);hi=min(a+n,w['address']+len(b))
     if lo<hi:mask[lo-a:hi-a]=b'\1'*(hi-lo)
    assert bytes(q['defined'])==mask;fields['imageAPIOwned']+=sum(mask);fields['imageAPIOpaque']+=n-sum(mask)
  advance(len(c['writes']));assert g==blobs[c['after']['globals']] and gm==blobs[c['after']['mask']] and stack==blobs[c['after']['stack']] and known==blobs[c['after']['knownStack']]
  assert g[0xb440:]==blobs[c['before']['globals']][0xb440:]
  for r in c['records']:
   b,m=records[r['address']];assert b==blobs[r['bytes']] and m==blobs[r['mask']]
  for r in p['records']:assert r in c['records']
  for h in c['helpers']+c['frontHelpers']:
   assert h['returnSP']==h['sp']+4+h['pop'] and hex(h['entry']) in c['instructions'];counts['helperReturns']+=1
   if h.get('kind')=='constructor':assert h['result']==h['wrapper']
  counts['fullRecordBytes']+=len(records)*0x1f50;counts['wrapperRecords']+=len(records);counts['stackBytes']+=SSIZE*2;counts['fullGlobalBytes']+=FULL*2
 _,lib=unpack(fixtures/'original-lib-initialization.json');patches=lib['cases'][0]['patches']
 for p in patches:assert all(int(a,16)+len(bytes.fromhex(h))<=p['address'] or int(a,16)>=p['address']+p['count'] for a,h in pcs.items())
 coverage={}
 for name,start,end in [('caller',0x42709b,0x427127),('gate',0x4237e0,0x42383d),('threadRequest',0x43c450,0x43c496),('fill',0x415160,0x4151c3),('background',0x423840,0x42390a),('loader',0x43ed10,0x43ee50),('copy',0x4013d0,0x4014d2),('bitmap',0x43f010,0x43f300),('clip',0x43ef70,0x43f00d)]:
  text=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',f'--start-address={hex(start)}',f'--stop-address={hex(end)}',str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True);items=[]
  for line in text.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
   if m:items.append(dict(address=hex(int(m[1],16)),bytes=bytes.fromhex(m[2]).hex(),instruction=m[3]))
  assert all(v['address'] not in pcs or pcs[v['address']]==v['bytes'] for v in items)
  coverage[name]=dict(static=len(items),executed=sum(v['address'] in pcs for v in items),unexecuted=[v for v in items if v['address'] not in pcs])
 pins=json.loads((ROOT/'build/research/application-front-screen-prior-pins.json').read_bytes());assert len(pins)==241
 for name,h in pins.items():assert digest((fixtures/name).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for name,m in v['files'].items():assert digest((vendor/'vendor'/name).read_bytes())==m['vendoredSHA256']
 report=dict(sourceBytes=len(raw),sourceSHA256=digest(raw),producerSHA256=digest((ROOT/'tools/oracle_application_front_screen.py').read_bytes()),cases=41,settingsParents=19,bitmapParents=7,parentCounts=dict(parentCounts),counts=dict(counts),events=dict(events),fields=dict(fields),actualEXE=sum(int(a,16)<0x78000000 for a in pcs),actualCRT=sum(int(a,16)>=0x78000000 for a in pcs),coverage=coverage,blobs=len(blobs),assets=36,atomicParts=41,priorFixturesUnchanged=241,vendorFiles=10,libPatchSpansDisjoint=13,fullOriginalStatesReconstructed=True,ownParentsRetained=True,sourceNullStops=1,nativeCompletedPrefixes=40,wholeDispatcherReturns=0,workerBodyExecuted=False,windowsVerified=False)
 if fixture:
  payload,value=unpack(fixture);assert payload+b'\n'==raw and value==d;p=Path(fixture).read_bytes();report.update(fixtureBytes=len(p),fixtureSHA256=digest(p),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();r=validate(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps({k:v for k,v in r.items() if k!='coverage'},indent=2))
