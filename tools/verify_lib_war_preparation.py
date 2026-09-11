#!/usr/bin/env python3
"""Read-only22-call War parent/first-preparation audit.
Pinned original NTSD EXE/lib/VC80, original resources and controlled
Unicorn2.1.4/CW023f observations. Reconstruct every byte/mask/read/checkpoint,
validate actual ret1c/ret4, retained parent and four accepted parent reproductions.
Check owned arena/music/replay buffers, distinct CPU/human placement, pending
stack words, filename and initialization order. These low-level checks recover
game compatibility; no expected edits, source execution/fault continuation,
Windows/device/full game or Native-equivalence claim.
LIB_WAR_PREPARATION_PARENT_PLAN.md defines the finite preflight boundary.
"""
import argparse,base64,bisect,collections,datetime,hashlib,json,struct,zlib
from pathlib import Path
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256

def sha(raw):return hashlib.sha256(raw).hexdigest()
def canonical(x):return json.dumps(x,separators=(',',':')).encode()

def stream_document(path):
 decoder=json.JSONDecoder();hash=hashlib.sha256();count=0;buffer='';case_hashes=[]
 with path.open('rb') as f:
  def more():
   nonlocal buffer,count
   b=f.read(8*1024*1024);assert b,'Unexpected end of source document';hash.update(b);count+=len(b);buffer+=b.decode('ascii')
  more();assert buffer.startswith('{"cases":[');buffer=buffer[len('{"cases":['):]
  while True:
   buffer=buffer.lstrip()
   if not buffer:more();continue
   if buffer[0]==']':buffer=buffer[1:];break
   if buffer[0]==',':buffer=buffer[1:];continue
   try:c,end=decoder.raw_decode(buffer)
   except json.JSONDecodeError:more();continue
   case_hashes.append(sha(canonical(c)));buffer=buffer[end:]
  tail=f.read();hash.update(tail);count+=len(tail);buffer+=tail.decode('ascii')
  assert buffer.startswith(',');metadata=json.loads('{'+buffer[1:])
 return metadata,case_hashes,dict(bytes=count,sha256=hash.hexdigest())

