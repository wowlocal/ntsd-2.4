#!/usr/bin/env python3
"""Compare only the CONTROL section of both pinned GAMEPLAY_ENTRY captures.
The producer is oracle_gameplay_entry.py. It reproduced its entire own parent
before continuing on the same CPU/stack. Physics bytes remain in the lossless
artifact for provenance, but are explicitly NOT natively compared here.
"""
import base64,hashlib,json,os,subprocess,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(raw):return hashlib.sha256(raw).hexdigest()
def main():
 captures=[]
 for suffix in ('','-control'):
  evidence=ROOT/'docs/evidence'/f'gameplay-entry{suffix}.json';source=json.loads(evidence.read_bytes())
  path=ROOT/'build/original'/source['corpus'];raw=path.read_bytes()
  assert digest(raw)==source['sha256'] and len(raw)==source['bytes']
  doc=json.loads(raw);assert [c['label'] for c in doc['cases']]==['control','physics']
  assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/doc['parent']['fixture']).read_bytes())==doc['parent']['sha256']
  for key,b in doc['blobs'].items():
   value=zlib.decompress(base64.b64decode(b['deflate']),-15);assert digest(value)==key and len(value)==b['count']
  captures.append((suffix,source,doc,raw))
 subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalGameplayControlTests'],
  env=dict(os.environ,NTSD_GAMEPLAY_CONTROL_DIRECTORY=str(ROOT/'build/original')),check=True)
 for suffix,source,doc,raw in captures:
  payload=raw[:-1];compressor=zlib.compressobj(level=9,wbits=-15);compressed=compressor.compress(payload)+compressor.flush()
  packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/f'original-gameplay-control{suffix}.json';fixture.write_bytes(packed)
  section=doc['cases'][0]
  report=dict(exeSHA256=doc['exeSHA256'],dllSHA256=doc['dllSHA256'],scope=__doc__,parent=doc['parent'],
   corpus=source['corpus'],sha256=digest(raw),bytes=len(raw),fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),
   nativeCompared=True,comparedSections=['control'],uncomparedSections=['physics'],end=section['end'],
   helpers=len(section['helpers']),actorReturns=sum(h['entry']==0x413080 for h in section['helpers']),
   comparedActorCheckpoints=sum(c['pc']==0x41e364 for c in section['checkpoints']),
   readsBeforeWrites=section['readsBeforeWrites'],sourceEvidence=f'gameplay-entry{suffix}.json')
  (ROOT/'docs/evidence'/f'gameplay-control{suffix}.json').write_text(json.dumps(report,indent=2)+'\n')
  print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
