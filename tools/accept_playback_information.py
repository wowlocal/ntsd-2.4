#!/usr/bin/env python3
"""Verify whole playback-info source calls and native comparison before publishing."""
import argparse
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, digest, publish


def validate():
    raw=(ROOT/'build/original/playback-information.json').read_bytes();doc=json.loads(raw)
    source=json.loads((ROOT/'build/research/playback-information.json').read_bytes())
    assert len(raw)==source['bytes'] and digest(raw)==source['sha256']
    assert doc['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
    assert doc['crtSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'
    assert doc['packageSHA256']=='8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd'
    assert doc['fpcw']==0x23f and doc['blobEncoding']=='zlib' and len(doc['cases'])==120
    assert len({c['spec']['label'] for c in doc['cases']})==120
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']));assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    instructions=set();counts=Counter();undefined=0;helpers=0;stores=0;stored_bytes=0;copies=0;formats=Counter()
    for c in doc['cases']:
        assert c['end']==dict(pc=0x30000000,sp=0x1000f010)
        before=blobs[c['globals']];assert len(before)==0xb440
        value=bytearray(before);written=bytearray(len(value));writes=[]
        # Every raw source write is retained; source separately checks actual
        # REP counts, advancement, DF and copied bytes against these masks.
        for w in c['writes']:
            pc,offset,size,number=w['pc'],w['address']-0x44d000,w['size'],w['value']
            assert 0x41b390<=pc<0x41b5cf or pc==0x423a49 or 0x78130000<=pc<0x78230000
            assert size in (1,4) and 0<=offset and offset+size<=len(value)
            value[offset:offset+size]=number.to_bytes(size,'little');written[offset:offset+size]=b'\1'*size
            writes.append((w['address'],size,number,pc==0x423a49));stores+=1;stored_bytes+=size
        assert bytes(value)==blobs[c['globalsAfter']] and bytes(written)==blobs[c['written']]
        for h in c['copies']:
            assert h['pc'] in (0x41b5a6,0x41b5bf) and h['bytes']==h['count']*(4 if h['pc']==0x41b5a6 else 1)
            assert len(bytes.fromhex(h['before']))==h['bytes']
            assert all(written[h['destination']-0x44d000:h['destination']-0x44d000+h['bytes']])
            copies+=1
        assert len(c['copies'])==2
        value=bytearray(before);bitmap=None;text=None;passes=[];groups=[];blits=0;event_writes=[];format_events=[]
        for e in c['events']:
            kind=e['kind'];counts[kind]+=1
            if kind=='infoWrite':
                p,size,number=e['arguments'];value[p-0x44d000:p-0x44d000+size]=number.to_bytes(size,'little');event_writes.append((p,size,number,False))
            elif kind=='infoText':
                if text is not None:groups.append((text,passes));passes=[]
                text=e['arguments'][0];assert text in (0x450f60,0x44fd18,0x44f900,0x450e98)
            elif kind=='stringWrite':
                assert text is not None
                p,number=e['arguments'];assert number==0;value[text-0x44d000+p]=0;event_writes.append((text+p,1,0,True))
            elif kind=='fontPass':
                offset=text-0x44d000;end=value.index(0,offset)
                assert e['strings']==[list(value[offset:end])];assert e['arguments'][2]==64 and e['arguments'][4:]==[0,0];passes.append(e['arguments'])
            elif kind=='format':
                assert e['arguments']==[len(e['strings'][1])]
                assert bytes(e['strings'][0]).hex() in doc['formats'].values();format_events.append(e)
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
        groups.append((text,passes))
        assert event_writes==writes and bytes(value)==blobs[c['globalsAfter']] and blits==c['blits']
        assert groups[-1][0]==0x450e98
        for pointer,passes in groups:
            assert len(passes)==4
            x,y=passes[-1][:2]
            assert [p[:2] for p in passes]==[[(x-1)&0xffffffff,(y+1)&0xffffffff],[(x-1)&0xffffffff,y],[x,(y+1)&0xffffffff],[x,y]]
            assert all(p[2:]==passes[-1][2:] for p in passes)
        calls=[]
        for h in c['helpers']:
            assert h['entry'] in (0x41b390,0x7817775d,0x423a70,0x423940,0x43f010,0x43ef70)
            assert h['returnSP']==h['sp']+4+h['pop']
            assert h['pop']==(12 if h['entry']==0x41b390 else 24 if h['entry']==0x43f010 else 0)
            if h['entry']==0x7817775d:
                output=bytes.fromhex(h['output']);assert output[-1]==0 and len(output)==h['result']+1
                fmt=bytes(h['format']);assert len(h['arguments'])==fmt.count(b'%')
                calls.append(dict(kind='format',arguments=[h['result']],strings=[h['format'],list(output[:-1])]))
                formats[fmt.decode()]+=1
        assert len(calls)==2 and calls==format_events
        helpers+=len(c['helpers']);instructions.update(c['instructions'])
    assert sorted(instructions)==doc['instructions']
    lines=(ROOT/'build/research/compact.asm').read_text().splitlines()
    static={int(line[:6],16) for line in lines if len(line)>6 and line[6]==' ' and all(c in '0123456789abcdef' for c in line[:6]) and 0x41b390<=int(line[:6],16)<0x41b5cf}
    assert len(static)==200 and static<=instructions and len(instructions)==980
    report=dict(source,blobs=len(blobs),eventCounts=dict(counts),undefinedBitmapReads=undefined,helperReturns=helpers,
        globalStores=stores,globalStoredBytes=stored_bytes,completeREPCopies=copies,formatCalls=dict(formats),
        callerInstructions=len(static),callerStaticInstructions=len(static),missingCallerInstructions=[],
        exeInstructions=sum(p<0x70000000 for p in instructions),crtInstructions=sum(p>=0x70000000 for p in instructions),
        nativeComparison='Full globals and actual store masks/order; actual VC80 integer format outputs/returns; all ordered font/draw/read/clip/Blt events; live author/info truncation and ten-byte sentinels; wrapped signed ticks; late whole-call global rollback.',
        sourceNormalReturnsVerified=True,sourcePrivateCallerStackComparedNatively=False,initializedWholeTick=False,pixelsCompared=False)
    return report,raw


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');args=parser.parse_args()
    report,raw=validate();(ROOT/'build/research/playback-information-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VERIFIED',report['cases'],'playback info calls',report['eventCounts'],flush=True)
    if args.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/mode-label-fixture-pins.json').read_bytes())
    assert len(old)==180 and all(pins[n]==sha for n,sha in old.items())
    mode=json.loads((ROOT/'docs/evidence/mode-label.json').read_bytes());assert mode['nativeCompared']
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalPlaybackInformationTests'],
        env=dict(os.environ,NTSD_PLAYBACK_INFORMATION_CORPUS=str(ROOT/'build/original/playback-information.json')),check=True)
    publish([('playback-information',report,raw)],pins,pin_name='playback-information-fixture-pins.json')


if __name__=='__main__':main()