def verify(path):
 total=22
 d,case_hashes,raw_pin=stream_document(path);stats=collections.Counter();unknown=collections.Counter();recording_unknown=collections.Counter();pcs={};streams=collections.Counter()
 manifest=json.loads((path.parent/'war-preparation-parent-manifest1.json').read_text())
 assert len(case_hashes)==len(d['installations'])==len(manifest)==total
 files=[(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes(),(DEFAULT_SOURCE/'lib.dll').read_bytes(),(ROOT/'build/original/crt/msvcr80.dll').read_bytes()]
 assert [sha(b) for b in files]==[EXE_SHA256,'28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba','c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d']
 assert [d[k] for k in ('exeSHA256','libSHA256','crtSHA256')]==[sha(b) for b in files]
 images=[PE(b) for b in files];blobs={}
 for k,v in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and sha(b)==k==v['sha256'];blobs[k]=b
 def storage(r):
  b,m=(blobs[r[k]] for k in ('bytes','defined'));assert len(b)==len(m) and set(m)<={0,1};return bytearray(b),bytearray(m)
 def records(items):return {r['address']:storage(r['storage']) for r in items}
 def exe(p,n):
  rva=p-0x400000;s=next(s for s in images[0].sections if s['rva']<=rva and rva+n<=s['rva']+max(s['fileSize'],s['virtualSize']))
  offset=rva-s['rva'];known=max(0,min(n,s['fileSize']-offset))
  return files[0][s['fileOffset']+offset:s['fileOffset']+offset+known]+bytes(n-known)
 def instructions(items,lib,patches):
  for key,value in items.items():
   p=int(key,16);b=bytes.fromhex(value)
   if p>=0x78130000:o=images[2].offset(p-images[2].base);expected=files[2][o:o+len(b)]
   elif 0x36000000<=p<0x36005000:expected=lib[p-0x36000000:p-0x36000000+len(b)]
   else:
    expected=bytearray(exe(p,len(b)))
    for patch in patches:
     start=patch['address'];v=bytes.fromhex(patch['after'])
     for i in range(len(b)):
      if start<=p+i<start+len(v):expected[i]=v[p+i-start]
   assert b==expected,(hex(p),b.hex(),bytes(expected).hex())
   assert key not in pcs or pcs[key]==value;pcs[key]=value
 parents={p['firstCase']:p for p in d['parents']};previous=None
 preset_combinations=set();visited_cells=set();rep_pcs=collections.Counter();frame_phases=set();random_lists=[];action_pairs=set()
 for index,(spec,install) in enumerate(zip(manifest,d['installations'])):
  part=path.with_suffix('.parts')/f'{index:04d}.json';part_raw=part.read_bytes();part_doc=json.loads(part_raw);c=part_doc['case'];label=spec['label']
  assert sha(canonical(c))==case_hashes[index] and c['spec']==spec,(index,label,'atomic case/manifest')
  if index in (0,1,11,12):
   source_index_path=ROOT/'build/research/lib-war/lib-war-index1.json'
   source_index=json.loads(source_index_path.read_text())
   pin=source_index['cases'][{0:0,1:1,11:412,12:413}[index]];prior_raw=(source_index_path.parent/pin['path']).read_bytes()
   assert len(prior_raw)==pin['bytes'] and sha(prior_raw)==pin['sha256']
   prior=json.loads(prior_raw);prior_parents=prior['parents']
   if index>=11:assert prior_parents[0]['firstCase']==412;prior_parents[0]['firstCase']=11
   assert canonical(c)==canonical(prior['case']) and canonical(part_doc['parents'])==canonical(prior_parents)
   stats['source2ParentReproductions']+=1
  if index<10:
   pinfile=path.parent/'war-preparation-parent-capture3.pins.json';pins=json.loads(pinfile.read_text())
   first=path.parent/'war-preparation-parent-capture1.parts'/f'{index:04d}.json';first_raw=first.read_bytes()
   assert sha(first_raw)==pins[str(first.resolve())]
   assert canonical(c)==canonical(json.loads(first_raw)['case']);stats['firstCaptureCompleteReproductions']+=1
  assert part_doc['installation']==install
  for k,v in part_doc['blobs'].items():assert d['blobs'][k]==v
  stats['atomicCases']+=1;stats['atomicBytes']+=len(part_raw)
  del part_doc,part_raw
  state=records(c['before']);initial={p:(bytes(v),bytes(m)) for p,(v,m) in state.items()}
  if index in parents:
   parent=parents[index];constructors=parent['constructors'];assert len(constructors['calls'])==401
   instructions(constructors['instructions'],state[0x36000000][0],install['patches'])
   for j,call in enumerate(constructors['calls']):
    p=call['address'];v,m=storage(call['before'])
    for w in constructors['writes'][call['firstStore']:call['lastStore']]:
     a=w['address'];b=bytes.fromhex(w['bytes'])
     if p<=a and a+len(b)<=p+len(v):v[a-p:a-p+len(b)]=b;m[a-p:a-p+len(b)]=b'\1'*len(b)
    assert (v,m)==storage(call['after']) and call['entry']==(0x419e40 if j==0 else 0x4061d0)
    assert call['fpuBefore']['cw']==call['fpuAfter']['cw']==0x23f
    stats['constructorReturns']+=1
   for view in parent['fileBackedInputs']:
    p=view['address'];b=bytes.fromhex(view['bytes']);assert b==exe(p,len(b))
    # The parent first reads literal PE backing, then applies the declared
    # initial globals. In particular, control starts the pulse phase at3;
    # this is an input override of PE451b80=0, not a different source byte.
    expected=bytearray(b)
    for key,value in spec.get('globals',{}).items():
     address=int(key)
     if p<=address and address+4<=p+len(b):
      supplied=struct.pack('<I',value&0xffffffff)
      if expected[address-p:address-p+4]!=supplied:stats['declaredPEParentOverrides']+=1
      expected[address-p:address-p+4]=supplied
    assert state[0x44d000][0][p-0x44d000:p-0x44d000+len(b)]==expected,(label,'PE parent plus declared globals',hex(p))
  if spec.get('chain'):
   prior=records(previous['after']);declared=[]
   for p,v in spec.get('bridgeGlobals',{}).items():declared.append(dict(address=int(p),bytes=struct.pack('<I',v&0xffffffff).hex()))
   for row in spec.get('bridgeReady',[]):
    for off,v in [(0x364,row['team']),(0x368,d['roster']['entries'][row['object']]['address'])]:declared.append(dict(address=c['actorAddresses'][row['seat']]+off,bytes=struct.pack('<I',v).hex()))
   assert declared==c['bridge']
   stats['readyBridges']+=int('bridgeReady' in spec);stats['popupBridges']+=int('bridgeGlobals' in spec and 'bridgeReady' not in spec)
   for change in declared+c['stimulus']+c['callerABI']:
    p=change['address'];b=bytes.fromhex(change['bytes']);found=[(a,v,m) for a,(v,m) in prior.items() if a<=p and p+len(b)<=a+len(v)];assert len(found)==1
    a,v,m=found[0];v[p-a:p-a+len(b)]=b;m[p-a:p-a+len(b)]=b'\1'*len(b)
   assert prior==state,(label,'whole retained parent')
  previous=c
  assert c['cw']==0x23f
  if c['end']=='returned':
   assert c['endPC']==0x30000000 and c['endSP']==d['entrySP']+8 and not c['pending'];assert c['instructions']['0x422ab8']=='c20400'
   if c['warSP'] is not None:assert c['instructions']['0x439ecd']=='c21c00';stats['warReturns']+=1
   stats['wholeReturns']+=1
  else:
   assert c['end']==spec['end']=='warMatchPreparation' and c['endPC']==0x43a21f and c['endSP']==c['warSP']
   assert [h['entry'] for h in c['pending']]==[0x429730,0x438b40] and '0x43a21f' not in c['instructions'];stats['preparationBoundaries']+=1
  instructions(c['instructions'],state[0x36000000][0],install['patches'])
  assert install['base']==0x36000000 and install['result']==1 and len(install['patches'])==13
  for patch in install['patches']:assert bytes.fromhex(patch['before'])==exe(patch['address'],patch['count'])
  new={};alive={r['address']:r['live'] for r in c['before'] if r['live'] is not None}
  for ei,e in enumerate(c['events']):
   if e['kind']=='warBitmap' and e['startup'].get('kind')=='allocate':
    a=e['startup'];p=a['address'];g=c['warGraphics'];record=next(r for r in g['allocations'] if r['address']==p)
    assert p==0x76000020+(1-a['index'] if spec['control'] else a['index'])*0x2000 and a['count']==0x1f50 and p not in state
    state[p]=(bytearray(blobs[record['backing']]),bytearray(0x1f50));new[p]=ei;stats['warBitmapAllocations']+=1
  music_allocations=[e for e in c['bodyMusic'] if e['kind']=='allocate'];music_index=0
  for ei,e in enumerate(c['events']):
   if e['kind']=='preparationBitmap' and e['startup'].get('kind')=='allocate':
    a=e['startup'];p=a['address'];assert p==0x76004020+a['index']*0x2000 and a['count']==0x1f50 and p not in state
    row=next(x for x in c['preparationGraphics']['allocations'] if x['address']==p)
    assert blobs[row['backing']]==b'\xa5'*0x1f50
    state[p]=(bytearray(blobs[row['backing']]),bytearray(0x1f50));new[p]=ei;stats['arenaBitmapAllocations']+=1
   elif e['kind']=='calloc':
    p,n,size=e['arguments'];assert p==c['replayAddress']==0x75000020 and n==1 and size==0x630e18 and p not in state
    state[p]=(bytearray(size),bytearray(b'\1'*size));new[p]=ei;stats['recordingAllocations']+=1
   elif e['kind']=='allocate':
    record=music_allocations[music_index];music_index+=1
    assert e['arguments']==record['arguments'];p=record['response']['pointer'];count=e['arguments'][0];raw=bytes(record['response']['bytes'])
    assert p>=0x2c020020 and p not in state and len(raw)==count and count%2==0
    assert raw==(bytes(i%256 for i in range(count)) if spec['control'] else b'\xa5'*count)
    state[p]=(bytearray(raw),bytearray(count));new[p]=ei;stats['musicAllocations']+=1;stats['musicAllocationBytes']+=count
  assert music_index==len(music_allocations)
  addresses=sorted(state)
  def owner(p,n):
   i=bisect.bisect_right(addresses,p)-1;assert i>=0;a=addresses[i];v,m=state[a]
   assert a<=p and p+n<=a+len(v),(label,hex(p),n);return a,v,m,p-a
  def lifetimes(count):
   result=dict(alive)
   for e in c['events'][:count]:
    if e['kind'] in ('startup','warBitmap','preparationBitmap') and e['startup'].get('kind')=='allocate':result[e['startup']['address']]=True
    elif e['kind']=='allocate':result[next(e['response']['pointer'] for e in c['bodyMusic'] if e['kind']=='allocate')]=True
    elif e['kind']=='calloc':result[e['arguments'][0]]=True
    elif e['kind']=='free':assert result[e['arguments'][0]];result[e['arguments'][0]]=False
   return result
  points=collections.defaultdict(list);reads=collections.defaultdict(list);event_steps=collections.defaultdict(list)
  for point in c['points']:points[point['storeCount']].append(point)
  for kind,items in [('instruction',c['reads']),('API',c['apiReads'])]:
   for x in items:reads[x['storeCount']].append((kind,x))
  for ei,e in enumerate(c['events']):
   if e['kind']=='candidates':
    h=next(h for h in c['helpers'] if h['entry']==0x417170 and h['stream']==0x122 and h['eventStart']==ei+1)
    event_steps[h['firstStore']].append(e)
  for step in range(len(c['writes'])+1):
   for point in points.pop(step,[]):
    expected=records(point['records']);available={p for p in state if p not in new or new[p]<point['eventCount']};assert set(expected)==available,(label,point['kind'],'region lifetime')
    live=lifetimes(point['eventCount'])
    for r in point['records']:
     p=r['address'];assert state[p]==expected[p],(label,point['kind'],hex(p),'bytes/mask')
     if r['live'] is not None:assert r['live']==live[p]
     stats['pointRecords']+=1;stats['pointBytes']+=len(state[p][0])
    if point['kind'].startswith('war-0x'):
     assert point['sp']==c['warSP'] and point['fpu']['cw']==0x23f;stats['warPoints']+=1
     if point['kind']=='war-0x438bbb' and 'bridgeReady' in spec:
      g=state[0x44d000][0]
      for row in spec['bridgeReady']:
       i=row['seat'];actor=state[c['actorAddresses'][i]][0]
       assert struct.unpack_from('<i',g,0x451288+i*4-0x44d000)[0]==row['status'] and struct.unpack_from('<i',g,0x451248+i*4-0x44d000)[0]==row['object']
       assert struct.unpack_from('<i',actor,0x364)[0]==row['team'] and struct.unpack_from('<I',actor,0x368)[0]==d['roster']['entries'][row['object']]['address'];stats['readyConsumerBindings']+=1
    if point['kind'].startswith('war-preparation-'):
     pc=point['pc'];root=c['warSP'];assert point['sp']==root-(12 if pc==0x43a766 else 0) and point['fpu']['cw']==0x23f
     for offset,value in point['locals'].items():
      _,v,m,o=owner(root+int(offset),4);assert struct.unpack_from('<I',v,o)[0]==value
     for offset,value in [(0x1c,0x44d020),(0x28,d['worldAddress']),(0x38,0x451160),(0x3c,d['worldAddress']+0x194)]+([] if pc==0x43a21f else [(0x2c,d['worldAddress']+4)]):
      _,v,m,o=owner(root+offset,4);assert v[o:o+4]==struct.pack('<I',value) and m[o:o+4]==b'\1'*4
     if point['name'] is not None:
      value=bytes.fromhex(point['name'])+b'\0';_,v,m,o=owner(root+0x84c,len(value));assert v[o:o+len(value)]==value and m[o:o+len(value)]==b'\1'*len(value)
     stats['preparationPoints']+=1
    stats['points']+=1
   for e in event_steps.pop(step,[]):
    seat=e['arguments'][0];g=state[0x44d000][0];selected=struct.unpack_from('<8i',g,0x451248-0x44d000)
    choices=[v['ordinal'] for v in d['roster']['entries'][1:] if v['type']==0 and v['id']<30 and v['ordinal'] not in selected]
    assert e['arguments']==[seat,*choices];random_lists.append(dict(case=index,seat=seat,choices=choices));stats['liveRandomLists']+=1
   for kind,x in reads.pop(step,[]):
    p,n=x['address'],x['count'];b=bytes.fromhex(x['bytes']);m=bytes(x['known']);assert len(b)==len(m)==n
    if kind=='instruction':assert hex(x['pc']) in c['instructions']
    if x.get('kind')=='pinnedEXE':assert b==exe(p,n) and m==b'\1'*n
    else:
     a,v,mask,o=owner(p,n);assert v[o:o+n]==b and mask[o:o+n]==m,(label,kind,step,hex(p),'read provenance')
     assert a not in new or new[a]<x['eventIndex']
     if 0 in m:unknown[(x['pc'],p,n)]+=1
     if 0x43d2c0<=x['pc']<=0x43db38:
      if not all(m):recording_unknown[(x['pc'],p,n,b.hex(),tuple(m))]+=1
      stats['recordingReads']+=1;stats['recordingReadBytes']+=n
    stats[kind+'Reads']+=1;stats[kind+'ReadBytes']+=n
   if step==len(c['writes']):break
   w=c['writes'][step];p=w['address'];b=bytes.fromhex(w['bytes']);a,v,m,o=owner(p,len(b));assert a not in new or new[a]<w['eventIndex']
   if w['pc'] is not None:assert hex(w['pc']) in c['instructions']
   v[o:o+len(b)]=b;m[o:o+len(b)]=b'\1'*len(b);stats['stores']+=1;stats['storedBytes']+=len(b)
   if w['pc'] in (0x43962b,0x439637,0x439647,0x439652,0x43965b,0x439663):visited_cells.add(p)
   if w['pc']==0x4389c5:frame_phases.add(struct.unpack('<i',b)[0])
  assert not points and not reads and not event_steps and state==records(c['after']),(label,'whole final storage')
  for h in c['helpers']:
   assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4 and h['firstStore']<=h['lastStore']<=len(c['writes']);stats['helperReturns']+=1
   if h['entry']==0x417170:
    i=(h['index']+1)%3000;counter=(h['counter']+1)%1234;v=initial[0x44d000][0]
    assert h['result']==(v[0x44ff90-0x44d000+i]+counter)%h['range'];streams[h['stream']]+=1
  for rep in c['reps']:
   assert bytes.fromhex(rep['after'])==(bytes.fromhex(rep['input']) if rep['source'] is not None else bytes.fromhex(rep['input'])*(rep['count']//4))
   assert 0<=rep['firstStore']<=rep['lastStore']<=len(c['writes']);rep_pcs[rep['pc']]+=1;stats['completeREPs']+=1;stats['REPBytes']+=rep['count']
  if 'preset-table-' in label and 'release' not in label:
   g=state[0x44d000][0];word=lambda p:struct.unpack_from('<i',g,p-0x44d000)[0]
   side=word(0x451ba8);preset=word(0x44d760)-5;strength=word(0x451b98+side*4)+1
   assert side in (0,1) and preset in range(5) and strength in (1,2,3)
   for i in range(11):
    total=word(0x44d388+(preset*11+i)*4)*strength//3;front=word(0x44d468+(preset*11+i)*4)*strength//3
    if front<1 and total>0:front=1
    assert word(0x44d5f8+(side*11+i)*4)==front and word(0x44d650+(side*11+i)*4)==max(0,total-front)
   preset_combinations.add((side,preset,strength));stats['presetTableCells']+=11
  if spec.get('expectedPreparation'):
   entry=records(next(p for p in c['points'] if p['kind']=='war-preparation-0x43a21f')['records'])
   eg=entry[0x44d000][0];fg=state[0x44d000][0];integer=lambda b,o:struct.unpack_from('<i',b,o)[0]
   word=lambda b,a:integer(b,a-0x44d000);arena=word(fg,0x44d024)
   bg=entry[0x60000020+0x4d45db0+arena*0x990][0];width,lower,upper=struct.unpack_from('<iii',bg)
   cleared=records(next(p for p in c['points'] if p['kind']=='war-preparation-0x43a305')['records'])
   assert cleared[d['worldAddress']][0][4:404]==bytes(400)
   draws=[h for h in c['helpers'] if h['entry']==0x417170 and h['stream'] in (0x125,0x127)]
   actual=[]
   for seat in range(8):
    status=word(eg,0x451288+seat*4)
    if status<=0:continue
    cpu=status>10;slot=seat+10 if cpu else seat;actual.append(slot)
    source=entry[c['actorAddresses'][seat]][0];b=state[c['actorAddresses'][slot]][0]
    object=struct.unpack_from('<I',source,0x368)[0];team=integer(source,0x364);assert team in (1,2)
    assert b[0x368:0x36c]==struct.pack('<I',object) and integer(b,0x31c)==integer(entry[object+0x90][0],0)
    assert integer(b,0x364)==integer(b,0x344)==team and integer(b,8)==75 and integer(b,0x354)==slot
    assert integer(b,0x340)==word(eg,0x44d754+team*4) and integer(b,0x308)==200
    h=draws[len(actual)-1];assert h['stream']==(0x125 if cpu else 0x127) and h['range']==upper-lower
    x=100 if team==1 else width-100;z=h['result']+lower
    assert [integer(b,o) for o in (0x10,0x14,0x18)]==[x,0,z] and b[0x58:0x70]==struct.pack('<ddd',float(x),0.0,float(z))
    stats['preparedCPU' if cpu else 'preparedHuman']+=1;stats['preparedParticipants']+=1
   assert len(draws)==len(actual)==8 and [i for i in range(400) if state[d['worldAddress']][0][i+4]]==actual
   prefix=('%4d%02d%02d_%02d%02d%02d_Battle'%tuple(spec['localTime'][i] for i in (0,1,3,4,5,6))).encode();filename=prefix+b'.lfr\0'
   assert fg[0x44fd98-0x44d000:0x44fd98-0x44d000+len(filename)]==filename
   naming=[h for h in c['helpers'] if h['entry']==0x7817775d and h['returnPC'] in (0x43a275,0x43a289)]
   assert [bytes.fromhex(h['output']) for h in naming]==[prefix,filename[:-1]]
   flags=[w['address'] for w in c['writes'] if w['pc'] in (0x43a70e,0x43a718)];assert flags==[0x44d034,0x450bbc]
   assert word(fg,0x44d034)==1 and word(fg,0x44d020)==0 and word(fg,0x450b80)==1
   pg=c['preparationGraphics'];assert pg['events']==[e['startup'] for e in c['events'] if e['kind']=='preparationBitmap']
   assert len(pg['allocations'])==(0 if arena==99 else integer(bg,0x1c))
   for row in pg['records']:assert state[row['address']]==(blobs[row['bytes']],blobs[row['mask']])
   replay=state[c['replayAddress']];assert len(replay[0])==0x630e18 and all(replay[1]);stats['recordingBytes']+=len(replay[0]);stats['wholePreparations']+=1
  stats['finalRecords']+=len(state);stats['finalBytes']+=sum(len(v) for v,m in state.values())
  if index%25==0:print('audited',index,label,flush=True)
 assert stats['wholeReturns']==22 and stats['warReturns']==20 and stats['preparationBoundaries']==0
 assert stats['source2ParentReproductions']==4 and stats['firstCaptureCompleteReproductions']==10
 assert stats['constructorReturns']==802 and stats['readyConsumerBindings']==16 and stats['warBitmapAllocations']==4
 assert stats['wholePreparations']==2 and stats['preparedParticipants']==16
 assert stats['preparedCPU']==6 and stats['preparedHuman']==10
 assert stats['recordingAllocations']==2 and streams[0x123]==2 and streams[0x125]==6 and streams[0x127]==10
 resources={x['path'][1]:x for x in images[0].resources() if x['path'][0]==2}
 for name,a in d['assets'].items():
  if a['kind']=='embedded':r=resources[name];b=files[0][r['fileOffset']:r['fileOffset']+r['size']];dib=b
  else:b=(DEFAULT_SOURCE/name.replace('\\','/')).read_bytes();assert b[:2]==b'BM';dib=b[14:]
  assert blobs[a['raw']]==b;w,h=struct.unpack_from('<ii',dib,4);planes,bpp=struct.unpack_from('<HH',dib,12)
  assert [w,abs(h),planes,bpp]==[a[k] for k in ('width','height','planes','bpp')]
 for group in [d['roster']['sourceFiles'],d['roster']['smallSourceFiles'],d['arenas']['sourceFiles']]:
  for name,pin in group.items():b=(DEFAULT_SOURCE/name).read_bytes();assert dict(bytes=len(b),sha256=sha(b))==pin
 coverage=dict(preflightCalls=22,preparations=2,parentCallsReproduced=4,recordingInputsBound=not recording_unknown,complete=not recording_unknown)
 return dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),raw=raw_pin,cases=len(case_hashes),counts=dict(stats),instructionStarts=len(pcs),instructions=pcs,randomStreams=dict(streams),liveRandomLists=random_lists,REPStarts=dict(rep_pcs),presetCombinations=sorted(preset_combinations),editedCells=sorted(visited_cells),framePhases=sorted(frame_phases),blobs=len(blobs),decodedBlobBytes=sum(map(len,blobs.values())),unknownReads=[dict(pc=p,address=a,count=n,occurrences=v) for (p,a,n),v in sorted(unknown.items())],sourceAudited=True,unboundRecordingInputs=[dict(pc=pc,address=p,count=n,bytes=raw,known=list(m),occurrences=k) for (pc,p,n,raw,m),k in recording_unknown.items()],coverage=coverage,finiteAcceptanceComplete=coverage['complete'],nativeCompared=False,windowsVerified=False,wholeGameComplete=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 result=verify(a.source);a.output.write_text(json.dumps(result,indent=2)+'\n');print({k:result[k] for k in ('cases','counts','instructionStarts','blobs','finiteAcceptanceComplete','coverage')})
