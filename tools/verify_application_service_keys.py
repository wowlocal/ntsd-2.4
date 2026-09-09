#!/usr/bin/env python3
"""Verify service-key source inputs, complete global effects and packaging.

Only43e9db..43ea95 executes in this controlled corpus. Fresh static PE byte
checks distinguish its57 observed starts from the full236-instruction
dispatcher. Native comparison and original Windows/device input are separate.
"""
import argparse,base64,itertools,json,struct,zlib
from collections import Counter
from accept_initialized_gameplay import ROOT,FIXTURES,capture,digest
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE
from inspect_application_dispatcher import capture as inspect_dispatcher

GLOBAL,END,KEYS=0x44d000,0x4593a8,0x455378
FIELDS=(0x4593a4,0x450bec,0x4593a0)


def validate():
    report,raw,doc=capture('application-service-keys');assert len(doc['cases'])==report['cases']==3964
    static=inspect_dispatcher();pcs={x['address'] for x in static['instructions'] if 0x43e9db<=x['address']<0x43ea95}
    assert static['exeSHA256']==doc['exeSHA256']==EXE_SHA256 and set(doc['instructions'])==pcs and len(pcs)==57
    exe=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');pe=PE(exe);image=bytearray(0x100000)
    for s in pe.sections:
        if s['name']!='.rsrc':image[s['rva']:s['rva']+s['fileSize']]=exe[s['fileOffset']:s['fileOffset']+s['fileSize']]
    original=bytes(image[GLOBAL-pe.base:END-pe.base])
    declared=[]
    for sequence,diagnostics,mode,mask in itertools.product(range(4),range(2),range(3),range(64)):
        declared.append(([sequence,diagnostics,mode],[k for n,k in enumerate((65,66,67,112,113,114)) if mask>>n&1]))
    for key,sequence,diagnostics in itertools.product(range(300),range(4),range(2)):declared.append(([sequence,diagnostics,1],[key]))
    chains={'held-and-released':[[],[65],[65],[],[66],[66],[],[67],[67],[],[112],[113],[114],[112,113,114],[]],
        'interrupted-scan':[[65],[70],[66],[67],[65,66,67],[65,66,67],[]],
        'scan-end':[[249],[250],[299],[65,250],[66,299],[67,250]]}
    retained={};steps=Counter();stores=Counter();reads=0
    for n,c in enumerate(doc['cases']):
        assert c['index']==n and c['end']==dict(pc=0x43ea95,sp=0x1000f000) and c['fpcw']==0x23f
        if n<len(declared):assert (c['before'],c['pressed'])==declared[n] and c['chain'] is None and c['step'] is None
        else:
            label=c['chain'];assert c['step']==steps[label] and c['pressed']==chains[label][steps[label]]
            assert c['before']==retained.get(label,[0,0,0]);steps[label]+=1;retained[label]=c['after']
        assert set(c['instructions'])<=pcs and 0x43ea95 not in c['instructions']
        keyboard=bytes(100 if k in c['pressed'] else 117 for k in range(300));assert digest(keyboard)==c['keyboardUnchangedSHA256']
        value=bytearray(original)
        for address,item in zip(FIELDS,c['before']):value[address-GLOBAL:address-GLOBAL+4]=struct.pack('<I',item)
        value[KEYS-GLOBAL:KEYS-GLOBAL+300]=keyboard;assert digest(value)==c['globalsBeforeSHA256']
        assert [w['address'] for w in c['writes'][:2]]==[0x450bec,0x4593a4]
        for w in c['writes']:
            assert w['address'] in FIELDS;value[w['address']-GLOBAL:w['address']-GLOBAL+4]=struct.pack('<I',w['value']);stores[hex(w['address'])]+=1
        assert digest(value)==c['globalsAfterSHA256']
        assert [int.from_bytes(value[a-GLOBAL:a-GLOBAL+4],'little') for a in FIELDS]==c['after']
        assert value[KEYS-GLOBAL:KEYS-GLOBAL+300]==keyboard
        assert c['reads']==list(range(250))+([112,113,114] if c['after'][1] else []);reads+=len(c['reads'])
        assert c['registers']==[c['after'][0],0x11223364,250,c['after'][1],0,1,2,0x1000f000]
    assert steps==Counter({k:len(v) for k,v in chains.items()}) and sum(stores.values())==9278 and reads==997303
    report.update(fullGlobalStoreReconstruction=True,keyboardBytesUnchanged=True,allPrefixInstructionStartsExecuted=True,
        staticDispatcherInstructions=236,wholeDispatcherExecuted=False,ownGameJoin=False,storeCounts=dict(stores),retainedChains=dict(steps))
    return report,raw,doc


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accepted',action='store_true');a=p.parse_args();report,raw,doc=validate()
    if a.accepted:
        accepted=json.loads((ROOT/'docs/evidence/application-service-keys.json').read_bytes());assert accepted['nativeCompared']
        packed=(FIXTURES/accepted['fixture']).read_bytes();wrapper=json.loads(packed);restored=zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
        assert restored+b'\n'==raw and json.loads(restored)==doc and len(restored)==wrapper['count'] and digest(restored)==wrapper['sha256']
        assert accepted['sha256']==digest(raw) and accepted['bytes']==len(raw) and accepted['fixtureSHA256']==digest(packed) and accepted['fixtureBytes']==len(packed)
        before=json.loads((ROOT/'build/research/application-service-keys-prior-pins.json').read_bytes());now=json.loads((ROOT/'build/research/application-service-keys-fixture-pins.json').read_bytes())
        assert all(now[n]==sha and digest((FIXTURES/n).read_bytes())==sha for n,sha in before.items())
        assert all(digest((FIXTURES/n).read_bytes())==sha for n,sha in now.items())
        vendor=ROOT/'native/Sources/NTSDReplayCodec';up=json.loads((vendor/'upstream.json').read_bytes());assert len(up['files'])==10
        assert all(digest((vendor/'vendor'/n).read_bytes())==v['vendoredSHA256'] for n,v in up['files'].items())
        report.update(fullRawPackedBytesEqual=True,completeJSONEqual=True,packedBytes=len(packed),packedSHA256=digest(packed),priorPinsUnchanged=len(before),milestonePins=len(now),vendorHashesVerified=10)
    (ROOT/'build/research/application-service-keys-artifact-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))


if __name__=='__main__':main()
