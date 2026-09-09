#!/usr/bin/env python3
"""Accept forty-eight active-key own loaded calls, then publish lossless evidence.

Compare independently reconstructed native input/round/body state and ordered
output against the pinned pristine EXE/VC80 on initialized Unicorn without
bundled lib.dll patches; this is not the DLL-enabled application. Preserve
normal returns, masks, scratch boundaries and late whole-call rollback. The
original replay tick advances18..65; this does not establish the outer timed
loop, a full match, Windows or device output. No source state seeds the native operation.
"""
import argparse
import json
import os
import subprocess
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish
from verify_active_gameplay_source import validate


def validated_captures():
    captures=[]
    for suffix in ('','-control'):
        name='active-gameplay'+suffix;report,raw,doc=capture(name)
        assert len(doc['cases'])==report['returnedCalls']==48
        verified=validate(doc,suffix,raw);report.update(verified)
        report.update(wholeFrameHeapAtEveryReturn=True,wholeFrameHeapAtEveryIntermediateStage=False,
            wholeObjectAndWeaponStringsAtEveryReturn=True,wholeObjectsAtEveryIntermediateStage=False,
            sourceStackBytesImportedToNative=False,successiveLoadedCalls=True,advancingOuterTicks=False,
            fullMatchCompared=False,pixelsCompared=False,audioDeviceCompared=False)
        report.update(bundledLibLoaded=False,referenceDomain='Pristine EXE/VC80 controlled initialization without bundled lib.dll patches; not the actual DLL-enabled application startup')
        captures.append((name,report,raw))
        (ROOT/'build/research'/(name+'-verification.json')).write_text(json.dumps(report,indent=2)+'\n')
        print(name,'source/parent/components/blobs/globals/FPU/returns verified',len(raw),'bytes',flush=True)
    return captures


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--verify-only',action='store_true');p.add_argument('--scratch-path');p.add_argument('--package-path',default='native');a=p.parse_args()
    captures=validated_captures()
    if a.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/continuous-gameplay-fixture-pins.json').read_bytes())
    assert len(old)==190 and all(pins[n]==sha for n,sha in old.items())
    latest=json.loads((ROOT/'build/research/application-service-keys-fixture-pins.json').read_bytes())
    assert len(latest)==195 and all(pins[n]==sha for n,sha in latest.items())
    dispatch=json.loads((ROOT/'build/research/application-dispatch-prefix-fixture-pins.json').read_bytes())
    assert len(dispatch)==196 and all(pins[n]==sha for n,sha in dispatch.items())
    (ROOT/'build/research/active-gameplay-prior-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    # Each active test reconstructs and compares the complete neutral parent.
    # The six standalone timer/neutral/paused integration tests already passed
    # with these exact six owned source files; do not repeat that whole suite.
    command=['swift','test','--package-path',str(ROOT/a.package_path),'-c','release','--filter','OriginalActiveGameplayTests']
    if a.scratch_path:command.extend(['--scratch-path',str(ROOT/a.scratch_path)])
    subprocess.run(command,env=dict(os.environ,NTSD_ACTIVE_GAMEPLAY_DIRECTORY=str(ROOT/'build/original')),check=True)
    for _,report,_ in captures:
        report['priorAcceptedFixturePinsUnchanged']=len(pins)
        report['nativeComparison']='Forty-eight pristine EXE/VC80 active-key control calls retain independently reconstructed native state, with exact full return bytes/masks, owned Object records/weapon strings/resources/replay, all declared body checkpoints and ordered events. First new call late dispatcher observer verifies whole-call storage rollback while retaining acquired keyboard input. Full control parent and first-body comparison retained. Source normal machine frames and FPU history are separately asserted; no stack snapshot seeds Native. Bundled lib.dll patches are not loaded or compared.'
    publish(captures,pins,pin_name='active-gameplay-fixture-pins.json')


if __name__=='__main__':main()
