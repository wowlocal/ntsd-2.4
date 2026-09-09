#!/usr/bin/env python3
"""Compare the freshly reproduced own419380/4064d0 continuation before publishing.
The entire prior MATCH_LAUNCH/control/physics/held-object chain is retained and compared.
"""
import base64,hashlib,json,os,subprocess,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(raw):return hashlib.sha256(raw).hexdigest()
def main():
 captures=[]
 for suffix in ('','-control'):
  report=json.loads((ROOT/'build/research'/f'gameplay-contacts{suffix}.json').read_bytes())
  raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
  doc=json.loads(raw);assert [c['label'] for c in doc['cases']]==['contacts']
  assert doc['exeSHA256']==report['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
  assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/doc['parent']['fixture']).read_bytes())==doc['parent']['sha256']
  for key,b in doc['blobs'].items():
   value=zlib.decompress(base64.b64decode(b['deflate']),-15);assert digest(value)==key and len(value)==b['count']
  captures.append(("gameplay-contacts"+suffix,report,raw))
 report=json.loads((ROOT/'build/research/world-contacts.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
 assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
 doc=json.loads(raw);assert len(doc['cases'])==report['cases']==7925 and doc['exeSHA256']==report['exeSHA256'] and sum(c['helpers'] for c in doc['cases'])==report['helpers']
 captures.append(('world-contacts',report,raw))
 subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','Original(WorldContacts|GameplayContacts)Tests'],env=dict(os.environ,NTSD_GAMEPLAY_CONTACTS_DIRECTORY=str(ROOT/'build/original'),NTSD_WORLD_CONTACTS_CORPUS=str(ROOT/'build/original/world-contacts.json')),check=True)
 for name,report,raw in captures:
  payload=raw[:-1];compressor=zlib.compressobj(level=9,wbits=-15);compressed=compressor.compress(payload)+compressor.flush()
  packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/f'original-{name}.json';fixture.write_bytes(packed)
  report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence'/f'{name}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
