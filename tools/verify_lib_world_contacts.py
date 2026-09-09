#!/usr/bin/env python3
"""Verify immutable whole-contact source bytes, masks and live hook provenance.

Read-only transport/blob/ABI consistency and old-control comparisons; this is
not another game execution or native/Windows result. Actual DLL instructions
and successful declared loader operations are retained in the source corpus.
"""
import base64,hashlib,json,zlib
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
BASE=0x36000000
def fixture(name):
    raw=(ROOT/'native/Tests/NTSDCoreTests/Fixtures'/name).read_bytes();w=json.loads(raw)
    b=zlib.decompress(base64.b64decode(w['deflate']),-15)
    assert len(b)==w['count'] and digest(b)==w['sha256']
    return json.loads(b),digest(raw)

def main():
    raw=(ROOT/'build/original/lib-world-contacts.json').read_bytes()
    report=json.loads((ROOT/'build/research/lib-world-contacts.json').read_bytes());doc=json.loads(raw)
    assert len(raw)==report['bytes'] and digest(raw)==report['sha256']
    assert len(doc['cases'])==10661 and doc['fpcw']==0x37f and doc['entryFPSW']==0 and doc['entryTag']==0xffff
    assert not doc['nativeCompared'] and not doc['windowsVerified']
    old,sha=fixture('original-world-contacts.json');assert sha==doc['prior']['fixtureSHA256']
    init,_=fixture('original-lib-initialization.json');installed=doc['installation']
    assert installed['base']==BASE and installed['result']==1 and len(installed['relocations'])==76
    original=init['cases'][0]
    assert len(installed['patches'])==len(original['patches'])==13
    for new,ref in zip(installed['patches'],original['patches']):
        assert (new['address'],new['count'],new['before'])==(ref['address'],ref['count'],ref['before'])
        a,b=bytes.fromhex(new['after']),bytes.fromhex(ref['after'])
        if len(a)==2:assert a==b==b'\x90\x90'
        else:
            assert a[0]==b[0]==0xe9
            assert (int.from_bytes(a[1:],'little')-int.from_bytes(b[1:],'little'))%2**32==BASE-0x10000000
    assert {p-BASE for p in installed['instructions']}=={p['address']-0x10000000 for p in original['instructions'] if 0x10000000<=p['address']<0x10005000}
    assert Counter(e['name'] for e in installed['events'])=={'VirtualAlloc':2,'VirtualProtect':26,'RtlMoveMemory':13}
    blobs={}
    for key,item in doc['blobs'].items():
        b=zlib.decompress(base64.b64decode(item['deflate']),-15)
        assert digest(b)==key and len(b)==item['count'];blobs[key]=b
    assert len(blobs)==1924
    labels=set();pcs=set();sites=Counter();continuations=Counter();states=Counter();kinds=Counter()
    for i,c in enumerate(doc['cases']):
        assert c['label'] not in labels;labels.add(c['label']);pcs.update(c['instructions'])
        pool,mask,glob=[blobs[c[k+'SHA256']] for k in ('pool','mask','globals')]
        assert len(pool)==len(mask)==424408 and len(glob)==46144 and set(mask)<={0,1}
        assert c['exitSP']==0x1000e000 and c['exitCW']==0x37f and c['exitTag']==0xffff and (c['exitFPSW']>>11)&7==0
        if i<7925:
            assert c['pristineOutcomeEqual']
            assert all(c[k]==v for k,v in old['cases'][i].items()),(i,c['label'])
        aliases=dict(c.get('aliases',[]))
        for h in c['hooks']:
            sites[h['site']]+=1;continuations[(h['site'],h['continuation'])]+=1
            assert h['sp']==h['pairSP']-0x40
            assert h['attackAddress']==0x70000020+0x500*aliases.get(h['attacker'],h['attacker'])
            assert h['defendAddress']==0x70000020+0x500*aliases.get(h['defender'],h['defender'])
            assert h['cw']==h['exitCW']==0x37f and h['fpsw']==h['exitFPSW'] and h['tag']==h['exitTag']==0xffff
            assert h['site'] in (0x4176ac,0x4177b9)
            allowed={0x4176cb,0x417f59} if h['site']==0x4176ac else {0x4177ca,0x41780b,0x417866}
            assert h['continuation'] in allowed
            if h['site']==0x4177b9:states[h['attackState']]+=1
            else:kinds[h['kind']]+=1
    assert pcs==set(doc['instructions']) and len(pcs)==1713
    static=json.loads((ROOT/'docs/evidence/lib-runtime-static.json').read_bytes())
    hookpcs={r['address']-0x10000000+BASE for r in static['instructions'] if 0x10001807<=r['address']<=0x10001a94 or 0x100011b9<=r['address']<=0x10001230}
    assert {p for p in pcs if BASE<=p<BASE+0x5000}<=hookpcs
    result=dict(rawSHA256=digest(raw),rawBytes=len(raw),cases=len(doc['cases']),wholePoolBytes=len(doc['cases'])*424408,
        fullMaskBytes=len(doc['cases'])*424408,globalsBytes=len(doc['cases'])*46144,
        allBlobsVerified=len(blobs),pristineWholeOutcomesUnchanged=7925,
        installerRelocations=76,installerActualPCs=len(installed['instructions']),
        wholeHelpers=sum(c['helpers'] for c in doc['cases']),events=sum(len(c['events']) for c in doc['cases']),
        actualEXEPCs=sum(p<BASE for p in pcs),actualDLLPCs=sum(p>=BASE for p in pcs),staticDLLPCs=len(hookpcs),
        missingStaticDLLPCs=[hex(p-BASE+0x10000000) for p in sorted(hookpcs-pcs)],
        hookSites={hex(k):v for k,v in sites.items()},hookContinuations={f'{k:x}->{v:x}':n for (k,v),n in continuations.items()},
        attackerStatesAtTeamHook=dict(sorted(states.items())),kindsAtTypeHook=dict(sorted(kinds.items())),
        windowsVerified=False)
    (ROOT/'build/research/lib-world-contacts-source-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('kindsAtTypeHook','attackerStatesAtTeamHook')},indent=2))
if __name__=='__main__':main()
