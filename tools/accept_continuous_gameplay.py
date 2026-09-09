#!/usr/bin/env python3
"""Accept sixteen successive own loaded calls, then publish lossless evidence.

Compare independently reconstructed native input/round/body state and ordered
output against the pinned original EXE/VC80 on initialized Unicorn. Preserve
normal returns, masks, scratch boundaries and late whole-call rollback. The
original replay tick advances2..17; this does not establish the outer timed
loop, a full match, Windows or device output. No source state seeds the native operation.
"""
import argparse
import json
import os
import subprocess
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish
from verify_continuous_gameplay_source import validate


def validated_captures():
    captures=[]
    for suffix in ('','-control'):
        name='continuous-gameplay'+suffix;report,raw,doc=capture(name)
        assert len(doc['cases'])==report['returnedCalls']==16
        verified=validate(doc,suffix,raw);report.update(verified)
        report.update(wholeFrameHeapAtEveryReturn=True,wholeFrameHeapAtEveryIntermediateStage=False,
            sourceStackBytesImportedToNative=False,successiveLoadedCalls=True,advancingOuterTicks=False,
            fullMatchCompared=False,pixelsCompared=False,audioDeviceCompared=False)
        captures.append((name,report,raw))
        (ROOT/'build/research'/(name+'-verification.json')).write_text(json.dumps(report,indent=2)+'\n')
        print(name,'source/parent/components/blobs/globals/FPU/returns verified',len(raw),'bytes',flush=True)
    return captures


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--verify-only',action='store_true');p.add_argument('--scratch-path');a=p.parse_args()
    captures=validated_captures()
    if a.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/gameplay-return-fixture-pins.json').read_bytes())
    assert len(old)==188 and all(pins[n]==sha for n,sha in old.items())
    command=['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalContinuousGameplayTests']
    if a.scratch_path:command.extend(['--scratch-path',str(ROOT/a.scratch_path)])
    subprocess.run(command,env=dict(os.environ,NTSD_CONTINUOUS_GAMEPLAY_DIRECTORY=str(ROOT/'build/original')),check=True)
    for _,report,_ in captures:
        report['nativeComparison']='Sixteen successive calls retain independently reconstructed native state, with exact full return bytes/masks, owned resources/replay, all declared body checkpoints and ordered events. First new call late dispatcher observer verifies whole-call storage rollback. Full own parent and first-body comparison retained. Source normal machine frames and FPU history are separately asserted; no stack snapshot seeds Native.'
    publish(captures,pins,pin_name='continuous-gameplay-fixture-pins.json')


if __name__=='__main__':main()
