#!/usr/bin/env python3
"""Compare own pause/step/resume, then atomically publish lossless evidence.

The native operation starts from its own accepted parent, not expected source
state. Preserve original bytes/masks and declared platform boundaries. This
does not establish playback startup, an application window or Windows output.
"""
import argparse
import base64
import json
import os
import subprocess
import zlib
from accept_initialized_gameplay import ROOT,FIXTURES,capture,digest
from accept_paused_hud import atomic
from verify_paused_gameplay_source import validate


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--verify-only',action='store_true');p.add_argument('--skip-build',action='store_true')
    p.add_argument('--package-path',default='native');p.add_argument('--scratch-path',default='build/paused-gameplay-swift')
    a=p.parse_args();captures=[]
    for suffix in ('','-control'):
        name='paused-gameplay'+suffix;report,raw,doc=capture(name)
        verified=validate(doc,suffix);report.update(verified)
        atomic(ROOT/'build/research'/(name+'-verification.json'),(json.dumps(report,indent=2)+'\n').encode())
        captures.append((name,report,raw))
        print(name,'complete source/parent/records/stores/FPU/returns verified',len(raw),'bytes',flush=True)
    if a.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/paused-hud-fixture-pins.json').read_bytes())
    assert len(old)==191 and all(pins[k]==v for k,v in old.items())
    command=['swift','test','--package-path',str(ROOT/a.package_path),'-c','release',
        '--scratch-path',str(ROOT/a.scratch_path),'-Xswiftc','-enable-testing','--filter','OriginalPausedGameplayTests']
    if a.skip_build:command.append('--skip-build')
    subprocess.run(command,env=dict(os.environ,NTSD_PAUSED_GAMEPLAY_DIRECTORY=str(ROOT/'build/original')),check=True)
    assert all(digest((FIXTURES/k).read_bytes())==v for k,v in pins.items())
    for name,report,raw in captures:
        payload=raw[:-1];compressor=zlib.compressobj(level=9,wbits=-15)
        compressed=compressor.compress(payload)+compressor.flush();assert zlib.decompress(compressed,-15)==payload
        packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
        fixture=FIXTURES/('original-'+name+'.json')
        if fixture.name in pins:assert digest(packed)==pins[fixture.name],'Never rewrite accepted expectations'
        else:atomic(fixture,packed)
        report.update(nativeCompared=True,windowsVerified=False,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),
            nativeComparison='Fourteen whole loaded calls on independently rebuilt retained state: own F1 pause, F2 single-step and F1 resume. Every input phase, full returned storage/masks, rendering checkpoint and ordered event compare; late whole-call rollback is checked for unpaused and paused continuations. No source stack state seeds Native.',
            wholePlaybackPrologueCompared=False,controlledAllPauseBranchesCompared=False,appWindowCompared=False,deviceOutputCompared=False)
        atomic(ROOT/'docs/evidence'/(name+'.json'),(json.dumps(report,indent=2)+'\n').encode())
        print(name,'published',len(packed),'bytes',flush=True)
    pins.update({p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')})
    atomic(ROOT/'build/research/paused-gameplay-fixture-pins.json',(json.dumps(pins,indent=2)+'\n').encode())
    print('Current fixture pins',len(pins),flush=True)


if __name__=='__main__':main()
