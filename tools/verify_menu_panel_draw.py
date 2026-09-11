#!/usr/bin/env python3
"""Read-only compatibility audit of original423b00 panel/timer/cold-tail calls.
Verify pinned NTSD bytes, actual code starts, full store/read/mask provenance,
owned atlas inputs, retained globals, complete ABI returns and explicit stops.
No source execution, expected edits, fault continuation or Windows/device claim.
The finite domain and unavailable-result boundaries are MENU_PANEL_DRAW_PLAN.md.
"""
from pathlib import Path
import argparse,base64,collections,hashlib,json,struct,zlib
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256

RECTS=[[0,0,397,34],[397,0,397,34],[0,34,198,194],[198,34,198,194],[396,34,198,194],[594,34,198,194],[0,228,198,194],[198,228,198,194],[396,228,198,194],[594,228,198,194],[0,422,794,128]]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def verify(path):
 raw=path.read_bytes();d=json.loads(raw);b=path.parent
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();lib=(DEFAULT_SOURCE/'lib.dll').read_bytes();pe=PE(exe)
 assert sha(exe)==EXE_SHA256==d['exeSHA256'] and sha(lib)==d['libSHA256']=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
 manifest=json.loads((b/'menu-panel-draw-finite-inputs.json').read_bytes())+json.loads((b/'menu-panel-draw-extension-inputs.json').read_bytes())
 assert [c['spec'] for c in d['cases']]==manifest and len(manifest)==1012
 blobs={}
 for k,v in d['blobs'].items():
  value=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(value)==v['count'] and sha(value)==k==v['sha256'];blobs[k]=value
 def record(x):
  raw=blobs[x['storage']['bytes']];mask=blobs[x['storage']['defined']];assert len(raw)==len(mask) and set(mask)<={0,1};return bytearray(raw),bytearray(mask)
 def exebytes(p,n):o=pe.offset(p-pe.base);return exe[o:o+n]
 stats=collections.Counter();events=collections.Counter();ends=collections.Counter();pcs={};last={}
 installations=d['installations'];assert len(installations)==1012 and all(i==installations[0] for i in installations)
 install=installations[0];assert install['base']==0x36000000 and install['result']==1 and len(install['patches'])==13 and [x['count'] for x in install['allocations']]==[4000,20000]
 for p in install['patches']:assert bytes.fromhex(p['before'])==exebytes(p['address'],p['count']) and len(bytes.fromhex(p['after']))==p['count']
 assert install==json.loads((b/'menu-panel-draw-probe2.json').read_bytes())['installations'][0]
 for index,c in enumerate(d['cases']):
  s=c['spec'];state={x['address']:record(x) for x in c['before']};assert len(state)==21
  alive={x['address']:x['live'] for x in c['before'] if x['live'] is not None};assert len(alive)==7 and all(alive.values())
  def owner(p,n):
   found=[(a,v) for a,v in state.items() if a<=p and p+n<=a+len(v[0])];assert len(found)==1,(s['label'],hex(p),n)
   a,(v,m)=found[0];return a,v,m,p-a
  if s.get('retained'):
   v,m=map(bytearray,last[s['control']])
   for p,x in s['globals'].items():off=int(p)-0x44d000;v[off:off+4]=struct.pack('<I',x&0xffffffff);m[off:off+4]=b'\1'*4
   for p,x in s['strings'].items():off=int(p)-0x44d000;raw=x.encode()+b'\0';v[off:off+len(raw)]=raw;m[off:off+len(raw)]=b'\1'*len(raw)
   assert state[0x44d000]==(v,m),(s['label'],'own retained globals')
  for i in range(5):
   p=0x27000020+0x2000*i;value=bytearray((j*37+11)&255 for j in range(0x1f50)) if s['control'] else bytearray(b'\xa5'*0x1f50);mask=bytearray(0x1f50)
   def put(off,values):
    raw=struct.pack('<'+'I'*len(values),*values);value[off:off+len(raw)]=raw;mask[off:off+len(raw)]=b'\1'*len(raw)
   put(0,[0x26004000+i*16,64,64,13])
   for j in range(13):
    for off,x in ((0x10,j%8*8),(0x7e0,j%8*8),(0xfb0,8),(0x1780,8)):put(off+j*4,[x])
   if i==(4 if s['control'] else 0):
    put(4,[794,550,11])
    for j,rect in enumerate(RECTS):
     for off,x in zip((0x10,0x7e0,0xfb0,0x1780),rect):put(off+j*4,[x])
    if s.get('nullSurface'):put(0,[0])
   assert state[p]==(value,mask),(s['label'],hex(p),'declared atlas input')
  for pc,code in c['instructions'].items():
   p=int(pc,16);value=bytes.fromhex(code);assert value==exebytes(p,len(value))
   assert not any(max(p,x['address'])<min(p+len(value),x['address']+x['count']) for x in install['patches'])
   assert pc not in pcs or pcs[pc]==code;pcs[pc]=code
  reads=collections.defaultdict(list)
  for kind,items in [('instruction',c['reads']),('API',c['apiReads'])]:
   for x in items:reads[x['storeCount']].append((kind,x))
  for step in range(len(c['writes'])+1):
   for kind,x in reads.pop(step,[]):
    p,n=x['address'],x['count'];value=bytes.fromhex(x['bytes']);mask=bytes(x['known']);assert len(value)==len(mask)==n and mask==b'\1'*n,(s['label'],x)
    if kind=='instruction':assert hex(x['pc']) in c['instructions']
    if x.get('kind')=='pinnedEXE':assert value==exebytes(p,n)
    else:a,v,m,off=owner(p,n);assert v[off:off+n]==value and m[off:off+n]==mask,(s['label'],kind,x)
    stats[kind+'Reads']+=1;stats[kind+'ReadBytes']+=n
   if step==len(c['writes']):break
   x=c['writes'][step];value=bytes.fromhex(x['bytes']);a,v,m,off=owner(x['address'],len(value))
   assert a in (0x44d000,0x10000000) and hex(x['pc']) in c['instructions'];v[off:off+len(value)]=value;m[off:off+len(value)]=b'\1'*len(value)
   stats['writes']+=1;stats['writeBytes']+=len(value)
  assert not reads
  for x in c['after']:
   assert state[x['address']]==record(x),(s['label'],hex(x['address']),'full final bytes/masks')
   if x['live'] is not None:assert x['live']==alive[x['address']]
   stats['records']+=1;stats['recordBytes']+=len(state[x['address']][0])
  for h in c['helpers']:
   assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4 and h['firstStore']<=h['lastStore']<=len(c['writes']) and h['eventStart']<=h['eventEnd']<=len(c['events']);stats['helpers']+=1
  assert c['cw']==0x23f
  if c['end']=='returned':assert c['endPC']==0x30000000 and c['endSP']==d['entrySP']+4 and not c['pending']
  elif c['end']=='zeroTimerRange':assert c['endPC']==0x423be8 and '0x423be8' not in c['instructions'] and c['events']==[dict(kind='timer',arguments=[17],strings=[])]
  else:assert c['end']=='noSelectableRow' and c['endPC']==0x423ed0 and c['scans']=={str(0x423ed0):9}
  ends[c['end']]+=1;events.update(e['kind'] for e in c['events'])
  for e in c['events']:
   if e['kind']=='fill':
    f=e['fill'];assert f['defined']==[i<4 or 0x50<=i<0x54 for i in range(100)] and f['effects'][:4]==[100,0,0,0] and f['effects'][0x50:0x54]==[255,255,255,0]
  if s.get('chain'):last[s['control']]=tuple(bytes(x) for x in state[0x44d000])
  parent='capture1' if index<1002 else 'extension1';part_index=index if index<1002 else index-1002
  part=json.loads((b/f'menu-panel-draw-{parent}.parts'/f'{part_index:04d}.json').read_bytes());assert part['case']==c and part['installation']==install and all(d['blobs'][k]==v for k,v in part['blobs'].items());stats['atomicParts']+=1
 static=json.loads((b/'menu-panel-draw-whole-static.json').read_bytes());missing=[x for x in static['instructions'] if hex(x['address']) not in pcs]
 assert [(x['address'],x['mnemonic']) for x in missing]==[(0x424028,'lea'),(0x42402f,'nop')]
 assert json.loads((b/'menu-panel-draw-probe2.json').read_bytes())['cases'][0]==d['cases'][0]
 return dict(scope=__doc__,rawBytes=len(path.read_bytes()),rawSHA256=sha(path.read_bytes()),cases=len(d['cases']),ends=dict(ends),events=dict(events),eventCount=sum(events.values()),**stats,instructionStarts=len(pcs),panelInstructionStarts=len(static['instructions'])-len(missing),panelStaticInstructions=len(static['instructions']),missingAlignment=missing,blobCount=len(blobs),decodedBlobBytes=sum(map(len,blobs.values())),undefinedObservedReads=0,allSourcePartsAndDeclaredAtlasInputsVerified=True,nativeCompared=False,windowsVerified=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists();d=verify(a.source);a.output.write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(d,indent=2))
