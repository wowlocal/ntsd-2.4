#!/usr/bin/env python3
"""Derive known troop/frame dependency inputs from all806 audited War calls.
Pinned original NTSD EXE/lib/VC80 Unicorn2.1.4 evidence:574 setup,192 cell and
40 multi-human-action calls. Read only exact indexed atomic parts, reconstruct
live scalar inputs and preserve ordered original stores/fills. This is a
projection for Native comparisons, not original execution or whole acceptance.
"""
from pathlib import Path
import argparse,json,base64,zlib,struct,hashlib,datetime
from index_lib_war_setup import PROFILES
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--index',type=Path,action='append',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
frames=[];operations=[];globals_base=0x44d000;corpora=[]
ranges=[('initialize',0x438bdb,0x438c44),('selectPreset',0x439d08,0x439dcf),('selectStrength',0x439b29,0x439c0b),('selectNone',0x439c10,0x439c5d),('selectAll',0x439c62,0x439ce5),('adjust',0x439586,0x439669),('backup',0x439763,0x4397a0),('restoreJump',0x439a0f,0x439a5a),('restoreCancel',0x439f27,0x439f58),('finalize',0x43a1be,0x43a201)]

for corpus_index,index_path in enumerate(a.index):
 indexed=json.loads(index_path.read_bytes());profile=indexed.get('profile','setup');expected=PROFILES[profile]
 assert indexed['source']['sha256']==expected['sha256'] and indexed['source']['bytes']==expected['bytes'] and len(indexed['cases'])==expected['cases']
 audit_raw=Path(indexed['audit']['path']).read_bytes();assert hashlib.sha256(audit_raw).hexdigest()==indexed['audit']['sha256'];audit=json.loads(audit_raw);assert audit['sourceAudited'] is True and audit['cases']==expected['cases']
 start_ops=len(operations);start_frames=len(frames)
 for row in indexed['cases']:
  index=row['index'];raw=(index_path.parent/row['path']).read_bytes();assert len(raw)==row['bytes'] and hashlib.sha256(raw).hexdigest()==row['sha256']
  d=json.loads(raw);c=d['case'];spec=c['spec'];assert spec['label']==row['label']
  def blob(k):
   v=d['blobs'][k];raw=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(raw)==v['count'] and hashlib.sha256(raw).hexdigest()==k;return raw
  r=next(r['storage'] for r in c['before'] if r['address']==globals_base);g=bytearray(blob(r['bytes']));m=bytearray(blob(r['defined']))
  def word(a):
   o=a-globals_base;assert m[o:o+4]==b'\1'*4,(index,hex(a));return struct.unpack_from('<i',g,o)[0]
  group=[];op=None;entry=None
  def finish():
   global group,op,entry
   if not group:return
   assert entry is not None
   operations.append(dict(case=index,label=spec['label'],kind=op,inputs=entry,stores=group));group=[];op=None;entry=None
  for w in c['writes']:
   p=w['address'];raw=bytes.fromhex(w['bytes']);pc=w['pc'];kind=next((name for name,lo,hi in ranges if pc is not None and lo<=pc<=hi and (0x44d350<=p<0x44d778 or 0x451b38<=p<0x451bb4)),None)
   if globals_base<=p<p+len(raw)<=globals_base+len(g) and kind!=op:finish()
   if kind and not group:
    op=kind;side=word(0x451ba8);fields=[];params=dict(side=side)
    if kind=='selectPreset':params['preset']=word(0x44d760)-5;fields=[0x451b98+side*4]
    elif kind=='selectStrength':params['strength']=word(0x44d760)-1;fields=[0x451b90+side*4]
    elif kind=='adjust':
     row,cursor=word(0x44d770),word(0x44d76c);unit=(min(cursor,4)+6 if row>=3 else cursor);change='active' if row in (1,3) else 'reserve';cell=(0x44d5f8 if change=='active' else 0x44d650)+(side*11+unit)*4
     params.update(unit=unit,change=change,attack=word(0x4513b4)!=0,jump=word(0x4513b8)!=0,defense=word(0x4513bc)!=0);fields=[cell]
    elif kind=='backup':fields=[*range(0x44d5f8,0x44d6a8,4),0x451b98+side*4,0x451b90+side*4]
    elif kind.startswith('restore'):fields=[*range(0x44d548,0x44d5f8,4)]+([0x451b8c,0x451b88] if kind=='restoreJump' else [])
    elif kind=='finalize':fields=list(range(0x44d5f8,0x44d6a8,4))
    entry=dict(parameters=params,words=[[a,word(a)] for a in fields],known=True)
   if kind:assert len(raw)==4;group.append([p,struct.unpack('<i',raw)[0]])
   if globals_base<=p and p+len(raw)<=globals_base+len(g):g[p-globals_base:p-globals_base+len(raw)]=raw;m[p-globals_base:p-globals_base+len(raw)]=b'\1'*len(raw)
  finish()
  rows=[]
  for h in c['helpers']:
   if h['entry'] not in (0x4389a0,0x438ad0):continue
   events=c['events'][h['eventStart']:h['eventEnd']];assert events[0]['kind']=='warFrame';args=events[0]['arguments'];assert args[0]==h['entry'] and args[1:]==h['arguments']
   fills=[e['fill'] for e in events if e['kind']=='fill'];assert len(fills) in (4,8)
   rows.append(dict(firstStore=h['firstStore'],pulse=h['entry']==0x4389a0,arguments=h['arguments'],fills=fills))
  rows.sort(key=lambda x:x['firstStore']);frames.append(dict(case=index,label=spec['label'],fresh=not spec.get('chain',False),initialPhase=(3 if spec['control'] else 0) if not spec.get('chain',False) else None,afterPhase=word(0x451b80),frames=rows))
  if index%50==0:print('derived',index,len(operations),flush=True)

 corpora.append(dict(profile=profile,source=indexed['source'],cases=expected['cases'],firstOperation=start_ops,operations=len(operations)-start_ops,firstFrameCall=start_frames,frameCalls=len(frames)-start_frames))
assert [c['profile'] for c in corpora]==['setup','cells','multiaction']
result=dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),corpora=corpora,cases=sum(c['cases'] for c in corpora),operations=operations,frames=frames,nativeCompared=False,wholeNativeMenuCompared=False)
assert result['cases']==806
a.output.write_text(json.dumps(result,separators=(',',':'))+'\n');print('operations',len(operations),'frames',sum(len(c['frames']) for c in frames),'bytes',a.output.stat().st_size)
