#!/usr/bin/env python3
"""Verify and publish the font dependency after the result-recording milestone."""
import argparse
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, digest, publish


def validate():
    raw=(ROOT/'build/original/bitmap-font.json').read_bytes();doc=json.loads(raw)
    source=json.loads((ROOT/'build/research/bitmap-font.json').read_bytes())
    assert len(raw)==source['bytes'] and digest(raw)==source['sha256']
    assert doc['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
    assert doc['fpcw']==0x23f and doc['blobEncoding']=='zlib' and len(doc['cases'])==2450
    assert len({c['spec']['label'] for c in doc['cases']})==2450
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']));assert len(value)==b['count'] and digest(value)==key
        blobs[key]=value
    instructions=set();counts=Counter();undefined_reads=0;helper_returns=0;string_bytes=0
    for c in doc['cases']:
        spec=c['spec'];assert spec['entry'] in (0x423940,0x423a70)
        assert c['end']==dict(pc=0x30000000,sp=0x1000f004)
        assert len(blobs[c['globals']])==0xb440 and len(c['bitmaps'])==3
        for b in c['bitmaps']:
            assert len(blobs[b['bytes']])==len(blobs[b['defined']])==0x1f50
            assert all(v<2 for v in blobs[b['defined']])
        text=bytearray(blobs[c['textBefore']]);mask=bytearray(blobs[c['maskBefore']]);written=bytearray(len(text))
        assert len(text)==len(mask) and all(v<2 for v in mask)
        string_bytes+=len(text);offset=spec.get('offset',16);passes=[];bitmap=None;blits=0
        for event in c['events']:
            kind=event['kind'];counts[kind]+=1
            if kind=='fontPass':
                end=text.index(0,offset)
                assert event['strings']==[list(text[offset:end])] and len(event['arguments'])==6
                passes.append(event['arguments'])
            elif kind=='stringWrite':
                position,value=event['arguments'];assert value==0 and 0<=offset+position<len(text)
                text[offset+position]=0;mask[offset+position]=1;written[offset+position]=1
            elif kind=='draw':
                pointer=event['arguments'][0]
                assert pointer>=doc['bitmapBase'] and (pointer-doc['bitmapBase'])%0x2000==0
                bitmap=(pointer-doc['bitmapBase'])//0x2000;assert bitmap<3
            elif kind=='read':
                assert bitmap is not None
                r=event['read'];b=c['bitmaps'][bitmap];o=r['offset'];assert 0<=o<=0x1f50-4
                assert r['value']==int.from_bytes(blobs[b['bytes']][o:o+4],'little')
                assert r['defined']==all(blobs[b['defined']][o:o+4])
                undefined_reads+=not r['defined']
            elif kind=='blit':
                b=event['blit'];assert b['targetSurface']==doc['target'] and b['flags']==0x1008000 and b['effects'] is None
                assert b['sourceSurface']==int.from_bytes(blobs[c['bitmaps'][bitmap]['bytes']][:4],'little');blits+=1
            else:assert kind=='clip'
        expected_offsets=[(0,0)] if spec['entry']==0x423940 else [(-1,1),(-1,0),(0,1),(0,0)]
        assert len(passes)==len(expected_offsets)
        for args,(dx,dy) in zip(passes,expected_offsets):
            expected=[spec.get('x',80)+dx,spec.get('y',50)+dy,spec.get('columns',8),spec.get('lines',3),spec.get('style',0),spec.get('cursor',0)]
            assert args==[v&0xffffffff for v in expected]
        assert bytes(text)==blobs[c['textAfter']] and bytes(mask)==blobs[c['maskAfter']] and bytes(written)==blobs[c['written']]
        assert blits==c['blits']
        for offset in c['textReadOffsets']:assert blobs[c['maskBefore']][offset]
        for h in c['helpers']:
            assert h['entry'] in (0x423940,0x423a70,0x43f010,0x43ef70)
            assert h['returnSP']==h['sp']+4+h['pop'] and h['pop']==(24 if h['entry']==0x43f010 else 0)
        instructions.update(c['instructions']);helper_returns+=len(c['helpers'])
    assert sorted(instructions)==doc['instructions']
    lines=(ROOT/'build/research/compact.asm').read_text().splitlines()
    def starts(start,end):
        return {int(line[:6],16) for line in lines if len(line)>6 and line[6]==' ' and all(c in '0123456789abcdef' for c in line[:6]) and start<=int(line[:6],16)<end}
    single,wrapper=starts(0x423940,0x423a6d),starts(0x423a70,0x423afb)
    assert len(single)==104 and single-instructions=={0x42395d} and len(wrapper)==63 and wrapper<=instructions
    assert len(instructions)==394 and counts['fontPass']==counts['stringWrite']==6125 and helper_returns==35720
    report=dict(source,entries=dict(Counter(hex(c['spec']['entry']) for c in doc['cases'])),
        eventCounts=dict(counts),undefinedBitmapReads=undefined_reads,stringStorageBytesAndMasks=string_bytes,
        blobs=len(blobs),helperReturns=helper_returns,singleInstructions=len(single&instructions),singleStaticInstructions=len(single),
        missingSingleInstructions=sorted(single-instructions),wrapperInstructions=len(wrapper),
        bitmapInstructions=len(starts(0x43f010,0x43f2ff)&instructions),clipInstructions=len(starts(0x43ef70,0x43f001)&instructions),
        nativeComparison='Full input-string bytes/masks and actual NUL stores; all ordered pass/draw/read/clip/Blt events; unchanged globals and bitmap backing; four-pass mutation composition; late third-pass observer rollback.',
        sourceNormalReturnsVerified=True,sourcePrivateCallerStackComparedNatively=False,
        arbitraryTextResourceAliasesCompared=False,ownInitializedLabelCaller=False,pixelsCompared=False,windowsVerified=False)
    return report,raw


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');args=parser.parse_args()
    report,raw=validate()
    (ROOT/'build/research/bitmap-font-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VERIFIED',report['cases'],'font calls',report['eventCounts'],report['undefinedBitmapReads'],'undefined bitmap reads',flush=True)
    if args.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/gameplay-result-recording-fixture-pins.json').read_bytes())
    assert len(old)==178 and all(pins[n]==sha for n,sha in old.items())
    own=json.loads((ROOT/'docs/evidence/gameplay-result-recording.json').read_bytes());assert own['nativeCompared']
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalBitmapFontTests'],
        env=dict(os.environ,NTSD_BITMAP_FONT_CORPUS=str(ROOT/'build/original/bitmap-font.json')),check=True)
    publish([('bitmap-font',report,raw)],pins,pin_name='bitmap-font-fixture-pins.json')


if __name__=='__main__':main()
