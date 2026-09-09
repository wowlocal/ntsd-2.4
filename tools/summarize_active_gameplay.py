#!/usr/bin/env python3
"""Report observed active trajectories without changing source data or match claims.

Read only complete returned calls from the pinned original EXE/VC80 research
capture. The summary distinguishes command/recording mutations, contact lists,
damage, creations and queued sound play from merely requesting attack keys.
It is not native equivalence, a completed match or device/Windows evidence.
"""
import argparse
import base64
import json
import zlib
from collections import Counter
from pathlib import Path
from accept_initialized_gameplay import ROOT, capture, digest


def summarize(doc):
    cache={}
    def blob(key):
        if key not in cache:
            item=doc['blobs'][key];raw=zlib.decompress(base64.b64decode(item['deflate']),-15)
            assert len(raw)==item['count'] and digest(raw)==key;cache[key]=raw
        return cache[key]
    def snapshot(refs):return {k:doc['components'][v] for k,v in refs.items()}
    def actors(state):
        pool=blob(state['state']['poolBytes']);assert len(pool)==0x7d8+400*0x420
        return [pool[0x7d8+n*0x420:0x7d8+(n+1)*0x420] for n in range(400)]
    def integer(raw,offset):return int.from_bytes(raw[offset:offset+4],'little',signed=True)
    rows=[]
    for case in doc['cases']:
        before,after=map(snapshot,(case['before'],case['after']))
        a0,a1=actors(before),actors(after)
        glob=blob(after['state']['globals']);world=blob(after['state']['poolBytes'])[:0x7d8]
        effects=Counter(e['kind'] for stage in case['stages'] for e in stage['effects'])
        lifecycle=next(s for s in case['stages'] if s['label']=='post-draw-lifecycle')
        effects.update('lifecycle:'+e['kind'] for e in lifecycle['events'].get('lifecycle',[]))
        output=Counter(e['kind'] for e in case['output']['events'])
        rows.append(dict(index=case['index'],segment=case['acquisition']['plan']['segment'],
            phase=integer(glob,0x450b90-0x44d000),tick=integer(glob,0x450b8c-0x44d000),
            RNG=[integer(glob,p-0x44d000) for p in (0x450bcc,0x450c34)],
            activeSlots=[n for n in range(400) if world[4+n]],
            actors=[dict(slot=n,position=[integer(a1[n],p) for p in (0x10,0x14,0x18)],
                frame=integer(a1[n],0x70),HP=integer(a1[n],0x2fc),MP=integer(a1[n],0x308),
                HPChange=integer(a1[n],0x2fc)-integer(a0[n],0x2fc),
                currentButtons=list(a1[n][0xcd:0xd4]),previousButtons=list(a1[n][0xc6:0xcd])) for n in range(2)],
            effects=dict(effects),outputEvents=dict(output)))
    return dict(returnedCalls=len(rows),rows=rows,nativeCompared=False,windowsVerified=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--partial',action='store_true');a=p.parse_args()
    name='active-gameplay'+('-control' if a.control else '')
    if a.partial:
        path=ROOT/'build/research'/(name+'-partial.json');raw=path.read_bytes();proof=json.loads(path.with_suffix('.checkpoint.json').read_bytes())
        assert len(raw)==proof['bytes'] and digest(raw)==proof['sha256'];doc=json.loads(raw)
    else:_,raw,doc=capture(name)
    result=summarize(doc);result['sourceSHA256']=digest(raw)
    path=ROOT/'build/research'/(name+('-partial' if a.partial else '')+'-trajectory.json')
    path.write_text(json.dumps(result,indent=2)+'\n')
    print(path,result['returnedCalls'],'returned calls')


if __name__=='__main__':main()
