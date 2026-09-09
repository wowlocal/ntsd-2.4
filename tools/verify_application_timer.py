#!/usr/bin/env python3
"""Validate original timer artifacts and optional accepted lossless packaging.

This source/evidence check does not execute the dispatcher or a device. The
whole59-instruction timer slice uses declared clock/dispatch/recovery/Sleep
responses. Native acceptance is separate; preserve all prior fixture pins.
"""
import argparse,base64,itertools,json,zlib
from collections import Counter
from pathlib import Path
from accept_initialized_gameplay import ROOT,FIXTURES,capture,digest
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE
from inspect_application_timer import capture as inspect_timer


def validate():
    report,raw,doc=capture('application-timer')
    assert len(doc['cases'])==report['cases']==2025
    static=inspect_timer()
    assert static['exeSHA256']==doc['exeSHA256']
    pcs={i['address'] for i in static['instructions'] if 0x43d157<=i['address']<0x43d1ef}
    assert pcs==set(doc['instructions']) and len(pcs)==59
    exe=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert digest(exe)==EXE_SHA256;pe=PE(exe);cursor=0x43d157
    for row in static['instructions']:
        if row['address'] not in pcs:continue
        assert row['address']==cursor
        code=bytes.fromhex(row['bytes']);offset=pe.offset(cursor-pe.base);assert exe[offset:offset+len(code)]==code;cursor+=len(code)
    assert cursor==0x43d1ef
    space=list(itertools.product((0,1,-1),(0,0xfffffff0,0x7ffffff0),(0,1,2,3,4,32,33,34,99,100,101,102,0x7fffffff,0x80000000,0xfffffff0),(0,1,5,33,101),(0,1,-1)))
    events=Counter();reads=Counter();sleeps=Counter()
    for n,c in enumerate(doc['cases']):
        speed,baseline,delay,step,result=space[n]
        assert (c['speed'],c['baselineBefore'],c['dispatchResult'],c['target'])==(speed,baseline,result,0x28002020 if n%2 else 0)
        assert c['clockResponses']==[(baseline+delay+i*step)&0xffffffff for i in range(4)]
        assert c['index']==n and c['end']==dict(pc=0x43d1ef,sp=0x1000f000) and c['fpcw']==0x23f
        assert set(c['instructions'])<=pcs
        kinds=Counter(e['kind'] for e in c['events']);events.update(kinds);reads[kinds['time']]+=1
        assert kinds['dispatch']<=1 and kinds['sleep']<=1
        assert kinds['recoverSurface']==sum(e['kind']=='dispatch' and e['arguments'][1]&0x80000000!=0 for e in c['events'])
        assert [e['arguments'][0] for e in c['events'] if e['kind']=='time']==c['clockResponses'][:kinds['time']]
        for e in c['events']:
            if e['kind']=='sleep':assert 1<=e['arguments'][0]<=5;sleeps[e['arguments'][0]]+=1
    assert sum(events.values())==8163
    report.update(allStaticTimerInstructionsExecuted=True,eventCounts=dict(events),clockReadCounts=dict(reads),sleepDurations=dict(sleeps),
        dispatcherBodyExecuted=False,recoveryBodyExecuted=False,ownGameJoin=False,messageLoopCompared=False)
    return report,raw,doc


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accepted',action='store_true');a=p.parse_args()
    report,raw,doc=validate()
    if a.accepted:
        accepted=json.loads((ROOT/'docs/evidence/application-timer.json').read_bytes());assert accepted['nativeCompared']
        packed=(FIXTURES/accepted['fixture']).read_bytes();wrapper=json.loads(packed)
        restored=zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
        assert restored+b'\n'==raw and json.loads(restored)==doc and len(restored)==wrapper['count'] and digest(restored)==wrapper['sha256']
        assert accepted['sha256']==digest(raw) and accepted['bytes']==len(raw)
        assert accepted['fixtureSHA256']==digest(packed) and accepted['fixtureBytes']==len(packed)
        before=json.loads((ROOT/'build/research/application-timer-prior-pins.json').read_bytes())
        now=json.loads((ROOT/'build/research/application-timer-fixture-pins.json').read_bytes())
        assert all(now[n]==sha and digest((FIXTURES/n).read_bytes())==sha for n,sha in before.items())
        assert all(digest((FIXTURES/n).read_bytes())==sha for n,sha in now.items())
        vendor=ROOT/'native/Sources/NTSDReplayCodec';up=json.loads((vendor/'upstream.json').read_bytes());assert len(up['files'])==10
        assert all(digest((vendor/'vendor'/n).read_bytes())==v['vendoredSHA256'] for n,v in up['files'].items())
        report.update(fullRawPackedBytesEqual=True,completeJSONEqual=True,packedBytes=len(packed),packedSHA256=digest(packed),
            priorPinsUnchanged=len(before),milestonePins=len(now),vendorHashesVerified=10)
    (ROOT/'build/research/application-timer-artifact-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
