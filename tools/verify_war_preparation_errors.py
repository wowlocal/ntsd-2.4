#!/usr/bin/env python3
"""Read-only full record/mask/read/store audit of captured War resource errors.
Pinned NTSD EXE/lib/VC80, original resources and declared Unicorn FS/platform
inputs are compatibility evidence. Reconstruct new allocations, all checkpoints,
reads, stores, ownership and whole returns or stopped actual memory faults.
NULL write-hook attempts are distinct from committed owned stores. Verify every
declared failing API executed and preserve unknown backing and source faults.
No execution, expected edits, fault continuation, Windows/Native/fullgame claim.
"""
import argparse,base64,bisect,collections,datetime,hashlib,json,struct,zlib
from pathlib import Path
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256,ROOT

FS_HEAD=0x7d010000
def sha(b):return hashlib.sha256(b).hexdigest()
def canonical(x):return json.dumps(x,separators=(',',':')).encode()

def audit(report_paths):
 files=[(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes(),(DEFAULT_SOURCE/'lib.dll').read_bytes(),(ROOT/'build/original/crt/msvcr80.dll').read_bytes()]
 assert [sha(b) for b in files]==[EXE_SHA256,'28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba','c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d']
 images=[PE(b) for b in files];stats=collections.Counter();pcs={};unknown=collections.Counter();outcomes=[];pins={};seen_blobs={}
 def pinned(path,pin=None):
  raw=Path(path).read_bytes();actual=dict(bytes=len(raw),sha256=sha(raw))
  if pin:assert all(actual[k]==pin[k] for k in actual)
  pins[str(Path(path).resolve())]=actual;return json.loads(raw)
 def exe(p,n):
  rva=p-0x400000;s=next(s for s in images[0].sections if s['rva']<=rva and rva+n<=s['rva']+max(s['fileSize'],s['virtualSize']))
  offset=rva-s['rva'];known=max(0,min(n,s['fileSize']-offset))
  return files[0][s['fileOffset']+offset:s['fileOffset']+offset+known]+bytes(n-known)
 for report_path in report_paths:
  report=pinned(report_path);assert len(report['prefixProof'])==report['prefixCalls']==10
  for proof in report['prefixProof']:
   old=pinned(proof['path'],proof);assert sha(canonical(old['case']))==proof['normalizedSHA256'] and sha(canonical(old['parents'][0]['constructors']))==proof['constructorSHA256']
   assert proof['relocation']['fsRecordsRelocated']>=2 and proof['relocation']['fsInstructionAccessesRelocated']>0
   stats['prefixReproductions']+=1
  stats['scenarios']+=1;previous=None
  for ci,pin in enumerate(report['calls']):
   d=pinned(pin['path'],pin);c=d['case'];label=c['spec']['label'];blob={}
   assert d['scenario']==report['scenario'] and d['prefixProof']==report['prefixProof']
   for k,v in d['blobs'].items():
    b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and sha(b)==k==v['sha256'];blob[k]=b
    if k in seen_blobs:assert seen_blobs[k]==len(b)
    seen_blobs[k]=len(b)
   def storage(r):
    b,m=(blob[r[k]] for k in ('bytes','defined'));assert len(b)==len(m) and set(m)<={0,1};return bytearray(b),bytearray(m)
   def records(rows):return {r['address']:storage(r['storage']) for r in rows}
   state=records(c['before']);alive={r['address']:r['live'] for r in c['before'] if r['live'] is not None};new={}
   assert 0 not in state and FS_HEAD in state and all(a>0 for a,_,_ in d['memoryMappings'])
   prior=records(previous['after'] if previous else old['case']['after'])
   if not previous:prior[FS_HEAD]=prior.pop(0)
   changes=[(int(p),struct.pack('<I',v)) for p,v in c['spec'].get('matrixInputs',{}).get('words',{}).items()]
   changes += [(c['actorAddresses'][seat]+off,bytes([value])) for seat,off,value in c['spec']['buttons']]
   changes += [(0x1000f000,struct.pack('<I',0x30000000)),(0x1000f004,struct.pack('<I',0x26006000)),(0x1000ea24,struct.pack('<I',0x26006000))]
   for p,b in changes:
    found=[(a,v,m) for a,(v,m) in prior.items() if a<=p and p+len(b)<=a+len(v)];assert len(found)==1
    a,v,m=found[0];v[p-a:p-a+len(b)]=b;m[p-a:p-a+len(b)]=b'\1'*len(b)
   assert prior==state,(label,'whole live previous return plus declared inputs')
   stats['retainedWholeJoins']+=1
   fs=d['fsEnvironment'];assert fs['fsBase']==FS_HEAD and [fs[k] for k in ('cs','ds','es','ss','fs')]==[8,16,16,16,24]
   for key,value in c['instructions'].items():
    p=int(key,16);b=bytes.fromhex(value)
    if p>=0x78130000:offset=images[2].offset(p-images[2].base);expected=files[2][offset:offset+len(b)]
    elif 0x36000000<=p<0x36005000:expected=state[0x36000000][0][p-0x36000000:p-0x36000000+len(b)]
    else:
     expected=bytearray(exe(p,len(b)))
     for patch in d['installation']['patches']:
      a=patch['address'];v=bytes.fromhex(patch['after'])
      for i in range(len(b)):
       if a<=p+i<a+len(v):expected[i]=v[p+i-a]
    assert b==expected,(label,hex(p),'original opcode');assert key not in pcs or pcs[key]==value;pcs[key]=value
   music=[e for e in c['bodyMusic'] if e['kind']=='allocate'];mi=0;g=c['preparationGraphics']
   for ei,e in enumerate(c['events']):
    p=None
    if e['kind']=='preparationBitmap' and e['startup'].get('kind')=='allocate':
     a=e['startup'];p=a['address'];stats['bitmapAllocationRequests']+=1
     if p:
      row=g['allocations'][a['index']];assert row['address']==p and p==0x76004020+a['index']*0x2000
      b=blob[row['backing']];assert b==b'\xa5'*0x1f50;v,m=bytearray(b),bytearray(len(b));stats['bitmapAllocations']+=1
    elif e['kind']=='calloc':
     p,n,size=e['arguments'];assert n==1 and size==0x630e18;stats['recordingAllocationRequests']+=1
     if p:v,m=bytearray(size),bytearray(b'\1'*size);stats['recordingAllocations']+=1
    elif e['kind']=='allocate':
     record=music[mi];mi+=1;assert e['arguments']==record['arguments'];p=record['response']['pointer'];stats['musicAllocationRequests']+=1
     if p:
      b=bytes(record['response']['bytes']);assert len(b)==e['arguments'][0];v,m=bytearray(b),bytearray(len(b));stats['musicAllocations']+=1
    if p:
     assert p not in state;state[p]=(v,m);new[p]=ei
   assert mi==len(music)
   addresses=sorted(state)
   def owner(p,n):
    i=bisect.bisect_right(addresses,p)-1;assert i>=0;a=addresses[i];v,m=state[a]
    assert a<=p and p+n<=a+len(v),(label,hex(p),n,'owner');return a,v,m,p-a
   def lifetime(count):
    live=dict(alive);mi=0
    for e in c['events'][:count]:
     p=None
     if e['kind']=='preparationBitmap' and e['startup'].get('kind')=='allocate':p=e['startup']['address']
     elif e['kind']=='calloc':p=e['arguments'][0]
     elif e['kind']=='allocate':p=music[mi]['response']['pointer'];mi+=1
     if p:assert p not in live;live[p]=True
     if e['kind']=='free' or e['kind']=='preparationBitmap' and e['startup'].get('request',{}).get('kind')=='free':
      p=e['arguments'][0] if e['kind']=='free' else e['startup']['request']['words'][0];assert live[p];live[p]=False
    return live
   points=collections.defaultdict(list);reads=collections.defaultdict(list)
   for p in c['points']:points[p['storeCount']].append(p)
   for kind,key in [('instruction','reads'),('API','apiReads')]:
    for r in c[key]:reads[r['storeCount']].append((kind,r))
   for step in range(len(c['writes'])+1):
    for point in points.pop(step,[]):
     expected=records(point['records']);available={p for p in state if p not in new or new[p]<point['eventCount']};assert set(expected)==available
     live=lifetime(point['eventCount'])
     for r in point['records']:
      p=r['address'];assert state[p]==expected[p],(label,point['kind'],hex(p),'checkpoint bytes/mask')
      if r['live'] is not None:assert r['live']==live[p]
      stats['pointRecords']+=1;stats['pointBytes']+=len(state[p][0])
     if 'fpu' in point:assert point['fpu']['cw']==0x23f
     stats['points']+=1
    for kind,r in reads.pop(step,[]):
     p,n=r['address'],r['count'];b=bytes.fromhex(r['bytes']);mask=bytes(r['known']);assert len(b)==len(mask)==n
     if kind=='instruction':assert hex(r['pc']) in c['instructions']
     if r.get('kind')=='pinnedEXE':assert b==exe(p,n) and mask==b'\1'*n
     else:
      a,v,m,o=owner(p,n);assert v[o:o+n]==b and m[o:o+n]==mask,(label,kind,step,hex(p),'read')
      assert a not in new or new[a]<r['eventIndex']
      if 0 in mask:unknown[(r['pc'],p,n)]+=1
     stats[kind+'Reads']+=1;stats[kind+'ReadBytes']+=n
    if step==len(c['writes']):break
    w=c['writes'][step];p=w['address'];b=bytes.fromhex(w['bytes']);a,v,m,o=owner(p,len(b));assert a not in new or new[a]<w['eventIndex']
    if w['pc'] is not None:assert hex(w['pc']) in c['instructions']
    if p==FS_HEAD:assert c['instructions'][hex(w['pc'])].startswith('64')
    v[o:o+len(b)]=b;m[o:o+len(b)]=b'\1'*len(b);stats['stores']+=1;stats['storedBytes']+=len(b)
   assert not points and not reads and state==records(c['after']),(label,'whole after bytes/masks')
   live=lifetime(len(c['events']))
   for r in c['after']:
    if r['live'] is not None:assert r['live']==live[r['address']]
   for h in c['helpers']:
    assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4 and h['firstStore']<=h['lastStore']<=len(c['writes']);stats['helperReturns']+=1
   assert c['cw']==0x23f and c['end']==pin['end'] and c['endPC']==pin['endPC'] and c['endSP']==pin['endSP']
   if c['end']=='returned':
    assert c['endPC']==0x30000000 and c['endSP']==0x1000f008 and not c['pending'] and c['instructions']['0x422ab8']=='c20400' and c['instructions']['0x439ecd']=='c21c00';stats['wholeReturns']+=1
   else:
    f=c['sourceFault'];assert c['end']=='sourceFault' and f['invalidAccesses'] and all(x.get('pc',x.get('registers',{}).get('eip'))==c['endPC'] for x in f['invalidAccesses'])
    assert ci==len(report['calls'])-1;stats['sourceFaults']+=1
   stimulus=c['spec'].get('resourceFailure',{});applied=c['resourceFailureInput'];ge=g['events']
   for key,result in applied['graphics'].get('results',{}).items():assert any(e.get('key')==key and e['response']['result']==result for e in ge),(label,key,'failure not reached')
   if 'nullAllocationOrdinal' in applied['graphics']:
    i=applied['graphics']['nullAllocationOrdinal'];assert g['allocations'][i]['address']==0
   if 'missingLoaderIndices' in applied['graphics']:
    ids=applied['graphics']['missingLoaderIndices'];loads=[h for h in g['helpers'] if h['kind']=='loader' and h['index'] in ids]
    assert len(loads)==1
    ev=ge[loads[0]['eventStart']:loads[0]['eventEnd']];assert len([e for e in ev if e.get('request',{}).get('kind')=='image' and e['response']['result']==0])==2
   if stimulus.get('replayNull'):assert any(e['kind']=='calloc' and e['arguments'][0]==0 for e in c['events']) and c['endPC']==0x43d2fd
   music_cfg=stimulus.get('music',{})
   if music_cfg.get('nullAllocation'):assert any(e['kind']=='allocate' and e['response']['pointer']==0 for e in c['bodyMusic'])
   if 'createResult' in music_cfg:assert any(e['kind']=='createInstance' and e['response']['result']==-1 and e['response']['pointer']==0 for e in c['bodyMusic'])
   if 'renderResult' in music_cfg:assert any(e['kind']=='method' and e['arguments'][:2]==[0x2c002000,0x34] and e['response']['result']==-1 for e in c['bodyMusic'])
   if music_cfg.get('conversion')=='none':assert any(e['kind']=='convert' and e['response']['result']==0 and e['response']['bytes']==[] for e in c['bodyMusic'])
   if 'musicQuery' in stimulus:
    iid=[0xb1,0xb6,0xb2,0xb3][stimulus['musicQuery']]
    assert any(e['kind']=='queryInterface' and e['strings'][0][0]==iid and e['response']['result']==-1 and e['response']['pointer']==0 for e in c['bodyMusic'])
   stats['calls']+=1
   outcomes.append(dict(scenario=report['scenarioIndex'],label=label,end=c['end'],pc=c['endPC'],records=len(c['after']),events=len(c['events']),sourceFault=c.get('sourceFault')))
   previous=c
 return dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),counts=dict(stats),outcomes=outcomes,instructionStarts=len(pcs),instructions=pcs,
  unknownReads=[dict(pc=p,address=a,count=n,occurrences=v) for (p,a,n),v in sorted(unknown.items())],blobs=len(seen_blobs),decodedBlobBytes=sum(seen_blobs.values()),pins=pins,sourceAudited=True,nativeCompared=False,fullPreparationComplete=False,fullGameComplete=False)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path,action='append',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 d=audit(a.report)
 with a.output.open('x') as f:json.dump(d,f,indent=2);f.write('\n')
 print(d['counts'])

if __name__=='__main__':main()
