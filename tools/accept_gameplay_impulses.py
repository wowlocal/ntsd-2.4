#!/usr/bin/env python3
"""Compare whole4196f0 and both fresh own post-draw continuations before publishing."""
import base64,hashlib,json,os,subprocess,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(raw):return hashlib.sha256(raw).hexdigest()
def main():
 captures=[];fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
 pins={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
 for suffix in ('','-control'):
  report=json.loads((ROOT/'build/research'/f'gameplay-impulses{suffix}.json').read_bytes())
  raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
  doc=json.loads(raw);assert [c['label'] for c in doc['cases']]==['post-draw-impulses']
  assert doc['exeSHA256']==report['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
  assert doc['dllSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'
  section=doc['cases'][0]
  assert section['impulses']['fpcw']==0 and not any(0x41971b<=pc<=0x419770 for pc in section['instructions'])
  assert digest((fixtures/doc['parent']['fixture']).read_bytes())==doc['parent']['sha256']
  for key,b in doc['blobs'].items():
   value=zlib.decompress(base64.b64decode(b['deflate']),-15);assert digest(value)==key and len(value)==b['count']
  captures.append(('gameplay-impulses'+suffix,report,raw))
 report=json.loads((ROOT/'build/research/world-impulses.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
 assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
 doc=json.loads(raw);assert len(doc['cases'])==report['cases']==1030 and len(doc['instructions'])==report['instructions']==58
 assert sum(len(c['events']) for c in doc['cases'])==report['writes']==9385
 assert len(doc['formats']['cases'])==report['formats']==256
 captures.append(('world-impulses',report,raw))
 subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','Original(WorldImpulses|GameplayImpulses)Tests'],env=dict(os.environ,NTSD_GAMEPLAY_IMPULSES_DIRECTORY=str(ROOT/'build/original'),NTSD_WORLD_IMPULSES_CORPUS=str(ROOT/'build/original/world-impulses.json')),check=True)
 assert all(digest((fixtures/name).read_bytes())==sha for name,sha in pins.items())
 for name,report,raw in captures:
  payload=raw[:-1];compressor=zlib.compressobj(level=9,wbits=-15);compressed=compressor.compress(payload)+compressor.flush()
  packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
  assert zlib.decompress(compressed,-15)==payload
  fixture=fixtures/f'original-{name}.json';fixture.write_bytes(packed)
  report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  report['scope']=report['scope'].replace('Source capture;\nnative comparison open.','Native comparison accepted for this bounded continuation; full tick and Windows remain open.')
  (ROOT/'docs/evidence'/f'{name}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 pins.update({p.name:digest(p.read_bytes()) for p in fixtures.glob('original-*impulses*.json')})
 (ROOT/'build/research/gameplay-impulses-fixture-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
if __name__=='__main__':main()
