#!/usr/bin/env python3
"""Verify both own result continuations after the controlled caller is accepted."""
import base64
import copy
import json
import os
import subprocess
import zlib
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, historical, publish


def validate_captures():
    captures=[]
    for suffix in ('','-control'):
        name='gameplay-result-recording'+suffix;report,raw,doc=capture(name)
        parent_report,parent=historical('gameplay-notices'+suffix)
        assert doc['parent']==report['parent']==dict(fixture=parent_report['fixture'],sha256=parent_report['fixtureSHA256'])
        assert doc['control']==bool(suffix) and len(doc['cases'])==1
        for key in ('worldAddress','actorAddresses','objectAddresses'):assert doc[key]==parent[key]
        blobs={}
        for key,b in doc['blobs'].items():
            value=zlib.decompress(base64.b64decode(b['deflate']),-15)
            assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
        c=doc['cases'][0];n=c['resultRecording']
        assert c['label']=='result-recording' and c['before']==parent['cases'][0]['after']
        assert c['end']==report['end']==dict(pc=0x422944,sp=0x1000e9bc)
        assert c['helpers']==c['checkpoints']==c['readsBeforeWrites']==[]
        # Source only increments its own elapsed word from0 to1 on this first
        # tick. This verifies the complete state, not just that selected word.
        before=blobs[c['before']['state']['globals']];after=blobs[c['after']['state']['globals']]
        assert before[0x3bbc:0x3bc0]==bytes(4)
        expected=bytearray(before);expected[0x3bbc:0x3bc0]=(1).to_bytes(4,'little')
        assert bytes(expected)==after
        assert c['before']['early']['globals']==c['before']['state']['globals']
        assert c['after']['early']['globals']==c['after']['state']['globals']
        unchanged=copy.deepcopy(c['after'])
        for field in ('state','early'):unchanged[field]['globals']=c['before'][field]['globals']
        assert unchanged==c['before']
        assert n['stageDefeatedBefore']==n['stageDefeatedAfter']==0
        accesses=n['fromLastRoundInitialization'];assert len(accesses)==1
        a=accesses[0]
        assert a['pc']==0x41d7d7 and a['sp']==0x1000e9bc and a['address']==0x1000ea20
        assert a['write'] and a['size']==4 and a['reportedValue']==0
        assert report['stackAccesses']==accesses
        executed={0x421cdc,0x421ce1,0x421ce4,0x421ce6,0x421ced,0x421cf0,0x421cf6}
        assert set(c['instructions'])==executed|{0x422944} and len(c['instructions'])==8
        audit,old=doc['fpu'],parent['fpu']
        for field in ('initialization','transitions','watchedInstructions'):assert audit[field]==old[field]
        assert len(old['checkpoints'])==1604 and audit['checkpoints'][:-1]==old['checkpoints']
        assert len(audit['checkpoints'])==report['fpuCheckpoints']==1605
        assert audit['checkpoints'][-1]==dict(pc=0x421cdc,sp=0x1000e9bc,fpcw=0x23f,fpsw=0x4000)
        assert n['fpcw']==0x23f and n['fpswBefore']==n['fpswAfter']==0x4000 and n['fptagBefore']==n['fptagAfter']==0xffff
        report.update(initializedParentReproduced=True,parentSHA256=parent_report['sha256'],
            executedOriginalInstructions=len(executed),observedUnexecutedTerminal=0x422944,
            sourceOnlyStateChange=dict(address=0x450bbc,before=0,after=1),
            nativeRoundResultRetained=True,sourceStackBytesImportedToNative=False,
            stackAuditAccesses=len(n['allStackAccesses']),stackAuditAccessesSinceRoundInitialization=len(accesses),
            writerCalled=False,recordingRemainsOwned=True,firstTickReturned=False,pixelsCompared=False)
        captures.append((name,report,raw))
    return captures


def main():
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous=json.loads((ROOT/'build/research/result-recording-fixture-pins.json').read_bytes())
    assert len(previous)==176 and all(pins[n]==sha for n,sha in previous.items())
    controlled=json.loads((ROOT/'docs/evidence/result-recording.json').read_bytes())
    assert controlled['nativeCompared'] and controlled['cases']==95
    captures=validate_captures()
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalGameplayResultRecordingTests'],
        env=dict(os.environ,NTSD_GAMEPLAY_RESULT_RECORDING_DIRECTORY=str(ROOT/'build/original')),check=True)
    publish(captures,pins,pin_name='gameplay-result-recording-fixture-pins.json')


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');args=parser.parse_args()
    if args.verify_only:
        for name,report,raw in validate_captures():
            print(name,'full source/parent/blob/FPU/stack verification passed',len(raw),'bytes',report['sha256'])
    else:main()
