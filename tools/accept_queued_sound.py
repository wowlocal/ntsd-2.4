#!/usr/bin/env python3
"""Verify native game sound-queue compatibility at the declared COM boundary."""
import argparse
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT,FIXTURES,digest,publish


def validate():
    raw=(ROOT/'build/original/queued-sound.json').read_bytes();doc=json.loads(raw)
    source=json.loads((ROOT/'build/research/queued-sound.json').read_bytes())
    assert len(raw)==source['bytes'] and digest(raw)==source['sha256']
    assert doc['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
    assert doc['fpcw']==0x23f and doc['blobEncoding']=='zlib'
    cases=doc['cases'];assert len(cases)==968 and len({c['spec']['label'] for c in cases})==968
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']));assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    instructions=set();events=Counter();helpers=0;stores=0;reads=0;method_counts=Counter()
    for c in cases:
        entry=c['spec'].get('entry',0x419e60);assert entry in (0x419e60,0x401a30)
        assert c['end']==dict(pc=0x30000000,sp=0x1000f000+(8 if entry==0x401a30 else 4))
        before=blobs[c['before']];assert len(before)==0xb440
        value=bytearray(before);written=bytearray(len(value));expected=[]
        for w in c['writes']:
            assert w['pc'] in (0x419e9f,0x419f7f) and w['size']==4 and w['value']==0
            p=w['address'];assert 0x457588<=p<0x457bc8 or 0x453e10<=p<0x453f50
            offset=p-0x44d000;assert offset%4==0
            value[offset:offset+4]=bytes(4);written[offset:offset+4]=b'\1'*4;expected.append(dict(kind='queueWrite',arguments=[p,0]));stores+=1
        assert bytes(value)==blobs[c['after']] and bytes(written)==blobs[c['written']]
        assert [e for e in c['events'] if e['kind']=='queueWrite']==expected
        assert sum(e['kind']=='method' for e in c['events'])==c['methods']
        for e in c['events']:
            events[e['kind']]+=1;args=e['arguments']
            if e['kind']=='method':
                assert args[0]>=doc['bufferBase'] and (args[0]-doc['bufferBase'])%16==0 and (args[0]-doc['bufferBase'])//16<480
                assert len(args)=={0x40:3,0x3c:3,0x48:2,0x34:3,0x30:5}[args[1]];method_counts[hex(args[1])]+=1
                if args[1]==0x34:assert args[2]==0
                if args[1]==0x30:assert args[2:4]==[0,0] and args[4] in (0,1)
            elif e['kind']=='play':assert len(args)==2
            else:assert e['kind']=='queueWrite'
        for h in c['helpers']:
            assert h['entry'] in (0x419e60,0x401a30) and h['pop']==(4 if h['entry']==0x401a30 else 0)
            assert h['returnSP']==h['sp']+4+h['pop']
        for r in c['resourceReads']:
            p=r['address']
            if p>=0x23003000:assert p-0x23003000 in (0x40,0x3c,0x48,0x34,0x30)
            else:assert p>=doc['bufferBase'] and (p-doc['bufferBase'])%16==0 and (p-doc['bufferBase'])//16<480 and r['value']==0x23003000
            reads+=1
        helpers+=len(c['helpers']);instructions.update(c['instructions'])
    assert sorted(instructions)==doc['instructions']
    static=json.loads((ROOT/'build/research/queued-sound-static.json').read_bytes());assert static['exeSHA256']==doc['exeSHA256'] and not static['dynamicExecution']
    groups={g['name']:{i['pc'] for i in g['instructions']} for g in static['groups']}
    assert groups['queue']-instructions=={0x419e78,0x419e7f} and groups['play']<=instructions and len(instructions)==173
    report=dict(source,blobs=len(blobs),eventCounts=dict(events),methodCounts=dict(method_counts),helperReturns=helpers,
        globalStores=stores,globalStoredBytes=stores*4,resourceReads=reads,queueInstructions=len(groups['queue']&instructions),
        queueStaticInstructions=len(groups['queue']),missingQueueInstructions=sorted(groups['queue']-instructions),
        playInstructions=len(groups['play']),entries=dict(Counter(hex(c['spec'].get('entry',0x419e60)) for c in cases)),
        nativeComparison='Full declared globals and write masks/order; all480 queue positions; signed wrapped weight/pan/volume arithmetic; exact COM request order and buffer identity; whole401a30 loop/device/null guards; late queue rollback.',
        sourceNormalReturnsVerified=True,sourcePrivateCallerStackComparedNatively=False,arbitraryCOMReentrancy=False,
        initializedOwnTick=False,hostAudioDeviceVerified=False)
    return report,raw


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');args=parser.parse_args()
    report,raw=validate();(ROOT/'build/research/queued-sound-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VERIFIED',report['cases'],'queued sound calls',report['eventCounts'],flush=True)
    if args.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/playback-information-fixture-pins.json').read_bytes())
    assert len(old)==181 and all(pins[n]==sha for n,sha in old.items())
    info=json.loads((ROOT/'docs/evidence/playback-information.json').read_bytes());assert info['nativeCompared']
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalQueuedSoundTests'],
        env=dict(os.environ,NTSD_QUEUED_SOUND_CORPUS=str(ROOT/'build/original/queued-sound.json')),check=True)
    publish([('queued-sound',report,raw)],pins,pin_name='queued-sound-fixture-pins.json')


if __name__=='__main__':main()
