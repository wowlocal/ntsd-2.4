#!/usr/bin/env python3
"""Read-only audit of whole installed-library mode-screen and enabled-panel composition.

Pinned NTSD EXE/lib.dll and Unicorn2.1.4 observations recover whole431d10
text/input/output order, owned string production and retained library DC.
Replay every recorded store/read and final region; verify actual instruction
bytes and ordinary return ABI. This executes no game, edits no expected byte,
continues no fault, and establishes no Windows/device/own-catalog equivalence.
See docs/research/MODE_PANEL_SCREEN_PLAN.md for finite inputs and open boundaries.
"""
from pathlib import Path
import argparse,base64,collections,hashlib,json,struct,zlib
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256

def sha(raw):return hashlib.sha256(raw).hexdigest()

def verify(path):
 raw=path.read_bytes();d=json.loads(raw)
 exe=next(DEFAULT_SOURCE.glob('*.exe')).read_bytes();lib=(DEFAULT_SOURCE/'lib.dll').read_bytes()
 assert sha(exe)==EXE_SHA256==d['exeSHA256'] and sha(lib)==d['libSHA256']=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
 pe=PE(exe);lp=PE(lib);blobs={}
 for key,b in d['blobs'].items():
  value=zlib.decompress(base64.b64decode(b['deflate']),-15)
  assert len(value)==b['count'] and sha(value)==key==b['sha256'];blobs[key]=value
 def record(x):
  value=blobs[x['storage']['bytes']];mask=blobs[x['storage']['defined']]
  assert len(value)==len(mask) and set(mask)<={0,1}
  return bytearray(value),bytearray(mask)
 def exe_bytes(p,n):return exe[pe.offset(p-0x400000):pe.offset(p-0x400000)+n]
 stats=collections.Counter();pcs={};ends=collections.Counter();events=collections.Counter();unknown=collections.Counter();last_dc=0
 assert len(d['cases'])==len(d['installations'])==32
 assert [c['spec'] for c in d['cases']]==json.loads((path.parent/'mode-panel-screen-finite-inputs.json').read_bytes())
 for index,(c,install) in enumerate(zip(d['cases'],d['installations'])):
  label=c['spec']['label'];state={x['address']:record(x) for x in c['before']};alive={x['address']:x['live'] for x in c['before'] if x['live'] is not None}
  assert len(state)==22 and len(alive)==8
  assert c['cw']==0x23f and c['end'] in ('returned','playback','zeroTimerRange','noSelectableRow')
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
   if p>=0x36000000:expected=lib_before[p-0x36000000:p-0x36000000+len(value)]
   else:
    expected=exe_bytes(p,len(value))
    for patch in install['patches']:
     start=patch['address'];new=bytes.fromhex(patch['after'])
     expected=bytes(new[q-start] if start<=q<start+len(new) else expected[q-p] for q in range(p,p+len(value)))
   assert value==expected,(label,pc,value.hex(),expected.hex());assert pc not in pcs or pcs[pc]==code;pcs[pc]=code
  reads=collections.defaultdict(list)
  for kind,items in [('instruction',c['reads']),('API',c['apiReads'])]:
   for x in items:reads[x['storeCount']].append((kind,x))
  for step in range(len(c['writes'])+1):
   for kind,x in reads.pop(step,[]):
    p,n=x['address'],x['count'];value=bytes.fromhex(x['bytes']);mask=bytes(x['known']);assert n==len(value)==len(mask)
    if kind=='instruction':assert hex(x['pc']) in c['instructions']
    if x.get('kind')=='pinnedEXE':assert value==exe_bytes(p,n) and mask==b'\1'*n
    else:
     a,v,m,off=owner(p,n);assert v[off:off+n]==value and m[off:off+n]==mask,(label,kind,step,x)
     if 0 in mask:
      # Base masks are write coverage for original globals. Their initial
      # cookie/worker toggle bytes are pinned EXE data, not unknown stack.
      assert p in (0x44eea4,0x44d784) and value==exe_bytes(p,n) and kind=='instruction'
      unknown[(x['pc'],p,n)]+=1
    assert 0<=x['eventIndex']<=len(c['events'])
    stats[kind+'Reads']+=1;stats[kind+'ReadBytes']+=n
   if step==len(c['writes']):break
   w=c['writes'][step];p=w['address'];value=bytes.fromhex(w['bytes']);a,v,m,off=owner(p,len(value));v[off:off+len(value)]=value;m[off:off+len(value)]=b'\1'*len(value)
   assert 0<=w['eventIndex']<=len(c['events'])
   if w['pc'] is None:assert len(value)==4 and 0x10000000<=p<0x10010000
   else:assert hex(w['pc']) in c['instructions']
   if a==0x36000000:assert p==0x3600306e and len(value)==4 and c['spec'].get('dcResult',0)>=0 and int.from_bytes(value,'little')==c['spec'].get('dc',0x76543210)
   stats['writes']+=1;stats['writeBytes']+=len(value)
  assert not reads
  for event in c['events']:
   events[event['kind']]+=1
   if event['kind']=='free':p=event['arguments'][0];assert alive[p];alive[p]=False
   if event['kind']=='fill':
    f=event['fill'];assert f['defined']==[i<4 or 0x50<=i<0x54 for i in range(100)]
    assert f['effects'][:4]==[100,0,0,0] and f['effects'][0x50:0x54] in ([0x65,0x25,0x12,0],[255,255,255,0])
  for x in c['after']:
   p=x['address'];assert state[p]==record(x),(label,hex(p),'full final bytes/mask')
   if x['live'] is not None:assert x['live']==alive[p]
   stats['records']+=1;stats['recordBytes']+=len(state[p][0])
  lib_after=bytes(state[0x36000000][0]);assert lib_before[:0x306e]==lib_after[:0x306e] and lib_before[0x3072:]==lib_after[0x3072:]
  for h in c['helpers']:
   assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4 and h['firstStore']<=h['lastStore']<=len(c['writes']) and h['eventStart']<=h['eventEnd']<=len(c['events'])
   if h['entry']==0x401290:
    assert h['arguments'][0]==d['target'] and len(h['text'])<4096
    assert any(x['address']==h['textAddress'] and bytes.fromhex(x['bytes'])==bytes(h['text'])+b'\0' and all(x['known']) for x in c['apiReads'])
   stats['helpers']+=1
  if c['end']=='returned':assert c['endSP']==d['entrySP']+20 and not c['pending']
  if c['end']=='playback':assert c['endSP']==d['bodySP'] and len(c['pending'])==1
  if c['end']=='zeroTimerRange':assert c['endPC']==0x423be8 and len(c['pending'])==2
  if c['end']=='noSelectableRow':assert c['endPC']==0x423ed0 and c['scans']=={str(0x423ed0):9} and len(c['pending'])==2
  kinds=[e['kind'] for e in c['events']]
  if c['end']=='playback':assert 'panel' not in kinds and not any(h['entry']==0x423b00 for h in c['helpers'])
  elif c['end']=='returned':assert kinds.count('panel')==1 and sum(h['entry']==0x423b00 for h in c['helpers'])==1
  if label.startswith(('confirm-release','release-then-notice')):assert kinds.index('free')<kinds.index('panel')<kinds.index('timer')
  if label.startswith('release-then-notice'):assert kinds.index('timer')<kinds.index('shell')
  if label.startswith('outer-link-before-banner'):assert kinds.count('shell')==1 and kinds.index('shell')<kinds.index('panel')

  if c['spec'].get('chain'):last_dc=int.from_bytes(state[0x36000000][0][0x306e:0x3072],'little')
  ends[c['end']]+=1
 # Independently compare every retained atomic source part, including nominal.
 for i,c in enumerate(d['cases']):
  directory=path.parent/'mode-panel-screen-capture1.parts'
  x=json.loads((directory/f'{i:04d}.json').read_bytes());assert x['case']==c and x['installation']==d['installations'][i]
  assert all(d['blobs'][k]==v for k,v in x['blobs'].items())
 probe=json.loads((path.parent/'mode-panel-screen-probe1.json').read_bytes());assert probe['cases'][0]==d['cases'][0]
 return dict(scope=__doc__,rawBytes=len(raw),rawSHA256=sha(raw),cases=len(d['cases']),ends=dict(ends),**stats,events=dict(events),instructionStarts=len(pcs),exeInstructionStarts=sum(int(p,16)<0x36000000 for p in pcs),libraryInstructionStarts=sum(int(p,16)>=0x36000000 for p in pcs),blobCount=len(blobs),decodedBlobBytes=sum(map(len,blobs.values())),writeMaskFalseReadsWithPinnedEXEProvenance=[dict(pc=hex(pc),address=hex(p),bytes=n,reads=count) for (pc,p,n),count in unknown.items()],nativeCompared=False,windowsVerified=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 result=verify(a.source);a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
