#!/usr/bin/env python3
"""Independently verify result-layout source artifacts before native acceptance.

Reconstruct full globals and caller storage from actual source writes, check
bitmap values/masks, helper ABI returns and executed instruction inventories.
This cannot establish initialized stack provenance or real platform output.
"""
import argparse
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, digest, publish


def validate(sample=False):
    raw=(ROOT/'build/original/result-layout.json').read_bytes();doc=json.loads(raw)
    source=json.loads((ROOT/'build/research/result-layout.json').read_bytes())
    assert len(raw)==source['bytes'] and digest(raw)==source['sha256']
    assert doc['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
    assert doc['crtSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'
    assert doc['packageSHA256']=='8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd'
    assert doc['fpcw']==0x23f and doc['blobEncoding']=='zlib'
    assert len(doc['cases'])==source['cases'] and len({c['spec']['label'] for c in doc['cases']})==len(doc['cases'])
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']));assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    instructions=set();counts=Counter();formats=Counter();reads=Counter();undefined=0;helpers=0;copies=0;stores=Counter();stored_bytes=Counter()
    for c in doc['cases']:
        if c.get('fault'):
            assert c['spec'].get('authorPointerFault') and c['fault']['bitmap']==0x41414141 and c['pendingAtFault']
            assert c['end']['pc']==c['fault']['pc'] and c['fault']['address']>=c['fault']['bitmap']
        else:assert c['end']==dict(pc=0x422994,sp=0x1000f000) and not c.get('pendingAtFault')
        for key,size in (('world',0x7d8),('actors',400*0x420),('headers',4*0x76c),('playback',0x148),('globals',0xb440),('localBefore',0x174),('lowBefore',0x38)):
            assert len(blobs[c[key]])==size
        values={key:bytearray(blobs[c[field]]) for key,field in (('globals','globals'),('local','localBefore'),('low','lowBefore'))}
        written={key:bytearray(len(v)) for key,v in values.items()};event_writes=[];source_writes=[]
        for w in c['localWrites']:
            pc,offset,size,number=w['pc'],w['offset'],w['size'],w['value']
            if offset>=0x44c:
                assert 0x78130000<=pc<0x78230000 and size==1 and offset+size<=0x5c0
                key='local';offset-=0x44c;source_writes.append(('formatWrite',[offset,size,number]))
            else:
                assert 0x422218<=pc<0x422944 and 0x34<=offset and offset+size<=0x64 and size in (1,4)
                normalized=(number+doc['worldBase']+4)&0xffffffff if offset==0x50 else number
                source_writes.append(('localWrite',[offset,size,normalized]));key='low';offset-=0x34
            values[key][offset:offset+size]=number.to_bytes(size,'little');written[key][offset:offset+size]=b'\1'*size
            stores[key]+=1;stored_bytes[key]+=size
        for w in c['writes']:
            pc,offset,size,number=w['pc'],w['address']-0x44d000,w['size'],w['value']
            assert 0x41b390<=pc<0x41b5cf or pc==0x423a49 or 0x78130000<=pc<0x78230000
            assert size in (1,4) and 0<=offset and offset+size<=0xb440
            values['globals'][offset:offset+size]=number.to_bytes(size,'little');written['globals'][offset:offset+size]=b'\1'*size
            stores['globals']+=1;stored_bytes['globals']+=size
        for key,after,mask in (('globals','globalsAfter','written'),('local','localAfter','localWritten'),('low','lowAfter','lowWritten')):
            assert bytes(values[key])==blobs[c[after]] and bytes(written[key])==blobs[c[mask]],(c['spec']['label'],key)
        assert blobs[c['lowBefore']][-8:]==blobs[c['lowAfter']][-8:]
        for r in c['retainedReads']:
            assert (r['pc'],r['offset'],r['size']) in ((0x422673,0x64,4),(0x42294d,0x68,4));reads[hex(r['pc'])]+=1
        for h in c['copies']:
            assert h['pc'] in (0x41b5a6,0x41b5bf) and h['bytes']==h['count']*(4 if h['pc']==0x41b5a6 else 1)
            assert len(bytes.fromhex(h['before']))==h['bytes']
            assert all(written['globals'][h['destination']-0x44d000:h['destination']-0x44d000+h['bytes']]);copies+=1
        globals_value=bytearray(blobs[c['globals']]);bitmap=None;text=None;blits=0;global_stores=[];format_events=[]
        for e in c['events']:
            kind=e['kind'];counts[kind]+=1
            if kind in ('localWrite','formatWrite'):event_writes.append((kind,e['arguments']))
            elif kind=='infoWrite':
                p,size,number=e['arguments'];globals_value[p-0x44d000:p-0x44d000+size]=number.to_bytes(size,'little');global_stores.append((p,size,number,False))
            elif kind=='infoText':text=e['arguments'][0];assert text in (0x450f60,0x44fd18,0x44f900,0x450e98)
            elif kind=='stringWrite':
                assert text is not None
                offset,number=e['arguments'];assert number==0;globals_value[text-0x44d000+offset]=0;global_stores.append((text+offset,1,0,True))
            elif kind=='fontPass':
                assert text is not None;offset=text-0x44d000;end=globals_value.index(0,offset)
                assert e['strings']==[list(globals_value[offset:end])] and e['arguments'][2]==64 and e['arguments'][4:]==[0,0]
            elif kind=='format':
                assert e['arguments']==[len(e['strings'][1])] and bytes(e['strings'][0]).hex() in doc['formats'].values();format_events.append(e)
            elif kind=='draw':
                p=e['arguments'][0]
                if c.get('fault') and p==c['fault']['bitmap']:
                    assert e is c['events'][-1];bitmap=None
                else:
                    assert p>=doc['bitmapBase'] and (p-doc['bitmapBase'])%0x2000==0
                    bitmap=(p-doc['bitmapBase'])//0x2000;assert bitmap<len(c['bitmaps'])
            elif kind=='read':
                assert bitmap is not None
                b=c['bitmaps'][bitmap];r=e['read'];offset=r['offset'];assert 0<=offset<=0x1f50-4
                assert r['value']==int.from_bytes(blobs[b['bytes']][offset:offset+4],'little')
                assert r['defined']==all(blobs[b['defined']][offset:offset+4]);undefined+=not r['defined']
            elif kind=='blit':
                b=e['blit'];assert b['targetSurface'] in (doc['target'],doc['indicatorTarget']) and b['effects'] is None
                assert b['sourceSurface']==int.from_bytes(blobs[c['bitmaps'][bitmap]['bytes']][:4],'little');blits+=1
            else:assert kind in ('clip','text','getDC','setBackgroundColor','setTextColor','stringLength','textOut','releaseDC')
        assert event_writes==source_writes
        assert global_stores==[(w['address'],w['size'],w['value'],w['pc']==0x423a49) for w in c['writes']]
        assert bytes(globals_value)==blobs[c['globalsAfter']] and blits==c['blits']
        calls=[];info_calls=0
        for h in c['helpers']:
            assert h['entry'] in (0x401290,0x41b390,0x7817775d,0x423a70,0x423940,0x43f010,0x43ef70)
            assert h['returnSP']==h['sp']+4+h['pop'] and h['pop']==(12 if h['entry']==0x41b390 else 24 if h['entry']==0x43f010 else 0)
            if h['entry']==0x41b390:info_calls+=1
            if h['entry']==0x7817775d:
                output=bytes.fromhex(h['output']);assert output[-1]==0 and len(output)==h['result']+1
                fmt=bytes(h['format']);assert len(h['arguments'])==fmt.count(b'%')
                calls.append(dict(kind='format',arguments=[h['result']],strings=[h['format'],list(output[:-1])]))
                formats[fmt.decode()]+=1
        assert info_calls in (0,1) and len(c['copies'])==2*info_calls and calls==format_events
        helpers+=len(c['helpers']);instructions.update(c['instructions'])
    assert sorted(instructions)==doc['instructions']
    static={int(line[:6],16) for line in (ROOT/'build/research/result-layout-static.asm').read_text().splitlines()}
    assert len(static)==537
    if not sample:assert static<=instructions,(len(doc['cases']),[hex(p) for p in sorted(static-instructions)])
    report=dict(source,blobs=len(blobs),eventCounts=dict(counts),undefinedBitmapReads=undefined,helperReturns=helpers,
        stores=dict(stores),storedBytes=dict(stored_bytes),retainedReads=dict(reads),completeREPCopies=copies,formatCalls=dict(formats),
        callerInstructions=len(static&instructions),callerStaticInstructions=len(static),missingCallerInstructions=[hex(p) for p in sorted(static-instructions)],
        exeInstructions=sum(p<0x70000000 for p in instructions),crtInstructions=sum(p>=0x70000000 for p in instructions),
        sourceNormalReturnsVerified=True,sourceFaultBoundaries=[c['fault'] for c in doc['cases'] if c.get('fault')],
        initializedWholeTick=False,pixelsCompared=False)
    return report,raw


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');parser.add_argument('--sample',action='store_true');args=parser.parse_args()
    report,raw=validate(sample=args.sample)
    (ROOT/'build/research/result-layout-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VERIFIED',report['cases'],'result layout calls',report['eventCounts'],flush=True)
    if args.verify_only or args.sample:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/queued-sound-fixture-pins.json').read_bytes())
    assert len(old)==182 and pins==old
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalResultLayoutTests'],
        env=dict(os.environ,NTSD_RESULT_LAYOUT_CORPUS=str(ROOT/'build/original/result-layout.json')),check=True)
    report['nativeComparison']='Full controlled World/400Actor/fourObject bytes and masks; globals and writes; caller formatting bytes/masks and normalized low-local writes; all formats, text/GDI/bitmap/font/clip/Blt events; late global/local rollback. Own initialized layout and target/string backing provenance remain separate.'
    publish([('result-layout',report,raw)],pins,pin_name='result-layout-fixture-pins.json')


if __name__=='__main__':main()
