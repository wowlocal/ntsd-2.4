#!/usr/bin/env python3
"""Inventory original loaded cpoint fields; not execution or reachability proof.
Keeps raw signed actions and vaction addresses without repairing original data.
"""
import base64,collections,hashlib,json,struct,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(raw):return hashlib.sha256(raw).hexdigest()
def main():
 parent=json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_bytes())['corpora'][0]
 raw=(ROOT/'build/original'/parent['corpus']).read_bytes();assert digest(raw)==parent['corpusSHA256']
 assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/parent['fixture']).read_bytes())==parent['fixtureSHA256']
 doc=json.loads(raw)
 def blob(key):
  b=doc['blobs'][key];value=zlib.decompress(base64.b64decode(b['deflate']),-15);assert digest(value)==key and len(value)==b['count'];return value
 types=collections.Counter();states=collections.Counter();points=collections.Counter();outside=[];holders=[];frames=0;conditional=[]
 for item in doc['children']:
  if item['kind']!='object':continue
  path=ROOT/'downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a'/item['path'].replace('\\','/')
  assert digest(path.read_bytes())==item['source'];types[item['objectType']]+=1
  holders.append({key:item[key] for key in ('index','id','path','source')})
  raw=blob(item['storage']['bytes']);mask=blob(item['storage']['defined'])
  for n in range(400):
   offset=0x7a4+n*0x178;assert mask[offset]
   if not raw[offset]:continue
   assert all(mask[offset+0x88:offset+0x8c]) and all(mask[offset+8:offset+12])
   fields=tuple(struct.unpack_from('<i',raw,offset+0x88+4*i)[0] if all(mask[offset+0x88+4*i:offset+0x8c+4*i]) else None for i in range(17))
   state=struct.unpack_from('<i',raw,offset+8)[0]
   points[fields]+=1;states[state]+=1;frames+=1
   if fields[0]==1 and fields[9]!=0 and (fields[15] is None or fields[16] is None):conditional.append(dict(object=item['index'],sourceID=item['id'],path=item['path'],frame=n,state=state,cpoint=list(fields)))
   if fields[0] in (1,2) and fields[5] is not None and not 0<=fields[5]<400:outside.append(dict(object=item['index'],sourceID=item['id'],path=item['path'],frame=n,state=state,cpoint=list(fields)))
 report=dict(exeSHA256=doc['exeSHA256'],scope=__doc__,nativeCompared=False,
  parent=dict(fixture=parent['fixture'],sha256=parent['fixtureSHA256'],corpusSHA256=parent['corpusSHA256']),
  objectTypes=dict(types),holders=holders,holderFrames=frames,uniqueCpoints=len(points),states=dict(states),
  vactions=sorted({v[5] for v in points if v[5] is not None}),cpointKinds=dict(collections.Counter({k:sum(count for p,count in points.items() if p[0]==k) for k in {p[0] for p in points}})),undefinedFields={str(i):sum(count for p,count in points.items() if p[i] is None) for i in range(17)},kinds=sorted({v[0] for v in points}),outsideFrameArray=outside,conditionalUndefinedReads=conditional)
 (ROOT/'docs/evidence/world-cpoints-dat.json').write_text(json.dumps(report,indent=2)+'\n')
 print('Original holders',len(holders),'frames',frames,'unique cpoints',len(points),'outside frame array',len(outside))
if __name__=='__main__':main()
