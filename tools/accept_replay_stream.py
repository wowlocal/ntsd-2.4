#!/usr/bin/env python3
"""Compare the actual replay stream dependency before publishing a new fixture."""
import json
import os
import subprocess
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish


def main():
    old=json.loads((ROOT/'build/research/replay-compression-fixture-pins.json').read_bytes())
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    assert len(old)==173 and all(pins[name]==sha for name,sha in old.items())
    report,raw,doc=capture('replay-stream')
    assert len(doc['cases'])==report['cases']==66
    assert len({c['label'] for c in doc['cases']})==66
    assert doc['platformWord']==dict(address=0x781c37c0,value=2,producerExecuted=False)
    assert doc['fileBacking']==dict(address=0x27001000,fields=[0,0,0,2,3,0,0,0],openBoundary=True)
    assert doc['descriptorBacking']==dict(tablePointerAddress=0x781c4820,table=0x270e0000,
        ordinal=3,recordBytes=64,osHandle=0x13572468,flags=1,remainingBytes=0,producerExecuted=False)
    requested=0;states={};pcs=set()
    for c in doc['cases']:
        assert [x['name'] for x in c['calls']]==['construct','write','write','close','destroy']
        for call,pop in zip(c['calls'],(16,8,8,0,0)):
            assert call['returnSP']==call['entrySP']+4+pop
            assert call['state']==int.from_bytes(bytes.fromhex(call['stream'])[0x5c:0x60],'little')
        io=[e for e in c['events'] if e['name'] in ('_wfsopen','_write','_close')]
        assert io[0]['name']=='_wfsopen' and io[0]['mode']=='77006200' and io[0]['share']==64
        path=bytes.fromhex(c['path']).split(b'\0')[0][:259]
        assert bytes.fromhex(io[0]['path'])==b''.join(bytes([b,0]) for b in path)
        if c['openFailure']:assert len(io)==1 and [x['state'] for x in c['calls']]==[2,6,6,6,6]
        else:assert io[-1]['name']=='_close'
        for event in io:
            if event['name']=='_write':
                data=bytes.fromhex(event['bytes']);assert len(data)==event['count']
                assert -1<=event['result']<=len(data);requested+=len(data)
        states[c['label']]=[x['state'] for x in c['calls']]
        pcs.update(c['instructions'])
    assert states['write-and-close-failure']==[0,0,4,6,6]
    assert requested==6664690 and sorted(pcs)==doc['instructions'] and len(pcs)==2950
    assert len(doc['codecInputs'])==2
    for item in doc['codecInputs']:
        case=next(c for c in doc['cases'] if c['label']=='codec-output-'+item['case'])
        payload=bytes.fromhex(case['payload'])
        assert digest(payload)==item['payloadSHA256'] and len(payload)==item['bytes'] and not item['keyApplied']
    report.update(descriptorBytesCompared=requested,streamStatesCompared=330,
        comparedScope='Ordered open path/mode/share, descriptor bytes/counts/close, five ios states and buffer attempt/fallback. Private C++/CRT allocations and object/FILE ABI bytes are source evidence only.',
        sourceInstructionCounting='Actual code-hook PCs, excluding declared boundary instructions and unexecuted stop.',
        inheritedBoundaries=doc['inheritedBoundaries'],sourcePrivateABICompared=False,
        sourceDLLStartupExecuted=False,nativeHostHeapPressureCompared=False)
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalReplayFileOutputTests'],
        env=dict(os.environ,NTSD_REPLAY_STREAM_CORPUS=str(ROOT/'build/original/replay-stream.json')),check=True)
    publish([('replay-stream',report,raw)],pins,pin_name='replay-stream-fixture-pins.json')

if __name__=='__main__':main()
