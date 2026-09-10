#!/usr/bin/env python3
"""Publish immutable calendar dependency bytes after raw native acceptance.
Transport deflation is research packaging, not a native calendar algorithm.
Keep invalid-parameter/unknown-allocator stops distinct from whole matches.
"""
import json,base64,zlib,hashlib,argparse
from verify_calendar_time import audit,ROOT
H=lambda b:hashlib.sha256(b).hexdigest()
def main():
 args=argparse.ArgumentParser(description=__doc__);args.add_argument('--transitions',action='store_true');a=args.parse_args();transition=a.transitions
 p=ROOT/'build/research/calendar-time-work.json';w=json.loads(p.read_bytes())
 assert w.get('rawAcceptancePassed') and w['nativeJobs'][-1]['status']=='terminal' and w['nativeJobs'][-1]['exitCode']==0
 if transition:assert w.get('transitionRawAcceptancePassed')
 name='calendar-transitions' if transition else 'calendar-time'
 source=ROOT/('build/research/calendar-time-transitions-candidate1.json' if transition else 'build/research/calendar-time-candidate2.json');r=audit(source);raw=source.read_bytes();payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);packed=z.compress(payload)+z.flush()
 fixture=ROOT/f'native/Tests/NTSDCoreTests/Fixtures/original-{name}.json';assert not fixture.exists()
 data=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(packed).decode()),separators=(',',':'))+'\n').encode();fixture.write_bytes(data)
 r.update(nativeCompared=True,fixture=fixture.name,fixtureBytes=len(data),fixtureSHA256=H(data),windowsVerified=False,fullGoalComplete=False,scope='9755 whole returns including20 clocks and9735 localtime calls;3 original stops are native rejections with rollback. OS/environment inputs controlled. Whole WinMain and native host timezone acquisition remain open.')
 if transition:r['scope']='1089 additional whole localtime returns;198 exact DST boundaries each with five neighboring seconds plus99 own June baselines. Main fixture unchanged; no Windows/device claim.'
 (ROOT/f'docs/evidence/{name}.json').write_text(json.dumps(r,indent=2)+'\n')
 pins={p.name:H(p.read_bytes()) for p in sorted((ROOT/'native/Tests/NTSDCoreTests/Fixtures').glob('*.json'))};assert len(pins)==(233 if transition else 232)
 if transition:(ROOT/'build/research/calendar-time-main-fixture-pins.json').write_bytes((ROOT/'build/research/calendar-time-fixture-pins.json').read_bytes())
 (ROOT/'build/research/calendar-time-fixture-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
 w.update(fixturePublished=True,currentFixtures=len(pins));key='transitionPublication' if transition else 'publication';w[key]=dict(fixture=str(fixture.relative_to(ROOT)),sha256=H(data),bytes=len(data));p.write_text(json.dumps(w,indent=2)+'\n');print(json.dumps(w[key],indent=2))
if __name__=='__main__':main()
