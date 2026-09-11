#!/usr/bin/env python3
"""Read-only complete War setup evidence audit, not original execution.
Pinned EXE/lib/VC80 and DAT/BMP/DIB references, controlled Unicorn2.1.4/CW023f.
Reconstruct whole records/masks from declared inputs and real writes; verify
every read, checkpoint, helper/REP return, live Random list and preset result.
Stream raw JSON and audit one atomic case at a time to bound host memory.
Separate profiles retain574 setup,192 cell-traversal and40 multi-human-action
calls. The latter two reproduce their exact original parent calls first.
LIB_WAR_SETUP_PLAN.md and LIB_WAR_SETUP_INPUTS.md retain source input correction,
unknown backing and BEFORE43a21f boundary. No expected edits, source-fault
continuation, Windows/device/full app or Native equivalence claim.
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

def verify(path,limit=None,profile='setup'):
 assert profile in ('setup','cells','multiaction')
 total={'setup':574,'cells':192,'multiaction':40}[profile]
 d,case_hashes,raw_pin=stream_document(path);stats=collections.Counter();unknown=collections.Counter();pcs={};streams=collections.Counter()
 manifest_name={'setup':'lib-war-manifest3.json','cells':'lib-war-cells-manifest1.json','multiaction':'lib-war-multiaction-manifest1.json'}[profile]
 manifest=json.loads((path.parent/manifest_name).read_text())
 if limit is None:assert len(case_hashes)==len(d['installations'])==len(manifest)==total
 else:assert len(case_hashes)==len(d['installations'])==limit;manifest=manifest[:limit]
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
  if profile in ('cells','multiaction') and index<2:
   source_index=json.loads((path.parent/'lib-war-index1.json').read_text())
   pin=source_index['cases'][index+(412 if profile=='multiaction' else 0)];prior_raw=(path.parent/pin['path']).read_bytes()
   assert len(prior_raw)==pin['bytes'] and sha(prior_raw)==pin['sha256']
   prior=json.loads(prior_raw)
   prior_parents=prior['parents']
   if profile=='multiaction':assert prior_parents[0]['firstCase']==412;prior_parents[0]['firstCase']=0
   assert canonical(c)==canonical(prior['case']) and canonical(part_doc['parents'])==canonical(prior_parents)
   stats['source2ParentReproductions']+=1
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
  if profile=='cells' and 'expectedEdit' in spec:
   edit=spec['expectedEdit'];row=edit['row'];side=edit['side'];unit=edit['unit']
   assert row in range(1,5) and side in (0,1) and unit in (range(6) if row<=2 else range(6,11))
   address=(0x44d5f8 if row%2 else 0x44d650)+(side*11+unit)*4
   assert edit['address']==address
   writes=[w for w in c['writes'] if w['pc'] in (0x43962b,0x439637,0x439647,0x439652,0x43965b,0x439663)]
   assert writes and {w['address'] for w in writes}=={address}
   stats['declaredCellEdits']+=1
  if profile=='multiaction' and 'expectedActions' in spec:
   action=spec['expectedActions'];row=action['row'];mask=action['mask']
   assert row in (1,2) and mask in range(1,8)
   address=0x44d5f8 if row==1 else 0x44d650;assert action['address']==address
   point=next(p for p in c['points'] if p['kind']=='war-0x438bbb')
   g=records(point['records'])[0x44d000][0]
   actual=sum((struct.unpack_from('<i',g,p-0x44d000)[0]!=0)<<i for i,p in enumerate((0x4513b4,0x4513b8,0x4513bc)))
   assert actual==mask and (row,mask) not in action_pairs;action_pairs.add((row,mask))
   writes=[w for w in c['writes'] if w['pc'] in (0x43962b,0x439637,0x439647,0x439652,0x43965b,0x439663)]
   assert writes and {w['address'] for w in writes}=={address};stats['declaredActionCombinations']+=1
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
  addresses=sorted(state)
  def owner(p,n):
   i=bisect.bisect_right(addresses,p)-1;assert i>=0;a=addresses[i];v,m=state[a]
   assert a<=p and p+n<=a+len(v),(label,hex(p),n);return a,v,m,p-a
  def lifetimes(count):
   result=dict(alive)
   for e in c['events'][:count]:
    if e['kind'] in ('startup','warBitmap') and e['startup'].get('kind')=='allocate':result[e['startup']['address']]=True
    elif e['kind']=='allocate':result[next(e['response']['pointer'] for e in c['bodyMusic'] if e['kind']=='allocate')]=True
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
    if point['kind'].startswith('war-'):
     assert point['sp']==c['warSP'] and point['fpu']['cw']==0x23f;stats['warPoints']+=1
     if point['kind']=='war-0x438bbb' and 'bridgeReady' in spec:
      g=state[0x44d000][0]
      for row in spec['bridgeReady']:
       i=row['seat'];actor=state[c['actorAddresses'][i]][0]
       assert struct.unpack_from('<i',g,0x451288+i*4-0x44d000)[0]==row['status'] and struct.unpack_from('<i',g,0x451248+i*4-0x44d000)[0]==row['object']
       assert struct.unpack_from('<i',actor,0x364)[0]==row['team'] and struct.unpack_from('<I',actor,0x368)[0]==d['roster']['entries'][row['object']]['address'];stats['readyConsumerBindings']+=1
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
  stats['finalRecords']+=len(state);stats['finalBytes']+=sum(len(v) for v,m in state.values())
  if index%25==0:print('audited',index,label,flush=True)
 if limit is None:
  assert frame_phases=={0,1,2,3}
  if profile=='setup':
   assert preset_combinations=={(s,p,k) for s in range(2) for p in range(5) for k in range(1,4)}
   assert stats['wholeReturns']==573 and stats['warReturns']==571 and stats['preparationBoundaries']==1
   assert stats['readyConsumerBindings']==16 and stats['constructorReturns']==802 and stats['warBitmapAllocations']==4
  elif profile=='cells':
   assert not preset_combinations and stats['source2ParentReproductions']==2 and stats['declaredCellEdits']==44
   assert stats['wholeReturns']==192 and stats['warReturns']==191 and stats['preparationBoundaries']==0
   assert stats['readyConsumerBindings']==8 and stats['constructorReturns']==401 and stats['warBitmapAllocations']==2
   assert visited_cells==set(range(0x44d5f8,0x44d6a8,4))
  else:
   assert not preset_combinations and stats['source2ParentReproductions']==2 and stats['declaredActionCombinations']==14
   assert action_pairs=={(row,mask) for row in (1,2) for mask in range(1,8)}
   assert stats['wholeReturns']==40 and stats['warReturns']==39 and stats['preparationBoundaries']==0
   assert stats['readyConsumerBindings']==8 and stats['constructorReturns']==401 and stats['warBitmapAllocations']==2
   assert visited_cells=={0x44d5f8,0x44d650}
 resources={x['path'][1]:x for x in images[0].resources() if x['path'][0]==2}
 for name,a in d['assets'].items():
  if a['kind']=='embedded':r=resources[name];b=files[0][r['fileOffset']:r['fileOffset']+r['size']];dib=b
  else:b=(DEFAULT_SOURCE/name.replace('\\','/')).read_bytes();assert b[:2]==b'BM';dib=b[14:]
  assert blobs[a['raw']]==b;w,h=struct.unpack_from('<ii',dib,4);planes,bpp=struct.unpack_from('<HH',dib,12)
  assert [w,abs(h),planes,bpp]==[a[k] for k in ('width','height','planes','bpp')]
 for group in [d['roster']['sourceFiles'],d['roster']['smallSourceFiles'],d['arenas']['sourceFiles']]:
  for name,pin in group.items():b=(DEFAULT_SOURCE/name).read_bytes();assert dict(bytes=len(b),sha256=sha(b))==pin
 # Capture2's simultaneous Right/Defense stimuli edit only seven cells.
 # Preserve the44-cell acceptance requirement and report its remaining gap
 # separately from successful reconstruction of every captured byte/mask.
 expected_cells={0x44d5f8,0x44d650} if profile=='multiaction' else set(range(0x44d5f8,0x44d6a8,4))
 coverage=dict(expectedEditableCells=sorted(expected_cells),missingEditableCells=sorted(expected_cells-visited_cells),actionCombinations=sorted(action_pairs),complete=limit is None and visited_cells==expected_cells)
 return dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),raw=raw_pin,cases=len(case_hashes),counts=dict(stats),instructionStarts=len(pcs),instructions=pcs,randomStreams=dict(streams),liveRandomLists=random_lists,REPStarts=dict(rep_pcs),presetCombinations=sorted(preset_combinations),editedCells=sorted(visited_cells),framePhases=sorted(frame_phases),blobs=len(blobs),decodedBlobBytes=sum(map(len,blobs.values())),unknownReads=[dict(pc=p,address=a,count=n,occurrences=v) for (p,a,n),v in sorted(unknown.items())],sourceAudited=True,coverage=coverage,finiteAcceptanceComplete=coverage['complete'],nativeCompared=False,windowsVerified=False,wholeGameComplete=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--profile',choices=['setup','cells','multiaction'],default='setup');a=p.parse_args();assert not a.output.exists()
 result=verify(a.source,a.limit,a.profile);result['profile']=a.profile;a.output.write_text(json.dumps(result,indent=2)+'\n');print({k:result[k] for k in ('cases','counts','instructionStarts','blobs','finiteAcceptanceComplete','coverage')})
