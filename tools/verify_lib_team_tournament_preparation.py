#!/usr/bin/env python3
"""Read-only audit of whole Team Tournament preparation and retained menu calls.
Pinned original EXE/lib/VC80/DAT/BMP evidence from controlled Unicorn2.1.4;
no execution, fault continuation, expected edits or Windows/device claim.
Reconstruct all recorded storage from declared inputs and actual writes, checking
reads/masks, every complete checkpoint/final record, allocations and true ABI
returns. Verify Actor-constructor provenance, full replay reads and 109/10a/10b,
date/local string backing and actual436afa rootSP10 with pending12arguments.
LIB_TEAM_TOURNAMENT_PREPARATION_PLAN.md defines finite acceptance and open boundaries.
"""
from pathlib import Path
import argparse,base64,collections,hashlib,json,struct,zlib
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256

def sha(raw):return hashlib.sha256(raw).hexdigest()

def verify(path):
 raw=path.read_bytes();d=json.loads(raw);stats=collections.Counter();unknown=collections.Counter();pcs={};streams=collections.Counter()
 assert len(d['cases'])==len(d['installations'])==210
 assert [c['spec'] for c in d['cases']]==json.loads((path.parent/'lib-team-tournament-preparation-finite-inputs1.json').read_bytes())
 files=[(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes(),(DEFAULT_SOURCE/'lib.dll').read_bytes(),(ROOT/'build/original/crt/msvcr80.dll').read_bytes()]
 assert [sha(f) for f in files]==[EXE_SHA256,'28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba','c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d']
 assert [d[k] for k in ('exeSHA256','libSHA256','crtSHA256')]==[sha(f) for f in files]
 images=[PE(f) for f in files];blobs={}
 for k,v in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and sha(b)==k==v['sha256'];blobs[k]=b
 def storage(r):
  b,m=(blobs[r[k]] for k in ('bytes','defined'));assert len(b)==len(m) and set(m)<={0,1};return bytearray(b),bytearray(m)
 def records(items):return {r['address']:storage(r['storage']) for r in items}
 def exe(p,n):o=images[0].offset(p-0x400000);return files[0][o:o+n]
 def instructions(items,lib_before,patches):
  for key,text in items.items():
   p=int(key,16);b=bytes.fromhex(text)
   if p>=0x78130000:o=images[2].offset(p-images[2].base);expected=files[2][o:o+len(b)]
   elif 0x36000000<=p<0x36005000:expected=lib_before[p-0x36000000:p-0x36000000+len(b)]
   else:
    expected=bytearray(exe(p,len(b)))
    for patch in patches:
     start=patch['address'];value=bytes.fromhex(patch['after'])
     for i in range(len(b)):
      if start<=p+i<start+len(value):expected[i]=value[p+i-start]
   assert b==expected,(hex(p),b.hex(),bytes(expected).hex())
   assert key not in pcs or pcs[key]==text;pcs[key]=text
 dependency=d['catalogDependency'];packed=(ROOT/dependency['path']).read_bytes();assert sha(packed)==dependency['sha256']=='5fcd6e364a7761fcad4dc5af9792acf18e20b7bd9ff6ea89a66955c48a2af05e'
 envelope=json.loads(packed);depraw=zlib.decompress(base64.b64decode(envelope['deflate']),-15);assert len(depraw)==envelope['count'] and sha(depraw)==envelope['sha256'];catalog=json.loads(depraw)
 depblobs={k:zlib.decompress(base64.b64decode(v['deflate']),-15) for k,v in catalog['blobs'].items()}
 assert all(len(v)==catalog['blobs'][k]['count'] and sha(v)==k for k,v in depblobs.items())
 assert dependency['checksum']==catalog['checksum'] and dependency['bitmapAddresses']==[b['address'] for b in catalog['bitmaps']]
 for parent in d['parents']:
  c=d['cases'][parent['firstCase']];constructors=parent['constructors'];assert len(constructors['calls'])==401
  before=records(c['before']);instructions(constructors['instructions'],before[0x36000000][0],d['installations'][parent['firstCase']]['patches'])
  for index,call in enumerate(constructors['calls']):
   p=call['address'];initial=storage(call['before']);state=[bytearray(x) for x in initial]
   for w in constructors['writes'][call['firstStore']:call['lastStore']]:
    a=w['address'];b=bytes.fromhex(w['bytes'])
    if p<=a and a+len(b)<=p+len(state[0]):state[0][a-p:a-p+len(b)]=b;state[1][a-p:a-p+len(b)]=b'\1'*len(b)
   assert tuple(state)==storage(call['after'])
   assert call['entry']==(0x419e40 if index==0 else 0x4061d0) and call['fpuBefore']['cw']==call['fpuAfter']['cw']==0x23f
   assert p==(d['worldAddress'] if index==0 else c['actorAddresses'][index-1]);stats['constructorReturns']+=1
  for view in parent['fileBackedInputs']:
   p=view['address'];b=bytes.fromhex(view['bytes']);assert b==exe(p,len(b)) and before[0x44d000][0][p-0x44d000:p-0x44d000+len(b)]==b
  # Full accepted BG records remain the pre-menu dependency, not new expected
  # inputs for Native. The native test rebuilds the catalog from raw resources.
  for i in range(101):
   off=0x4d45db0+i*0x990;r=catalog['regions'][str(off)]
   assert before[0x60000020+off]==(depblobs[r['bytes']],depblobs[r['defined']])
  for entry,child in zip(d['roster']['entries'],[x for x in catalog['children'] if x['kind']=='object']):
   r=child['storage'];assert before[entry['address']+0x90]==(depblobs[r['bytes']][0x90:0x94],depblobs[r['defined']][0x90:0x94])
 previous=None
 for c,install in zip(d['cases'],d['installations']):
  label=c['spec']['label'];state=records(c['before']);initial={p:(bytes(v),bytes(m)) for p,(v,m) in state.items()}
  assert c['end']=='returned' and c['endPC']==0x30000000 and c['endSP']==d['entrySP']+8 and c['cw']==0x23f and not c['pending']
  assert c['instructions']['0x422ab8']=='c20400' and c['instructions']['0x436fb5']=='c20c00'
  if c['spec'].get('chain'):
   prior=records(previous['after'])
   bridge=[]
   if 'bridgeGlobals' in c['spec']:
    assert prior==records(c['bridge']['before']),(label,'whole retained bridge input')
    bridge=[dict(address=int(p),bytes=struct.pack('<I',v).hex()) for p,v in c['spec']['bridgeGlobals'].items()]
    assert c['bridge']['writes']==bridge and {x['address'] for x in bridge}=={0x44d020,0x44d024,0x44d028}
    stats['controlledBridges']+=1
   else:assert 'bridge' not in c
   for change in bridge+c['stimulus']+c['callerABI']:
    p=change['address'];b=bytes.fromhex(change['bytes']);found=[(a,v,m) for a,(v,m) in prior.items() if a<=p and p+len(b)<=a+len(v)];assert len(found)==1
    a,v,m=found[0];v[p-a:p-a+len(b)]=b;m[p-a:p-a+len(b)]=b'\1'*len(b)
   assert prior==state,(label,'retained full parent')
  previous=c;instructions(c['instructions'],state[0x36000000][0],install['patches'])
  assert install['base']==0x36000000 and install['result']==1 and len(install['patches'])==13
  for patch in install['patches']:assert bytes.fromhex(patch['before'])==exe(patch['address'],patch['count'])
  new={};alive={r['address']:r['live'] for r in c['before'] if r['live'] is not None}
  for ei,e in enumerate(c['events']):
   if e['kind']=='preparationBitmap' and e['startup'].get('kind')=='allocate':
    a=e['startup'];p=a['address'];assert p==0x76000020+a['index']*0x2000 and a['count']==0x1f50
    assert p not in state;state[p]=(bytearray(b'\xa5'*0x1f50),bytearray(0x1f50));new[p]=ei
   if e['kind']=='calloc':
    p,n,size=e['arguments'];assert p==(0x75000020 if c['spec']['generation']==0 else 0x77000020+(c['spec']['generation']-1)*0x640000) and p==c['replayAddress'] and n==1 and size==0x630e18 and p not in state
    state[p]=(bytearray(size),bytearray(b'\1'*size));new[p]=ei
  addresses=sorted(state)
  def owner(p,n):
   import bisect
   i=bisect.bisect_right(addresses,p)-1;assert i>=0
   a=addresses[i];v,m=state[a];assert a<=p and p+n<=a+len(v),(label,hex(p),n);return a,v,m,p-a
  def lifetimes(count):
   result=dict(alive)
   for e in c['events'][:count]:
    if e['kind']=='free':p=e['arguments'][0];assert result[p];result[p]=False
    elif e['kind']=='preparationBitmap' and e['startup'].get('request',{}).get('kind')=='free':
     p=e['startup']['request']['words'][0];assert result[p];result[p]=False
    elif e['kind']=='calloc':result[e['arguments'][0]]=True
    elif e['kind'] in ('startup','preparationBitmap') and e['startup'].get('kind')=='allocate':result[e['startup']['address']]=True
    elif e['kind']=='allocate':result[next(e['response']['pointer'] for e in c['bodyMusic'] if e['kind']=='allocate')]=True
   return result
  points=collections.defaultdict(list);reads=collections.defaultdict(list)
  for point in c['points']:points[point['storeCount']].append(point)
  for kind,items in [('instruction',c['reads']),('API',c['apiReads'])]:
   for read in items:reads[read['storeCount']].append((kind,read))
  for step in range(len(c['writes'])+1):
   for point in points.pop(step,[]):
    expected=records(point['records']);available={p for p in state if p not in new or new[p]<point['eventCount']};assert set(expected)==available,(label,point['kind'],'region lifetime')
    live=lifetimes(point['eventCount'])
    for r in point['records']:
     p=r['address'];assert state[p]==expected[p],(label,point['kind'],hex(p),'bytes/mask')
     if r['live'] is not None:assert r['live']==live[p]
     stats['pointRecords']+=1;stats['pointBytes']+=len(state[p][0])
    if point['kind'].startswith('preparation-'):
     pc=int(point['kind'].split('-')[1],16);root=c['characterSP']-0xa18
     assert point['sp']==root-(12 if pc==0x436afa else 0) and point['fpu']['cw']==0x23f
     if pc==0x436afa:
      _,v,m,o=owner(point['sp']+0x1c,4);assert v[o:o+4]==struct.pack('<I',0x44d020) and m[o:o+4]==b'\1'*4
     if point['name'] is not None:
      b=bytes.fromhex(point['name'])+b'\0';_,v,m,o=owner(root+0x810,len(b));assert v[o:o+len(b)]==b and m[o:o+len(b)]==b'\1'*len(b)
     stats['preparationPoints']+=1
    stats['points']+=1
   for kind,x in reads.pop(step,[]):
    p,n=x['address'],x['count'];b=bytes.fromhex(x['bytes']);m=bytes(x['known']);assert len(b)==len(m)==n
    if kind=='instruction':assert hex(x['pc']) in c['instructions']
    if x.get('kind')=='pinnedEXE':assert b==exe(p,n) and m==b'\1'*n
    else:
     a,v,mask,o=owner(p,n);assert v[o:o+n]==b and mask[o:o+n]==m,(label,kind,step,hex(p),'read provenance')
     assert a not in new or new[a]<x['eventIndex']
     if 0 in m:unknown[(x['pc'],p,n)]+=1
     if 0x40c114<=x['pc']<=0x40c134:
      assert all(m),(label,'unknown live arena release operand',hex(p));stats['knownReleaseReads']+=1
      if 0x76000000<=a<0x76080000:assert lifetimes(x['eventIndex'])[a],(label,'release read of dead wrapper',hex(p))
     if 0x43d2c0<=x['pc']<=0x43db38:
      assert all(m),(label,hex(x['pc']),hex(p),'unavailable recording operand');stats['recordingReads']+=1;stats['recordingReadBytes']+=n
    stats[kind+'Reads']+=1;stats[kind+'ReadBytes']+=n
   if step==len(c['writes']):break
   w=c['writes'][step];p=w['address'];b=bytes.fromhex(w['bytes']);a,v,m,o=owner(p,len(b));assert a not in new or new[a]<w['eventIndex']
   if w['pc'] is not None:assert hex(w['pc']) in c['instructions']
   v[o:o+len(b)]=b;m[o:o+len(b)]=b'\1'*len(b);stats['stores']+=1;stats['storedBytes']+=len(b)
  assert not points and not reads and state==records(c['after']),(label,'whole final storage')
  live=lifetimes(len(c['events']))
  assert all(r['live'] is None or r['live']==live[r['address']] for r in c['after'])
  for h in c['helpers']:
   assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4 and h['firstStore']<=h['lastStore']<=len(c['writes']);stats['helperReturns']+=1
   if h['entry']==0x417170:
    index=(h['index']+1)%3000;counter=(h['counter']+1)%1234;v=initial[0x44d000][0]
    assert h['result']==(v[0x44ff90-0x44d000+index]+counter)%h['range'];streams[h['stream']]+=1
  if c['preparationGraphics'] is not None:
   # Derive every active Actor from the actual pre-consumer boundary.
   # These source inputs validate rules; Native independently retains its state.
   entry=records(next(p for p in c['points'] if p['kind']=='preparation-0x436747')['records'])
   eg,fg=entry[0x44d000][0],state[0x44d000][0]
   word=lambda b,a:struct.unpack_from('<i',b,a-0x44d000)[0]
   integer=lambda b,o:struct.unpack_from('<i',b,o)[0]
   arena=word(fg,0x44d024);bg=entry[0x60000020+0x4d45db0+arena*0x990][0]
   drawX=[h for h in c['helpers'] if h['entry']==0x417170 and h['stream']==0x10a]
   drawZ=[h for h in c['helpers'] if h['entry']==0x417170 and h['stream']==0x10b]
   active=[i for i in range(20) if entry[d['worldAddress']][0][4+i]]
   assert len(active)==len(drawX)==len(drawZ),(label,'placement RNG count')
   # Repeat confirmation deliberately retains assignments, unlike normal result
   # handling. Reconstruct actual4366c5 placement, including repeated CPUs and
   # the eight paired-seat capacity, before deriving preparation actor counts.
   placed=records(next(p for p in c['points'] if p['kind']=='team-tournament-0x4366c5')['records'])
   pg0=placed[0x44d000][0];pw=bytearray(placed[d['worldAddress']][0]);assign=[word(pg0,0x4512d0+i*4) for i in range(20)];placements=[]
   for member in range(4):
    index=word(pg0,0x4513ec+member*4);mapped=word(pg0,0x44d0e0+index*4)
    if word(pg0,0x451364+mapped*4)==0:
     slot=next((i for i in range(8) if pw[4+i]==pw[14+i]==0),None)
     if slot is not None:
      pw[14+slot]=1;assign[10+slot]=index
      objectAddress=d['roster']['entries'][word(pg0,0x44d0c0+mapped*4)]['address']
      actorAddress=c['actorAddresses'][10+slot]
      placements.extend([(0x43670a,0x4512f8+slot*4,struct.pack('<i',index).hex()),(0x436711,d['worldAddress']+14+slot,'01'),(0x436736,actorAddress+0x368,struct.pack('<I',objectAddress).hex())])
      assert struct.unpack_from('<I',entry[actorAddress][0],0x368)[0]==objectAddress
   assert pw==entry[d['worldAddress']][0] and assign==[word(eg,0x4512d0+i*4) for i in range(20)]
   assert placements==[(w['pc'],w['address'],w['bytes']) for w in c['writes'] if w['pc'] in (0x43670a,0x436711,0x436736)]
   stats['CPUPlacementStores']+=len(placements);stats['preparationsWith'+str(len(active))+'Actors']+=1
   assert len(active) in (4,6,8) and (len(active)==4 or c['spec']['generation']>0)
   assert set(assign[i] for i in active)==set(word(pg0,0x4513ec+i*4) for i in range(4))
   trunc=lambda a,b:(abs(a)//abs(b))*(-1 if (a<0)!=(b<0) else 1)
   for i,hx,hz in zip(active,drawX,drawZ):
    participant=word(eg,0x4512d0+i*4);actor=c['actorAddresses'][i];b=state[actor][0]
    assert 0<=participant<8
    assert all(integer(b,o)==word(eg,0x44d080+participant*4) for o in (0x2fc,0x300,0x304))
    assert integer(b,0x308)==500 and integer(b,0x33c)==word(eg,0x44d0a0+participant*4)
    assert integer(b,0x364)==word(eg,0x44d100+participant*4) and integer(b,8)==75 and integer(b,0x354)==i
    assert b[0x368:0x36c]==entry[actor][0][0x368:0x36c]
    width,lower,upper=struct.unpack_from('<iii',bg)
    assert hx['range']==trunc(width,2) and hz['range']==upper-lower
    x=hx['result']+trunc(width,4);z=hz['result']+lower
    assert [integer(b,o) for o in (0x10,0x14,0x18)]==[x,0,z]
    assert b[0x58:0x70]==struct.pack('<ddd',float(x),0.0,float(z))
    assert hx['lastStore']<hz['firstStore'];stats['preparedParticipants']+=1
   t=c['spec'].get('localTime',[2026,9,5,11,12,34,56,789]);year,month,_,day,hour,minute,second,_=t
   name=('%4d%02d%02d_%02d%02d%02d'%(year,month,day,hour,minute,second)).encode()+b'_2on2_'+{2:b'SemiFinal',4:b'Final'}.get(word(eg,0x44d318),b'')
   filename=name+b'.lfr\0';off=0x44fd98-0x44d000;assert fg[off:off+len(filename)]==filename
   formats=[h for h in c['helpers'] if h['entry']==0x7817775d and 'output' in h]
   naming=[h for h in formats if h['returnPC'] in (0x436795,0x436848)]
   assert [(h['returnPC'],bytes(h['format'])) for h in naming]==[(0x436795,b'%4d%02d%02d_%02d%02d%02d'),(0x436848,b'%s.lfr')]
   for h in formats:
    if h in naming:continue
    assert h['returnPC']==0x4029ae and bytes(h['format'])==b"Start recording '%s'..."
    assert bytes.fromhex(h['output'])==b"Start recording '"+filename[:-1]+b"'..."
    stats['recordingNoticeFormats']+=1
   flags=[w['address'] for w in c['writes'] if w['pc'] in (0x436a9f,0x436aa9)]
   assert flags==[0x44d034,0x450bbc]
   pg=c['preparationGraphics'];allocations=sum(e.get('kind')=='allocate' for e in pg['events'])
   assert allocations==(0 if arena==99 else integer(bg,0x1c));stats['independentlyExpectedBitmapAllocations']+=allocations
   p=c['replayAddress'];assert p in state and len(state[p][0])==0x630e18 and all(state[p][1]);stats['wholePreparations']+=1;stats['recordingBytes']+=0x630e18
   g=state[0x44d000][0];word=lambda p:struct.unpack_from('<i',g,p-0x44d000)[0]
   assert word(0x44d020)==0 and word(0x450b80)==1 and word(0x44d034)==1
   if 'randomArenaExpectation' in c['spec']:assert word(0x44d024)==c['spec']['randomArenaExpectation']
   pg=c['preparationGraphics'];assert pg['events']==[e['startup'] for e in c['events'] if e['kind']=='preparationBitmap']
   for r in pg['records']:
    assert state[r['address']]==(blobs[r['bytes']],blobs[r['mask']]) and live[r['address']]==pg['wrapperLive'][str(r['address'])]
  if c['preparationGraphics'] is not None:
   pg=c['preparationGraphics'];expected=[]
   for arena in range(17):
    b,m=initial[0x60000020+0x4d45db0+arena*0x990]
    first=struct.unpack_from('<I',b,0x914)[0];count=struct.unpack_from('<i',b,0x1c)[0]
    if first:
     assert 0<count<=30
     expected.extend(struct.unpack_from('<I',b,0x914+layer*4)[0] for layer in range(count))
   actual=[]
   for i,e in enumerate(pg['events']):
    if e.get('kind')=='allocate':stats['bitmapAllocations']+=1
    if e.get('request',{}).get('kind')=='free':
     p=e['request']['words'][0];actual.append(p);previous_api=pg['events'][i-1]
     surface=struct.unpack_from('<I',initial[p][0],0)[0]
     assert previous_api['request']==dict(kind='release',words=[surface],strings=[])
     assert previous_api['returnPC']==0x40c120 and e['returnPC']==0x40c125
     assert previous_api['response']['result']==c['spec']['releaseResult'] and e['response']['result']==0
     stats['releasePairs']+=1
   assert actual==expected,(label,'whole release order')
   assert bool(expected)==(c['spec']['generation']==1)
   if c['spec']['generation']==1:assert not any(e.get('kind')=='allocate' for e in pg['events'])
   if c['spec']['generation']==2:stats['staleTailReloads']+=1
  stats['finalRecords']+=len(state);stats['finalBytes']+=sum(len(v) for v,m in state.values())
 # Raw image/metadata provenance, including every newly loaded arena layer.
 resources={x['path'][1]:x for x in images[0].resources() if x['path'][0]==2}
 for name,a in d['assets'].items():
  if a['kind']=='embedded':r=resources[name];b=files[0][r['fileOffset']:r['fileOffset']+r['size']];dib=b
  else:b=(DEFAULT_SOURCE/name.replace('\\','/')).read_bytes();assert b[:2]==b'BM';dib=b[14:]
  assert blobs[a['raw']]==b;w,h=struct.unpack_from('<ii',dib,4);planes,bpp=struct.unpack_from('<HH',dib,12)
  assert [w,abs(h),planes,bpp]==[a[k] for k in ('width','height','planes','bpp')]
 for group in [d['roster']['sourceFiles'],d['roster']['smallSourceFiles'],d['arenas']['sourceFiles']]:
  for name,pin in group.items():b=(DEFAULT_SOURCE/name).read_bytes();assert dict(bytes=len(b),sha256=sha(b))==pin
 assert stats['wholePreparations']==56 and stats['constructorReturns']==22*401 and all(streams[s]>0 for s in (0x109,0x10a,0x10b))
 assert stats['releasePairs']==302 and stats['bitmapAllocations']>=604 and stats['staleTailReloads']==17 and stats['controlledBridges']==34
 assert stats['recordingNoticeFormats']==26
 assert stats['preparedParticipants']==300 and [stats['preparationsWith'+str(n)+'Actors'] for n in (4,6,8)]==[34,6,16] and stats['independentlyExpectedBitmapAllocations']==stats['bitmapAllocations']
 # Every atomically completed case and its source blob/asset/parent metadata is
 # retained unchanged in the final raw corpus.
 for index,c in enumerate(d['cases']):
  part=json.loads((path.with_suffix('.parts')/f'{index:04d}.json').read_bytes())
  assert part['case']==c and part['installation']==d['installations'][index]
  assert all(d['blobs'][k]==v for k,v in part['blobs'].items()) and all(d['assets'][k]==v for k,v in part['assets'].items())
  parent=max((p for p in d['parents'] if p['firstCase']<=index),key=lambda p:p['firstCase'])
  assert part['parents']==[parent];stats['atomicCases']+=1
 return dict(scope=__doc__,source=str(path),rawBytes=len(raw),rawSHA256=sha(raw),**stats,randomStreams={hex(k):v for k,v in streams.items()},instructionStarts=len(pcs),blobs=len(blobs),blobBytes=sum(map(len,blobs.values())),unknownReads=[dict(pc=hex(pc),address=hex(p),bytes=n,count=v) for (pc,p,n),v in unknown.items()],nativeCompared=False,windowsVerified=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 result=verify(a.source);a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='unknownReads'},indent=2))
