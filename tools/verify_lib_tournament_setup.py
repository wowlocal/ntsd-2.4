#!/usr/bin/env python3
"""Read-only full trace audit of retained Tournament roster/controller/shuffle/settings and ret4 or prelude boundaries.

Pinned NTSD EXE/lib.dll/VC80 and Unicorn2.1.4 observations recover 4229cc through429730/422ab8
text/input/output order, owned string production and retained library DC.
Replay every recorded store/read and final region; verify actual instruction
bytes and ordinary return ABI. This executes no game, edits no expected byte,
continues no fault, and establishes no Windows/device/own-catalog equivalence.
Actual41bc90 prologue establishes ordinary cookie/SEH backing; the declared
menu tail skips the intervening tick body. This is not an own complete tick.
See docs/research/LIB_TOURNAMENT_SETUP_PLAN.md for finite inputs and open boundaries.
"""
from pathlib import Path
import argparse,base64,collections,hashlib,json,struct,zlib
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256

def sha(raw):return hashlib.sha256(raw).hexdigest()

def verify(path):
 input_raw=path.read_bytes();d=json.loads(input_raw)
 exe=next(DEFAULT_SOURCE.glob('*.exe')).read_bytes();lib=(DEFAULT_SOURCE/'lib.dll').read_bytes()
 assert sha(exe)==EXE_SHA256==d['exeSHA256'] and sha(lib)==d['libSHA256']=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
 crt=(Path(__file__).resolve().parents[1]/'build/original/crt/msvcr80.dll').read_bytes()
 assert sha(crt)==d['crtSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'
 pe=PE(exe);lp=PE(lib);cp=PE(crt);blobs={}
 for key,b in d['blobs'].items():
  value=zlib.decompress(base64.b64decode(b['deflate']),-15)
  assert len(value)==b['count'] and sha(value)==key==b['sha256'];blobs[key]=value
 def decode_record(x):
  value=blobs[x['storage']['bytes']];mask=blobs[x['storage']['defined']]
  assert len(value)==len(mask) and set(mask)<={0,1}
  return bytearray(value),bytearray(mask)
 def exe_bytes(p,n):return exe[pe.offset(p-0x400000):pe.offset(p-0x400000)+n]
 stats=collections.Counter();pcs={};ends=collections.Counter();events=collections.Counter();unknown=collections.Counter();bitmap_unknown=collections.Counter();last_dc=0
 previous=None
 assert len(d['cases'])==len(d['installations'])==373
 assert [c['spec'] for c in d['cases']]==json.loads((path.parent/'lib-tournament-setup-finite-inputs.json').read_bytes())
 for index,(c,install) in enumerate(zip(d['cases'],d['installations'])):
  label=c['spec']['label']
  control=c['spec']['control']
  state={x['address']:decode_record(x) for x in c['before']};alive={x['address']:x['live'] for x in c['before'] if x['live'] is not None}
  assert len(state)==830+len(d['arenas']['entries'])+1 and len(alive)==20
  if c['spec'].get('chain'):
   assert previous is not None
   prior={x['address']:decode_record(x) for x in previous['after']}
   for x in c['stimulus']+c['callerABI']:
    p=x['address'];raw=bytes.fromhex(x['bytes']);matches=[(a,v,m) for a,(v,m) in prior.items() if a<=p and p+len(raw)<=a+len(v)];assert len(matches)==1
    a,v,m=matches[0];v[p-a:p-a+len(raw)]=raw;m[p-a:p-a+len(raw)]=b'\1'*len(raw)
   assert prior==state,(label,'retained previous complete state plus declared inputs/ABI')
   assert [(x['address'],x['live']) for x in previous['after']]==[(x['address'],x['live']) for x in c['before']]
  previous=c
  assert c['cw']==0x23f and c['end'] in ('returned','tournamentPrelude')
  assert install['base']==d['libraryAddress']==0x36000000 and install['preferredBase']==lp.base and install['libSHA256']==sha(lib) and install['result']==1
  assert len(install['patches'])==13 and [a['count'] for a in install['allocations']]==[4000,20000]
  for p in install['patches']:assert bytes.fromhex(p['before'])==exe_bytes(p['address'],p['count']) and len(bytes.fromhex(p['after']))==p['count']
  assert [e for e in install['events'] if e['name']=='RtlMoveMemory']==[dict(name='RtlMoveMemory',returnPC=e['returnPC'],**p) for e,p in zip([e for e in install['events'] if e['name']=='RtlMoveMemory'],install['patches'])]
  protections={}
  for e in install['events']:
   if e['name']=='VirtualProtect':
    p,n,v,out=e['arguments'];page=p&~4095;assert n in (2,5) and e['result']==1 and e['oldProtection']==protections.get(page,0x20);protections[page]=v
  assert all(v==0x20 for v in protections.values())
  for rel in install['relocations']:
   p=rel['offset'];assert struct.unpack('<I',lib[lp.offset(p):lp.offset(p)+4])[0]==rel['before']
   assert rel['after']==(rel['before']+install['base']-lp.base)&0xffffffff
  assert len(set(install['instructions']))==len(install['instructions']) and all(0x36001000<=p<0x36001c96 for p in install['instructions'])
  def owner(p,n):
   found=[(a,v) for a,v in state.items() if a<=p and p+n<=a+len(v[0])];assert len(found)==1,(label,hex(p),n)
   a,(v,m)=found[0];return a,v,m,p-a
  # Independently build all six declared atlas inputs, without source after-state.
  for i in range(5):
   value=bytearray(0x1f50);struct.pack_into('<4I',value,0,0x26004000+i*16,64,64,500)
   for j in range(500):
    for off,x in ((0x10,j%8*8),(0x7e0,j%8*8),(0xfb0,8),(0x1780,8)):struct.pack_into('<I',value,off+j*4,x)
   assert state[0x27000020+i*0x2000]==(value,bytearray(b'\1'*0x1f50))
  control=c['spec']['control'];panel=0x27000020+(0xc000 if control else 0xa000)
  value=bytearray((i*37+11)&255 for i in range(0x1f50)) if control else bytearray(b'\xa5'*0x1f50);mask=bytearray(0x1f50)
  def put(off,values):
   raw=struct.pack('<'+'I'*len(values),*values);value[off:off+len(raw)]=raw;mask[off:off+len(raw)]=b'\1'*len(raw)
  put(0,[0x26004050,794,550,11])
  rects=[[0,0,397,34],[397,0,397,34],[0,34,198,194],[198,34,198,194],[396,34,198,194],[594,34,198,194],[0,228,198,194],[198,228,198,194],[396,228,198,194],[594,228,198,194],[0,422,794,128]]
  for i in range(13):
   rect=rects[i] if i<11 else [i%8*8,i%8*8,8,8]
   for off,x in zip((0x10,0x7e0,0xfb0,0x1780),rect):put(off+i*4,[x])
  assert state[panel]==(value,mask)
  lib_before=bytes(state[0x36000000][0]);initial_dc=int.from_bytes(lib_before[0x306e:0x3072],'little')
  assert initial_dc==(last_dc if c['spec'].get('chain') else 0)
  for pc,code in c['instructions'].items():
   p=int(pc,16);value=bytes.fromhex(code)
   if p>=0x78130000:expected=crt[cp.offset(p-cp.base):cp.offset(p-cp.base)+len(value)]
   elif p>=0x36000000:expected=lib_before[p-0x36000000:p-0x36000000+len(value)]
   else:
    expected=exe_bytes(p,len(value))
    for patch in install['patches']:
     start=patch['address'];new=bytes.fromhex(patch['after'])
     expected=bytes(new[q-start] if start<=q<start+len(new) else expected[q-p] for q in range(p,p+len(value)))
   assert value==expected,(label,pc,value.hex(),expected.hex());assert pc not in pcs or pcs[pc]==code;pcs[pc]=code
  reads=collections.defaultdict(list)
  for kind,items in [('instruction',c['reads']),('API',c['apiReads'])]:
   for x in items:reads[x['storeCount']].append((kind,x))
  def lifetime(prefix):
   result=dict(alive)
   for event in prefix:
    if event['kind']=='free':assert result[event['arguments'][0]];result[event['arguments'][0]]=False
    elif event['kind']=='startup':
     e=event['startup'];p=0
     if e.get('kind')=='allocate':p=e['address']
     if e.get('kind')=='music' and e['music']['kind']=='allocate':p=e['music']['response']['pointer'] or 0
     if p:assert not result[p];result[p]=True
   return result
  points=collections.defaultdict(list)
  for point in c['points']:points[point['storeCount']].append(point)
  for step in range(len(c['writes'])+1):
   for point in points.pop(step,[]):
    assert len(point['records'])==830+len(d['arenas']['entries'])+1
    for x in point['records']:
     assert state[x['address']]==decode_record(x),(label,point['kind'],hex(x['address']),'full point bytes/mask')
     if x['live'] is not None:
      expected=lifetime(c['events'][:point['eventCount']])[x['address']]
      assert x['live']==expected
     stats['pointRecords']+=1;stats['pointRecordBytes']+=len(state[x['address']][0])
    assert 0<=point['readCount']<=len(c['reads']) and 0<=point['eventCount']<=len(c['events'])
    stats['points']+=1
   for kind,x in reads.pop(step,[]):
    p,n=x['address'],x['count'];value=bytes.fromhex(x['bytes']);mask=bytes(x['known']);assert n==len(value)==len(mask)
    if kind=='instruction':assert hex(x['pc']) in c['instructions']
    if x.get('kind')=='pinnedEXE':assert value==exe_bytes(p,n) and mask==b'\1'*n
    else:
     a,v,m,off=owner(p,n);assert v[off:off+n]==value and m[off:off+n]==mask,(label,kind,step,x)
     if 0 in mask:
      # Base masks are write coverage for original globals. Their initial
      # cookie/worker toggle bytes are pinned EXE data, not unknown stack.
      if p in (0x44eea4,0x44d784):
       assert value==exe_bytes(p,n) and kind=='instruction';unknown[(x['pc'],p,n)]+=1
      else:
       assert kind=='instruction' and x['pc'] in (0x43f04b,0x43f183,0x43f18c,0x43f190,0x43f197,0x43f19e) and a>=0x50000020 and off=={0x43f04b:12,0x43f183:12,0x43f18c:12,0x43f190:0xfac,0x43f197:0x7dc,0x43f19e:0x177c}[x['pc']] and n==4 and mask==bytes(4)
       initial=next(v for v in c['before'] if v['address']==a)
       assert value==blobs[initial['storage']['bytes']][off:off+4]
       assert any(e['kind']=='read' and e['read']==dict(offset=off,value=int.from_bytes(value,'little'),defined=False) for e in c['events'][x['eventIndex']:x['eventIndex']+1])
       bitmap_unknown[(x['pc'],n)]+=1
    assert 0<=x['eventIndex']<=len(c['events'])
    stats[kind+'Reads']+=1;stats[kind+'ReadBytes']+=n
   if step==len(c['writes']):break
   w=c['writes'][step];p=w['address'];value=bytes.fromhex(w['bytes']);a,v,m,off=owner(p,len(value));v[off:off+len(value)]=value;m[off:off+len(value)]=b'\1'*len(value)
   assert 0<=w['eventIndex']<=len(c['events'])
   if w['pc'] is None:assert len(value) in (4,24,26,108) and (0x10000000<=p<0x10010000 or 0x44d000<=p<0x458440 or 0x2c010020<=p<0x2c01003a)
   else:assert hex(w['pc']) in c['instructions']
   if a==0x36000000:assert p==0x3600306e and len(value)==4 and c['spec'].get('dcResult',0)>=0 and int.from_bytes(value,'little')==c['spec'].get('dc',0x76543210)
   stats['writes']+=1;stats['writeBytes']+=len(value)
  assert not reads and not points
  for event in c['events']:
   events[event['kind']]+=1
  alive=lifetime(c['events'])
  for event in c['events']:
   if event['kind']=='fill':
    f=event['fill'];assert f['defined']==[i<4 or 0x50<=i<0x54 for i in range(100)]
    assert f['effects'][:4]==[100,0,0,0] and f['effects'][0x50:0x54] in ([0x65,0x25,0x12,0],[255,255,255,0],[0,0,0,0],[0x9a,0x4d,0x32,0])
  for x in c['after']:
   p=x['address'];assert state[p]==decode_record(x),(label,hex(p),'full final bytes/mask')
   if x['live'] is not None:assert x['live']==alive[p]
   stats['records']+=1;stats['recordBytes']+=len(state[p][0])
  lib_after=bytes(state[0x36000000][0]);assert lib_before[:0x306e]==lib_after[:0x306e] and lib_before[0x3072:]==lib_after[0x3072:]
  for h in c['helpers']:
   assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4 and h['firstStore']<=h['lastStore']<=len(c['writes']) and h['eventStart']<=h['eventEnd']<=len(c['events'])
   if h['entry']==0x401290:
    assert h['arguments'][0]==d['target'] and len(h['text'])<4096
    assert any(x['address']==h['textAddress'] and bytes.fromhex(x['bytes'])==bytes(h['text'])+b'\0' and all(x['known']) for x in c['apiReads'])
   stats['helpers']+=1
  assert c['saved']==[0x11223344,0x22334455,0x33445566,0x44556677]
  assert c['points'][0]['sp']==d['tailSP']==d['entrySP']-0x644
  assert c['screenSP'] is None
  assert c['characterSP']==d['tailSP']-0xab4
  if c['end']=='returned':
   assert c['endSP']==d['entrySP']+8 and not c['pending'] and c['endPC']==0x30000000
   assert [p['kind'] for p in c['points']][-4:]==['character-0x42e0d2','menuReturned','matchBeforeReturn','returned']
   assert state[0]==(bytearray(bytes.fromhex('78563412')),bytearray(b'\1'*4))
   assert c['instructions']['0x42e0f9']=='c20c00' and c['instructions']['0x422ab8']=='c20400'
   assert sum(h['entry']==0x429730 and h['pop']==12 for h in c['helpers'])==1
  else:
   assert c['end']=='tournamentPrelude' and c['endPC']==0x4338c3 and c['endSP']==c['characterSP']-0xa14
   assert [h['entry'] for h in c['pending']]==[0x429730,0x432ab0] and all(h['pop']==12 for h in c['pending'])
   assert c['points'][-1]['kind']=='tournament-0x4338c3' and '0x4338c3' not in c['instructions']
  if True:
   points=[p for p in c['points'] if p['kind'].startswith(('character-','tournament-'))]
   assert [p['kind'] for p in points[:3]]==['tournament-0x432af2','tournament-0x432be2','tournament-0x432c76']
   for point in points:
    assert point['sp']==c['characterSP']-(0xa14 if point['kind'].startswith('tournament-') else 0);stack=decode_record(next(x for x in point['records'] if x['address']==d['stackAddress']))
    for key,value in point.get('locals',{}).items():
     off=point['sp']+int(key)-d['stackAddress'];assert all(stack[1][off:off+4]);assert int.from_bytes(stack[0][off:off+4],'little')==value
    stats['characterSemanticCounterWords']+=len(point.get('locals',{}))
   # Only independently declared400 Actor bindings can appear in the table.
   assert len(c['actorAddresses'])==400 and len(set(c['actorAddresses']))==400
   for index,p in enumerate(c['actorAddresses']):
    assert p==0x25000020+(399-index if c['spec']['control'] else index)*0x500
    assert state[d['worldAddress']][0][0x194+index*4:0x198+index*4]==p.to_bytes(4,'little')
   assert int.from_bytes(state[d['worldAddress']][0][0x7d4:0x7d8],'little')==0x60000020
   for seat in range(8):
    p=c['actorAddresses'][seat];binding=int.from_bytes(state[p][0][0x368:0x36c],'little');assert binding in [x['address'] for x in d['roster']['entries']]
  assert c['points'][1]['kind']=='musicReturned' and c['points'][2]['kind']=='resources-prefix'
  assert not any(e['kind']=='panel' for e in c['events'])

  last_dc=int.from_bytes(state[0x36000000][0][0x306e:0x3072],'little')
  ends[c['end']]+=1
 # Embedded resources and every successful API bitmap/description output derive
 # from pinned DIBs or the preceding native-equivalent descriptor request.
 resources={x['path'][1]:x for x in pe.resources() if x['path'][0]==2}
 assert len(d['assets'])==11
 for asset_path,asset in d['assets'].items():
  item=resources[asset_path];dib=exe[item['fileOffset']:item['fileOffset']+item['size']]
  assert asset['kind']=='embedded' and blobs[asset['raw']]==dib
  width,height=struct.unpack_from('<ii',dib,4);planes,bpp=struct.unpack_from('<HH',dib,12)
  assert [width,abs(height),planes,bpp]==[asset[k] for k in ('width','height','planes','bpp')]
 for c in d['cases']:
  startup=c['startup'];assert [e['startup'] for e in c['events'] if e['kind']=='startup']==startup['events']
  surfaces={}
  for e in startup['events']:
   if 'request' not in e:continue
   q,response=e['request'],e['response'];kind=q['kind']
   if kind=='getObject' and response['result']:
    a=startup['images'][str(q['words'][0])]['asset'];w,h,bpp,planes=(a[k] for k in ('width','height','bpp','planes'))
    expected=struct.pack('<4iHHI',0,w,h,((w*bpp+31)//32)*4,planes,bpp,0)
    assert response['writes']==[dict(offset=0,bytes=list(expected))]
   if kind=='createSurface' and response.get('output') is not None:surfaces[response['output']]=q['bytes']
   if kind=='description' and response['result']>=0:assert response['writes']==[dict(offset=0,bytes=surfaces[q['words'][0]])]
  for p,surface in startup['surfaces'].items():
   if not c['spec'].get('chain'):assert surfaces[int(p)]==surface['description']
  assert len(startup['allocations'])==11 and len(startup['records'])==(10 if c['end']=='nullSpark' else 11)
  expected=[0 if i in startup['spec'].get('nulls',[]) else 0x50000020+(10-i if c['spec']['control'] else i)*0x2000 for i in range(11)]
  assert [a['address'] for a in startup['allocations']]==expected
  for a in startup['allocations']:
   if a['address']:
    initial=bytes(i%256 for i in range(0x1f50)) if c['spec']['control'] else b'\xa5'*0x1f50
    assert blobs[a['backing']]==initial
  for record in startup['records']+startup['musicAllocations']:
   final=next(x for x in c['after'] if x['address']==record['address'])
   assert final['storage']==dict(bytes=record['bytes'],defined=record['mask']) and final['live']
  stats['freshBitmapRecords']+=len(startup['records']);stats['musicAllocations']+=len(startup['musicAllocations'])
 # Every completed atomic prefix is immutable and reproduced in the full output.
 for i,c in enumerate(d['cases']):
  x=json.loads((path.with_suffix('.parts')/f'{i:04d}.json').read_bytes());assert x['case']==c and x['installation']==d['installations'][i]
  assert all(d['blobs'][k]==v for k,v in x['blobs'].items()) and all(d['assets'][k]==v for k,v in x['assets'].items())
 # Recover declared catalog operands independently from original data files.
 from verify_character_roster_inputs import decode,text_read
 import re
 files={str(p.relative_to(DEFAULT_SOURCE)).replace('/','\\').lower():p for p in DEFAULT_SOURCE.rglob('*') if p.is_file()}
 def source(name):
  p=files[name.lower()];raw=p.read_bytes();assert dict(bytes=len(raw),sha256=sha(raw))==d['roster']['sourceFiles'][str(p.relative_to(DEFAULT_SOURCE))];return raw
 section=text_read(source('data\\data.txt')).split(b'<object>',1)[1].split(b'<object_end>',1)[0]
 rawentries=re.findall(rb'id:\s*([+-]?\d+)\s+type:\s*([+-]?\d+)\s+file:\s*([^\s]+)',section)
 assert len(rawentries)==len(d['roster']['entries'])==137
 initial={x['address']:decode_record(x) for x in d['cases'][0]['before']};catalog={}
 for i,((object_id,kind,path_bytes),entry) in enumerate(zip(rawentries,d['roster']['entries'])):
  path_name=path_bytes.decode('latin1');p=0x68000020+i*0x40000
  assert (entry['ordinal'],entry['id'],entry['type'],entry['path'],entry['address'])==(i,int(object_id),int(kind),path_name,p)
  decoded=decode(source(path_name),path_name);header=decoded.split(b'<bmp_begin>',1)[1].split(b'<bmp_end>',1)[0] if b'<bmp_begin>' in decoded else b''
  tokens=re.findall(rb'[^ \t\r\n\v\f]+',header);names=[tokens[n+1] for n,t in enumerate(tokens[:-1]) if t==b'name:'];heads=[tokens[n+1] for n,t in enumerate(tokens[:-1]) if t==b'head:']
  tail=bytearray(b'\xa5'*60);mask=bytearray(60)
  for name in [b'none']+names:tail[:len(name)+1]=name+b'\0';mask[:len(name)+1]=b'\1'*(len(name)+1)
  assert entry['nameTail']==tail.hex() and entry['nameMask']==mask.hex();catalog[p+0x25324]=(tail,mask)
  words=bytearray(struct.pack('<ii',int(object_id),int(kind))+b'\xa5'*4);known=bytearray(b'\1'*8+b'\0'*4)
  if heads:
   head=heads[-1].decode('latin1');bmp=source(head);width,height=struct.unpack_from('<ii',bmp,18);address=0x72000020+i*0x2000
   assert entry['portrait']==dict(path=head,width=width,height=height,address=address,surface=0x24000000)
   words[8:12]=struct.pack('<I',address);known[8:12]=b'\1'*4
   value=bytearray(b'\xa5'*0x1f50);struct.pack_into('<Iii',value,0,0x24000000,width,height);catalog[address]=(value,bytearray(b'\1'*12+bytes(0x1f50-12)))
  else:assert entry['portrait'] is None
  catalog[p+0x6f4]=(words,known)
  small=[tokens[n+1] for n,t in enumerate(tokens[:-1]) if t==b'small:']
  if small:
   name=small[-1].decode('latin1');file=files[name.lower()];bmp=file.read_bytes()
   assert dict(bytes=len(bmp),sha256=sha(bmp))==d['roster']['smallSourceFiles'][str(file.relative_to(DEFAULT_SOURCE))]
   width,height=struct.unpack_from('<ii',bmp,18);address=0x74000020+i*0x2000
   assert entry['small']==dict(path=name,width=width,height=height,address=address,surface=0x24000000)
   catalog[p+0x728]=(bytearray(struct.pack('<I',address)),bytearray(b'\1'*4))
   value=bytearray(b'\xa5'*0x1f50);struct.pack_into('<Iii',value,0,0x24000000,width,height)
   catalog[address]=(value,bytearray(b'\1'*12+bytes(0x1f50-12)))
  else:assert entry['small'] is None
 catalog[0x60000020]=(bytearray(struct.pack('<137I',*[0x68000020+i*0x40000 for i in range(137)])),bytearray(b'\1'*(137*4)))
 catalog[0x64d823a0]=(bytearray(struct.pack('<I',137)),bytearray(b'\1'*4))
 assert len(catalog)==402
 for c in d['cases']:
  for states in [c['before'],c['after']]+[p['records'] for p in c['points']]:
   records={x['address']:x for x in states}
   for p,expected in catalog.items():assert decode_record(records[p])==expected,(c['spec']['label'],hex(p),'read-only catalog operand retained')
 # Independently derive arena names from raw files and pinned constructor literals.
 arena=d['arenas'];assert (arena['backgroundBase'],arena['recordSize'],arena['nameOffset'])==(0x4d45db0,0x990,0x3cc)
 for relative,pin in arena['sourceFiles'].items():
  raw=(DEFAULT_SOURCE/relative).read_bytes();assert dict(bytes=len(raw),sha256=sha(raw))==pin
 section=text_read(source('data\\data.txt')).split(b'<background>',1)[1].split(b'<background_end>',1)[0]
 entries=re.findall(rb'id:\s*([+-]?\d+)\s+file:\s*([^\s]+)',section);assert len(entries)==arena['count']
 views={0x64d823a4:(bytearray(struct.pack('<I',len(entries))),bytearray(b'\1'*4))}
 assert len(arena['entries'])==len(entries)+2
 for item in arena['entries']:
  ordinal=item['ordinal']
  if ordinal in (99,100):
   name={99:b'Lee On Road\0',100:b'Random\0'}[ordinal];assert name in exe
  else:
   path_name=entries[ordinal][1].decode('latin1');assert item['path']==path_name
   raw=files[path_name.lower()].read_bytes();decoded=decode(raw,path_name)
   tokens=re.findall(rb'[^ \t\r\n\v\f]+',decoded);names=[tokens[i+1] for i,t in enumerate(tokens[:-1]) if t==b'name:'];assert len(names)==1
   name=names[0][:29].replace(b'_',b' ')+b'\0'
  assert bytes.fromhex(item['name'])==name
  views[0x60000020+0x4d45db0+ordinal*0x990+0x3cc]=(bytearray(name),bytearray(b'\1'*len(name)))
 for c in d['cases']:
  for records in [c['before'],c['after']]+[p['records'] for p in c['points']]:
   by_address={x['address']:x for x in records}
   for p,v in views.items():assert decode_record(by_address[p])==v
  if not c['spec'].get('chain'):
   g,m=decode_record(next(x for x in c['before'] if x['address']==0x44d000));off=0x44ff90-0x44d000
   seed=0xffffffff if c['spec']['control'] else 17;table=bytearray()
   for _ in range(3000):
    seed=(seed*0x343fd+0x269ec3)&0xffffffff;table.append(((seed>>16)&0x7fff)%255+1)
   assert g[off:off+3001]==table+b'\0' and m[off:off+3001]==b'\1'*3001 and 0 not in table

 assert ends=={'returned':372,'tournamentPrelude':1}
 streams=collections.Counter();controller_labels=collections.Counter();shuffle_calls=0
 for c in d['cases']:
  label=c['spec']['label'];control=c['spec']['control'];suffix='-control' if control else ''
  before_g=decode_record(next(x for x in c['before'] if x['address']==0x44d000))[0]
  g=decode_record(next(x for x in c['after'] if x['address']==0x44d000))[0]
  word=lambda p:struct.unpack_from('<i',g,p-0x44d000)[0]
  assert word(0x451160)==2
  if not c['spec'].get('chain'):
   assert before_g[0x44d31c-0x44d000:0x44d31e-0x44d000]==exe_bytes(0x44d31c,2)==b'x\0'
  rng=[h for h in c['helpers'] if h['entry']==0x417170]
  if any(h['stream'] in (0xf7,0xf8) for h in rng):
   assert [h['stream'] for h in rng]==[0xf7,0xf8]*50;shuffle_calls+=1
   order=list(struct.unpack_from('<8i',before_g,0x44d0e0-0x44d000))
   for a,b in zip(rng[::2],rng[1::2]):
    first,second=a['result'],b['result'];order[first],order[second]=order[second],order[first]
   assert order==list(struct.unpack_from('<8i',g,0x44d0e0-0x44d000)) and sorted(order)==list(range(8))
  for h in c['helpers']:
   if h['entry']==0x417170:
    assert h['stream'] in (1,0xf7,0xf8,0xf9);streams[h['stream']]+=1
    live=bytearray(before_g)
    for w in c['writes'][:h['firstStore']]:
     p=w['address'];raw=bytes.fromhex(w['bytes'])
     if 0x44d000<=p and p+len(raw)<=0x44d000+len(live):live[p-0x44d000:p-0x44d000+len(raw)]=raw
    selected=struct.unpack_from('<8i',live,0x44d0c0-0x44d000)
    if h['stream']==0xf9:
     expected=[x['ordinal'] for x in d['roster']['entries'] if x['ordinal']>=1 and x['type']==0 and x['id']<30 and x['ordinal'] not in selected]
     event=c['events'][h['eventStart']-1];assert event['kind']=='candidates' and event['arguments'][1:]==expected
     assert h['range']==len(expected) and 0<=h['result']<len(expected);stats['liveCandidateLists']+=1
    else:assert h['range']==8
    index=(h['index']+1)%3000;counter=(h['counter']+1)%1234
    assert h['result']==(live[0x44ff90-0x44d000+index]+counter)%h['range']
    event=c['events'][h['eventEnd']];assert event==dict(kind='random',arguments=[h['stream'],h['range'],h['result'],h['index'],h['counter'],index,counter],strings=[])
   if h['entry']==0x401290 and h['textAddress']==0x44d31c:
    assert len(h['text'])==1 and h['text'][0] in (67,49,50)
    # The same call writes the label byte; the terminator is retained file data.
    writes=[w for w in c['writes'][:h['firstStore']] if w['address']==0x44d31c]
    assert writes and bytes.fromhex(writes[-1]['bytes'])==bytes(h['text'])
    assert g[0x44d31d-0x44d000]==0;controller_labels[chr(h['text'][0])]+=1
  if label=='shuffle-wait-7'+suffix:assert word(0x44d020)==22 and word(0x4513d8)==11 and word(0x4513dc)==0
  if label=='reselect-press'+suffix:assert word(0x44d020)==20
  if label=='reselect-held'+suffix:assert word(0x44d020)==21 and word(0x4513e8)==0 and word(0x4513e4)==0
  if label=='arena-next-16-press':assert word(0x44d024)==100 and word(0x44d028)==1
  if label=='arena-next-17-press':assert word(0x44d024)==99 and word(0x44d028)==0
  if label=='arena-next-18-press':assert word(0x44d024)==0 and word(0x44d028)==0
  if label=='start':assert word(0x44d020)==25 and word(0x44d024)==21%(d['arenas']['count']+2) and word(0x44d028)==0 and word(0x451340)==2 and [word(0x44d0c0+i*4) for i in range(2)]==[17,21]
  if label=='quit-control':assert word(0x44d020)==10 and word(0x451340)==0
 assert shuffle_calls==22 and streams[0xf7]==streams[0xf8]==1100
 assert streams[0xf9]==stats['liveCandidateLists'] and streams[0xf9]>0
 stats['shuffleCalls']=shuffle_calls;stats['controllerLabelCalls']=sum(controller_labels.values())


 return dict(scope=__doc__,controllerLabels=dict(controller_labels),randomStreams={hex(k):v for k,v in streams.items()},undefinedBitmapReads=[dict(pc=hex(pc),bytes=n,reads=count) for (pc,n),count in bitmap_unknown.items()],rawBytes=len(input_raw),rawSHA256=sha(input_raw),cases=len(d['cases']),ends=dict(ends),**stats,events=dict(events),instructionStarts=len(pcs),exeInstructionStarts=sum(int(p,16)<0x36000000 for p in pcs),libraryInstructionStarts=sum(0x36000000<=int(p,16)<0x36005000 for p in pcs),crtInstructionStarts=sum(int(p,16)>=0x78130000 for p in pcs),blobCount=len(blobs),decodedBlobBytes=sum(map(len,blobs.values())),writeMaskFalseReadsWithPinnedEXEProvenance=[dict(pc=hex(pc),address=hex(p),bytes=n,reads=count) for (pc,p,n),count in unknown.items()],nativeCompared=False,windowsVerified=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 result=verify(a.source);a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
