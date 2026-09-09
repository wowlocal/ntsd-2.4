#!/usr/bin/env python3
"""Verify controlled original output/return artifacts and compare native output.

Reconstruct complete globals/masks from original writes, check all bitmap reads,
source stage ordering, normal helper returns and unmodified prologue/epilogue.
This does not turn the supplied output context into an initialized full tick.
"""
import argparse
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, digest, capture, publish

NAME='gameplay-output-controlled'
STAGES=[0x41b130,0x4028a0,0x43e940,0x419e60]
CALLER={0x422994,0x422999,0x42299f,0x4229a0,0x4229a1,0x4229a3,0x4229a8,0x4229ae,0x4229af,0x4229b4,0x4229b9,0x4229ba,0x4229bf,0x4229c2,0x4229c7}
EPILOGUE={0x422a95,0x422a9c,0x422aa3,0x422aa4,0x422aa5,0x422aa6,0x422aa7,0x422aae,0x422ab0,0x422ab5,0x422ab7,0x422ab8}


def validate():
    report,raw,doc=capture(NAME)
    assert doc['crtSHA256']==report['crtSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'
    assert doc['packageSHA256']=='8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd'
    assert doc['fpcw']==0x23f and doc['blobEncoding']=='zlib'
    assert len(doc['cases'])==report['cases'] and len({c['spec']['label'] for c in doc['cases']})==len(doc['cases'])
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']));assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    pcs=set();events=Counter();helpers=Counter();writes=Counter();formats=Counter();undefined=0;blits=0
    for c in doc['cases']:
        assert c['abi']==dict(entrySP=0x1000f624,bodySP=0x1000effc,returnSP=0x1000f62c,
            saved=[0x11223344,0x22334455,0x33445566,0x44556677],restoredSEH=0x12345678,returnPC=0x30000000)
        assert c['prologue']==[0x41bc90,0x41bc91,0x41bc93,0x41bc96,0x41bc98,0x41bc9d,0x41bca3,0x41bca4,0x41bcaa,0x41bcaf,0x41bcb1,0x41bcb8,0x41bcb9,0x41bcba,0x41bcbb,0x41bcc0,0x41bcc2,0x41bcc3,0x41bcca]
        assert CALLER|EPILOGUE <= set(c['instructions'])
        assert 0x4450b2 in c['instructions'] and 0x30000000 not in c['instructions']
        assert [e['arguments'][0] for e in c['events'] if e['kind']=='stage']==STAGES
        value=bytearray(blobs[c['globals']]);mask=bytearray(len(value));assert len(value)==0xb440
        for w in c['writes']:
            offset=w['address']-0x44d000;size=w['size'];assert size in (1,2,4) and 0<=offset<offset+size<=len(value)
            value[offset:offset+size]=w['value'].to_bytes(size,'little');mask[offset:offset+size]=b'\1'*size;writes[hex(w['pc'])]+=1
        assert value==blobs[c['globalsAfter']] and mask==blobs[c['written']]
        bitmap=None;seen_blits=0;source_formats=[]
        event_writes=[]
        for e in c['events']:
            kind=e['kind'];events[kind]+=1
            if kind=='draw':
                p=e['arguments'][0];assert p>=doc['bitmapBase'] and (p-doc['bitmapBase'])%0x2000==0
                bitmap=(p-doc['bitmapBase'])//0x2000;assert bitmap<len(c['bitmaps'])
            elif kind=='read':
                assert bitmap is not None;r=e['read'];b=c['bitmaps'][bitmap];offset=r['offset'];assert 0<=offset<=0x1f50-4
                assert r['value']==int.from_bytes(blobs[b['bytes']][offset:offset+4],'little')
                assert r['defined']==all(blobs[b['defined']][offset:offset+4]);undefined+=not r['defined']
            elif kind=='blit':
                assert bitmap is not None;b=e['blit'];seen_blits+=1
                assert b['targetSurface']==doc['target'] and b['effects'] is None
                assert b['sourceSurface']==int.from_bytes(blobs[c['bitmaps'][bitmap]['bytes']][:4],'little')
            elif kind=='format':source_formats.append(e)
            elif kind=='labelWrite':event_writes.append(tuple(e['arguments']))
            elif kind=='stringWrite':event_writes.append((0x450c38+e['arguments'][0],1,0))
            elif kind=='queueWrite':event_writes.append((e['arguments'][0],4,0))
        assert event_writes==[(w['address'],w['size'],w['value']) for w in c['writes'] if not 0x402810<=w['pc']<0x402a60]
        assert seen_blits==c['blits'];blits+=seen_blits
        expected_formats=[]
        for h in c['helpers']:
            helpers[hex(h['entry'])]+=1
            assert h['returnSP']==h['sp']+4+h['pop']
            if h['entry']==0x7817775d:
                output=bytes.fromhex(h['output']);assert len(output)==h['result']+1 and output[-1]==0
                expected_formats.append(dict(kind='format',arguments=[h['result']],strings=[h['format'],list(output[:-1])]))
                formats[bytes(h['format']).decode()]+=1
        assert expected_formats==source_formats
        assert all(sum(h['entry']==stage for h in c['helpers'])==1 for stage in STAGES)
        assert sum(h['entry']==0x4450b2 for h in c['helpers'])==2
        pcs.update(c['instructions'])
    assert sorted(pcs)==doc['instructions'] and dict(events)==report['events']
    assert sum(helpers.values())==report['helpers'] and len(pcs)==report['instructions']
    report.update(blobs=len(blobs),eventCounts=dict(events),helperReturns=dict(helpers),storePCs=dict(writes),formats=dict(formats),
        blits=blits,undefinedBitmapReads=undefined,callerInstructions=len(CALLER),epilogueInstructions=len(EPILOGUE),
        exeInstructions=sum(p<0x70000000 for p in pcs),crtInstructions=sum(p>=0x70000000 for p in pcs),
        originalNormalCookieChecks=2*len(doc['cases']),sourceSavedRegistersAndSEHVerified=True,
        sourceGlobalWritesAndMasksVerified=True,allOriginalReturnInstructionsExecuted=True,
        initializedWholeTick=False,pixelsCompared=False,audioDeviceCompared=False)
    return report,raw


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--verify-only',action='store_true');p.add_argument('--scratch-path');args=p.parse_args()
    report,raw=validate();(ROOT/'build/research/gameplay-output-controlled-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VERIFIED',report['cases'],'whole controlled output/return calls',report['sha256'],flush=True)
    if args.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous=json.loads((ROOT/'build/research/result-layout-fixture-pins.json').read_bytes())
    assert len(previous)==183 and all(pins[n]==sha for n,sha in previous.items())
    command=['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalGameplayOutputTests']
    if args.scratch_path:command.extend(['--scratch-path',str(ROOT/args.scratch_path)])
    subprocess.run(command,env=dict(os.environ,NTSD_GAMEPLAY_OUTPUT_CORPUS=str(ROOT/'build/original'/f'{NAME}.json')),check=True)
    report['nativeComparison']='Complete controlled globals and defined masks, exact ordered label/font/GDI/COM/sound events and format bytes; native late sound failure rolls back entire output. Source writes and write masks independently reconstructed; private stack writes and Windows/device output are not native comparisons.'
    publish([(NAME,report,raw)],pins,pin_name='gameplay-output-fixture-pins.json')


if __name__=='__main__':main()
