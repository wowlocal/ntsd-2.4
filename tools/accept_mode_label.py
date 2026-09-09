#!/usr/bin/env python3
"""Validate whole mode-label calls before publishing after the font dependency."""
import argparse
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, digest, publish


def validate():
    raw=(ROOT/'build/original/mode-label.json').read_bytes();doc=json.loads(raw)
    source=json.loads((ROOT/'build/research/mode-label.json').read_bytes())
    assert len(raw)==source['bytes'] and digest(raw)==source['sha256']
    assert doc['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
    assert doc['fpcw']==0x23f and doc['blobEncoding']=='zlib' and len(doc['cases'])==148
    assert len({c['spec']['label'] for c in doc['cases']})==148
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']));assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    instructions=set();counts=Counter();undefined=0;helpers=0;stores=0;stored_bytes=0
    for c in doc['cases']:
        assert c['end']==dict(pc=0x30000000,sp=0x1000f00c)
        before=blobs[c['globals']];assert len(before)==0xb440
        value=bytearray(before);written=bytearray(len(value));writes=[]
        for w in c['writes']:
            pc,offset,size,number=w['pc'],w['address']-0x44d000,w['size'],w['value']
            assert 0x41b130<=pc<0x41b387 or pc==0x423a49
            assert size in (1,2,4) and 0x450c38-0x44d000<=offset and offset+size<=0x450c38-0x44d000+1024
            value[offset:offset+size]=number.to_bytes(size,'little');written[offset:offset+size]=b'\1'*size
            writes.append(('stringWrite',[w['address']-0x450c38,0]) if pc==0x423a49 else ('labelWrite',[w['address'],size,number]))
            stores+=1;stored_bytes+=size
        assert bytes(value)==blobs[c['globalsAfter']] and bytes(written)==blobs[c['written']]
        assert [(e['kind'],e['arguments']) for e in c['events'] if e['kind'] in ('labelWrite','stringWrite')]==writes
        value=bytearray(before);bitmap=None;passes=[];blits=0
        for e in c['events']:
            kind=e['kind'];counts[kind]+=1
            if kind=='labelWrite':
                p,size,number=e['arguments'];value[p-0x44d000:p-0x44d000+size]=number.to_bytes(size,'little')
            elif kind=='stringWrite':
                p,number=e['arguments'];assert number==0;value[0x450c38-0x44d000+p]=0
            elif kind=='fontPass':
                offset=0x450c38-0x44d000;end=value.index(0,offset)
                assert e['strings']==[list(value[offset:end])];assert e['arguments'][2:]==[64,4,0,0];passes.append(e['arguments'])
            elif kind=='draw':
                p=e['arguments'][0];assert p>=doc['bitmapBase'] and (p-doc['bitmapBase'])%0x2000==0
                bitmap=(p-doc['bitmapBase'])//0x2000;assert bitmap<3
            elif kind=='read':
                assert bitmap is not None
                b=c['bitmaps'][bitmap];r=e['read'];offset=r['offset'];assert 0<=offset<=0x1f50-4
                assert r['value']==int.from_bytes(blobs[b['bytes']][offset:offset+4],'little')
                assert r['defined']==all(blobs[b['defined']][offset:offset+4]);undefined+=not r['defined']
            elif kind=='blit':
                b=e['blit'];assert b['targetSurface']==doc['target'] and b['flags']==0x1008000 and b['effects'] is None
                assert b['sourceSurface']==int.from_bytes(blobs[c['bitmaps'][bitmap]['bytes']][:4],'little');blits+=1
            else:assert kind=='clip'
        assert bytes(value)==blobs[c['globalsAfter']] and len(passes)==4 and blits==c['blits']
        x,y=passes[-1][:2]
        assert y==(510 if c['spec'].get('alternate',0) else 531)
        assert [p[:2] for p in passes]==[[(x-1)&0xffffffff,(y+1)&0xffffffff],[(x-1)&0xffffffff,y],[x,(y+1)&0xffffffff],[x,y]]
        for r in c['labelReads']:assert 0<=r['offset'] and r['offset']+r['size']<=1024
        for h in c['helpers']:
            assert h['entry'] in (0x41b130,0x423a70,0x423940,0x43f010,0x43ef70)
            assert h['returnSP']==h['sp']+4+h['pop']
            assert h['pop']==(8 if h['entry']==0x41b130 else 24 if h['entry']==0x43f010 else 0)
        helpers+=len(c['helpers']);instructions.update(c['instructions'])
    assert sorted(instructions)==doc['instructions']
    lines=(ROOT/'build/research/compact.asm').read_text().splitlines()
    static={int(line[:6],16) for line in lines if len(line)>6 and line[6]==' ' and all(c in '0123456789abcdef' for c in line[:6]) and 0x41b130<=int(line[:6],16)<0x41b387}
    assert static-instructions=={0x41b34f}
    report=dict(source,blobs=len(blobs),eventCounts=dict(counts),undefinedBitmapReads=undefined,helperReturns=helpers,
        globalStores=stores,globalStoredBytes=stored_bytes,callerInstructions=len(static&instructions),callerStaticInstructions=len(static),
        missingCallerInstructions=sorted(static-instructions),
        nativeComparison='Full globals and actual store masks/order; complete ordered font/draw/read/clip/Blt events; retained unknown-mode label, signed stage test, four-pass mutation, late global rollback.',
        sourceNormalReturnsVerified=True,sourcePrivateCallerStackComparedNatively=False,initializedWholeTick=False,pixelsCompared=False)
    return report,raw


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');args=parser.parse_args()
    report,raw=validate();(ROOT/'build/research/mode-label-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VERIFIED',report['cases'],'mode labels',report['eventCounts'],flush=True)
    if args.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/bitmap-font-fixture-pins.json').read_bytes())
    assert len(old)==179 and all(pins[n]==sha for n,sha in old.items())
    font=json.loads((ROOT/'docs/evidence/bitmap-font.json').read_bytes());assert font['nativeCompared']
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalModeLabelTests'],
        env=dict(os.environ,NTSD_MODE_LABEL_CORPUS=str(ROOT/'build/original/mode-label.json')),check=True)
    publish([('mode-label',report,raw)],pins,pin_name='mode-label-fixture-pins.json')


if __name__=='__main__':main()
