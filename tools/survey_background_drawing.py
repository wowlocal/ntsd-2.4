#!/usr/bin/env python3
"""Inventory drawing fields from the pinned original whole BG loader capture.
This is a data survey, not a new execution or native drawing comparison.
"""
import hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(raw):return hashlib.sha256(raw).hexdigest()
def main():
 evidence=json.loads((ROOT/'docs/evidence/background-loader.json').read_bytes())
 parent=next(c for c in evidence['corpora'] if c['name']=='baseline')
 raw=(ROOT/'build/original'/parent['corpus']).read_bytes();assert digest(raw)==parent['corpusSHA256']
 doc=json.loads(raw);assert doc['exeSHA256']==evidence['exeSHA256']
 fields={'key':0x3ec,'width':0x464,'x':0x4dc,'y':0x554,'height':0x5cc,'step':0x644,'start':0x6bc,'end':0x734,'period':0x7ac,'counter':0x824,'color':0x89c}
 arenas=[];unknown=[]
 for c in doc['cases']:
  if c['kind']!='parse':continue
  data=bytes.fromhex(c['after']['bytes']);mask=c['after']['defined']
  def integer(offset):
   if not all(mask[offset:offset+4]):return None
   return struct.unpack_from('<i',data,offset)[0]
  count=integer(0x1c);assert count is not None and 0<=count<=30
  layers=[]
  for i in range(count):
   layer={k:integer(o+4*i) for k,o in fields.items()}
   for k,v in layer.items():
    if v is None:unknown.append(dict(arena=c['index'],layer=i,field=k))
   layers.append(layer)
  arenas.append(dict(ordinal=c['index'],path=c['path'],width=integer(0),minimumZ=integer(4),maximumZ=integer(8),layers=layers))
 assert len(arenas)==17
 all_layers=[l for a in arenas for l in a['layers']]
 report=dict(exeSHA256=doc['exeSHA256'],scope=__doc__,parent=dict(corpus=parent['corpus'],sha256=parent['corpusSHA256']),arenas=arenas,
  summary=dict(arenas=len(arenas),layers=len(all_layers),bitmapLayers=sum(l['color']==0 for l in all_layers),rectangleLayers=sum(l['color']!=0 for l in all_layers),
   animatedBitmapLayers=sum(l['color']==0 and l['period'] is not None and l['period']>0 for l in all_layers),
   loopSteps=sorted({l['step'] for l in all_layers if l['color']==0 and l['step'] is not None}),
   widths=sorted({a['width'] for a in arenas}),narrowArenas=[a['ordinal'] for a in arenas if a['width']<794]),undefined=unknown)
 path=ROOT/'docs/evidence/background-drawing-dat.json';path.write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(dict(summary=report['summary'],undefined=len(unknown)),indent=2))
if __name__=='__main__':main()
