#!/usr/bin/env python3
"""Inventory original Object/Frame drawing fields from pinned loaded-catalog.
Picture selection here applies static40be70 range arithmetic with Actor318=0;
this is neither a new source execution nor natural gameplay reachability proof.
"""
import base64,collections,hashlib,json,struct,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(raw):return hashlib.sha256(raw).hexdigest()
def signed(v):return (v+0x80000000)%0x100000000-0x80000000
def main():
 parent=json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_bytes())['corpora'][0]
 raw=(ROOT/'build/original'/parent['corpus']).read_bytes();assert digest(raw)==parent['corpusSHA256']
 assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/parent['fixture']).read_bytes())==parent['fixtureSHA256']
 doc=json.loads(raw);cache={}
 def blob(key):
  if key not in cache:
   b=doc['blobs'][key];value=zlib.decompress(base64.b64decode(b['deflate']),-15);assert digest(value)==key and len(value)==b['count'];cache[key]=value
  return cache[key]
 def record(storage):return blob(storage['bytes']),blob(storage['defined'])
 def word(data,mask,offset):
  if offset<0 or offset+4>len(data) or not all(mask[offset:offset+4]):return None
  return struct.unpack_from('<i',data,offset)[0]
 bitmaps={b['address']:(i,b) for i,b in enumerate(doc['bitmaps'])}
 objects=[];missing=[];undefined=[];states=collections.Counter();frames=0;pointframes=0;sheetsum=0;sheetcounts=collections.Counter()
 for item in doc['children']:
  if item['kind']!='object':continue
  path=ROOT/'downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a'/item['path'].replace('\\','/')
  assert digest(path.read_bytes())==item['source']
  data,mask=record(item['storage']);count=word(data,mask,0x498);assert count is not None and 0<=count<=10
  sheets=[];sheetcounts[count]+=1;sheetsum+=count
  for n in range(count):
   sheet={k:word(data,mask,offset+4*n) for k,offset in [('first',0x62c),('columns',0x6a4),('rows',0x6cc)]}
   assert all(v is not None for v in sheet.values())
   for label,offset in [('normal',0x754),('mirrored',0x77c)]:
    pointer=word(data,mask,offset+4*n);assert pointer is not None and (pointer&0xffffffff) in bitmaps
    index,bitmap=bitmaps[pointer&0xffffffff];sheet[label]=dict(index=index,path=bitmap['path'])
   sheets.append(sheet)
  used=collections.Counter();pics=set();points=[]
  for n in range(400):
   at=0x7a4+n*0x178;assert mask[at]
   if not data[at]:continue
   fields={k:word(data,mask,at+offset) for k,offset in [('picture',4),('state',8),('centerX',0x50),('centerY',0x54),('pointX',0x80),('pointY',0x84)]}
   for k,v in fields.items():
    if v is None:undefined.append(dict(object=item['index'],frame=n,field=k))
   frames+=1;states[fields['state']]+=1;pic=fields['picture'];pics.add(pic)
   if fields['pointX'] is not None and fields['pointX']>0:pointframes+=1;points.append(n)
   if pic is None:continue
   selected=next((i for i,s in enumerate(sheets) if s['first']<=pic<signed(s['first']+signed(s['rows']*s['columns']))),None)
   if selected is None:missing.append(dict(object=item['index'],sourceID=item['id'],path=item['path'],frame=n,**fields));continue
   used[selected]+=1;s=sheets[selected];bitmap=doc['bitmaps'][s['normal']['index']];br,bm=record(bitmap['storage']);offset=((pic-s['first'])*4+0xfb0)&0xffffffff
   if word(br,bm,offset) is None:undefined.append(dict(object=item['index'],frame=n,field='normalPictureWidth',offset=offset))
  objects.append(dict(index=item['index'],sourceID=item['id'],path=item['path'],sourceSHA256=item['source'],type=item['objectType'],sheets=sheets,basePictureUsage=dict(used),pictures=sorted(p for p in pics if p is not None),positivePointFrames=points))
 report=dict(exeSHA256=doc['exeSHA256'],scope=__doc__,parent=dict(fixture=parent['fixture'],sha256=parent['fixtureSHA256'],corpusSHA256=parent['corpusSHA256']),
  summary=dict(objects=len(objects),presentFrames=frames,sheets=sheetsum,sheetCounts=dict(sheetcounts),positivePointFrames=pointframes,basePicturesWithoutSheet=len(missing),undefinedDrawingFields=len(undefined),states=dict(states)),objects=objects,basePicturesWithoutSheet=missing,undefined=undefined)
 (ROOT/'docs/evidence/object-drawing-dat.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report['summary'],indent=2))
if __name__=='__main__':main()
