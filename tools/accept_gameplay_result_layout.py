#!/usr/bin/env python3
"""Verify both own result-layout joins after controlled layout acceptance."""
import argparse
import base64
import json
import os
import subprocess
import zlib
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, historical, publish


def validate_captures():
    captures=[]
    for suffix in ('','-control'):
        name='gameplay-result-layout'+suffix;report,raw,doc=capture(name)
        parent_report,parent=historical('gameplay-result-recording'+suffix)
        assert doc['parent']==report['parent']==dict(fixture=parent_report['fixture'],sha256=parent_report['fixtureSHA256'])
        assert doc['control']==bool(suffix) and len(doc['cases'])==1
        for key in ('worldAddress','actorAddresses','objectAddresses'):assert doc[key]==parent[key]
        for key,b in doc['blobs'].items():
            value=zlib.decompress(base64.b64decode(b['deflate']),-15)
            assert len(value)==b['count'] and digest(value)==key
        c=doc['cases'][0];n=c['resultLayout']
        assert c['label']=='result-layout' and c['before']==parent['cases'][0]['after'] and c['after']==c['before']
        assert c['end']==report['end']==dict(pc=0x422994,sp=0x1000e9bc)
        assert c['helpers']==c['checkpoints']==c['readsBeforeWrites']==[]
        assert n['continuation']==0x422944 and n['stageDefeatedBefore']==n['stageDefeatedAfter']==0
        assert n['localAccesses']==report['localAccesses']==[]
        executed={0x422944,0x42294b};assert set(c['instructions'])==executed|{0x422994}
        audit,old=doc['fpu'],parent['fpu']
        for field in ('initialization','transitions','watchedInstructions'):assert audit[field]==old[field]
        assert len(old['checkpoints'])==1605 and audit['checkpoints'][:-1]==old['checkpoints']
        assert len(audit['checkpoints'])==report['fpuCheckpoints']==1606
        assert audit['checkpoints'][-1]==dict(pc=0x422944,sp=0x1000e9bc,fpcw=0x23f,fpsw=0x4000)
        assert n['fpcw']==0x23f and n['fpswBefore']==n['fpswAfter']==0x4000 and n['fptagBefore']==n['fptagAfter']==0xffff
        report.update(initializedParentReproduced=True,parentSHA256=parent_report['sha256'],
            executedOriginalInstructions=len(executed),observedUnexecutedTerminal=0x422994,
            completeBeforeAfterStateIdentical=True,nativeUsesOwnRecorderContinuation=True,
            nativeCallerFormatBackingUnavailable=True,nativeIndicatorTargetUnavailable=True,
            sourceStackBytesImportedToNative=False,firstTickReturned=False,pixelsCompared=False)
        captures.append((name,report,raw))
    return captures


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');args=parser.parse_args()
    captures=validate_captures()
    for name,report,raw in captures:print(name,'full source/parent/blob/FPU verification passed',len(raw),'bytes',report['sha256'],flush=True)
    if args.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous=json.loads((ROOT/'build/research/result-layout-fixture-pins.json').read_bytes())
    assert len(previous)==183 and all(pins[n]==sha for n,sha in previous.items())
    # The independent controlled output study was published while these own
    # captures ran. Retain that accepted addition and every prior fixture pin.
    accepted=json.loads((ROOT/'build/research/gameplay-output-fixture-pins.json').read_bytes())
    assert len(accepted)==184 and pins==accepted
    controlled=json.loads((ROOT/'docs/evidence/result-layout.json').read_bytes())
    assert controlled['nativeCompared'] and controlled['normalReturns']==599 and controlled['sourceFaults']==1
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalGameplayResultLayoutTests'],
        env=dict(os.environ,NTSD_GAMEPLAY_RESULT_LAYOUT_DIRECTORY=str(ROOT/'build/original')),check=True)
    publish(captures,pins,pin_name='gameplay-result-layout-fixture-pins.json')


if __name__=='__main__':main()
