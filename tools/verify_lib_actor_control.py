#!/usr/bin/env python3
"""Independently verify retained whole NTSD library-control source evidence.

Use immutable EXE/lib.dll identities, accepted installation and7168 controlled
Unicorn calls. Reconstruct complete Actor bytes/masks and globals from declared
inputs and recorded original stores, plus the entire unchanged Object backing.
Check helper returns and live hook/FPU provenance separately from native state.
This performs no new game execution and does not establish Windows/device or
whole initialized application behavior.
"""
import base64
import hashlib
import json
import struct
import zlib
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT/'native/Tests/NTSDCoreTests/Fixtures'
EXE = '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
LIB = '28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
digest = lambda raw: hashlib.sha256(raw).hexdigest()


def validate():
    raw = (ROOT/'build/original/lib-actor-control.json').read_bytes()
    report = json.loads((ROOT/'build/research/lib-actor-control.json').read_bytes())
    assert digest(raw) == report['sha256'] and len(raw) == report['bytes']
    doc = json.loads(raw)
    assert doc['exeSHA256'] == EXE and doc['libSHA256'] == LIB
    assert len(doc['cases']) == 7168 and not doc['nativeCompared'] and not doc['windowsVerified']
    assert len({c['label'] for c in doc['cases']}) == 7168
    packed = (FIXTURES/'original-lib-initialization.json').read_bytes()
    assert digest(packed) == '3697e7d6c40c78fd1ae026f658c28654a4ed825bde24c087df7ad51242f0584c'
    wrapper = json.loads(packed);body = zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
    assert len(body) == wrapper['count'] and digest(body) == wrapper['sha256']
    assert doc['installation'] == json.loads(body)['cases'][0]
    global_base = 0x44d000
    global_size = 0xb440
    def patch(data,offset,text):
        value = bytes.fromhex(text)
        assert 0 <= offset <= offset+len(value) <= len(data)
        data[offset:offset+len(value)] = value
        return len(value)
    old = json.loads((FIXTURES/'original-state-constructors.json').read_bytes())
    for fill,template in doc['templates'].items():
        prior = next(c for c in old['cases'] if c['label'] == 'actor-'+fill+('-100' if fill=='a5' else '-1400'))
        assert template['bytes'] == prior['bytes'] and template['defined'] == prior['defined']
    events = Counter();groups = Counter();states = Counter();frame_stores = Counter()
    helpers = 0;actor_stores = 0;global_stores = 0;checkpoints = 0;all_pcs = set();new_entry_changed_frames = 0
    for index,c in enumerate(doc['cases']):
        groups[c['group']] += 1
        template = doc['templates'][c['fill']]
        actor = bytearray.fromhex(template['bytes']);mask = bytearray(template['defined'])
        assert len(actor) == len(mask) == 0x420
        for offset,text in c['actor']:
            count = patch(actor,offset,text);mask[offset:offset+count] = b'\1'*count
        original_frame = int.from_bytes(actor[0x70:0x74],'little')
        for w in c['writes']:
            assert w['kind'] == 'instruction' and int(w['instruction'],16) in c['instructions']
            size = patch(actor,w['offset'],w['bytes']);mask[w['offset']:w['offset']+size] = b'\1'*size
            if 0x10001125 <= int(w['instruction'],16) <= 0x100011b8 and w['offset'] == 0x70:
                frame_stores[w['instruction']] += 1
            actor_stores += 1
        assert actor.hex() == c['after'] and mask.hex() == c['defined']
        globals_ = bytearray(global_size)
        globals_[0x44ff90-global_base:0x44ff90-global_base+3000] = bytes(1+i%255 for i in range(3000))
        struct.pack_into('<i',globals_,0x44d034-global_base,1)
        for address,text in c.get('globals',[]):patch(globals_,address-global_base,text)
        for w in c['globalWrites']:
            assert w['pc'] in c['instructions']
            patch(globals_,w['address']-global_base,w['value'].to_bytes(w['size'],'little').hex())
            global_stores += 1
        assert digest(globals_) == c['globalsSHA256']
        obj = bytearray(0x40000)
        for offset,text in doc['header']+c.get('header',[]):patch(obj,offset,text)
        for n in range(400):
            start = 0x7a4+n*0x178;obj[start] = 1
            struct.pack_into('<i',obj,start+8,doc['states'].get(str(n),3))
            if n in (60,65,80,85,90):struct.pack_into('<i',obj,start+0x4c,100)
        for n,offset,text in c.get('frames',[]):
            assert 0 <= n < 400;patch(obj,0x7a4+n*0x178+offset,text)
        assert digest(obj) == c['objectSHA256']
        assert c['end'] == dict(pc=0x30000000,sp=0x2000f00c)
        before,after = c['fpuBefore'],c['fpuAfter']
        assert before['cw'] == after['cw'] == c['fpcw'] in (0x23f,0x37f)
        assert before['tag'] == after['tag'] == 0xffff and ((before['sw']|after['sw'])>>11)&7 == 0
        entry = [p for p in c['checkpoints'] if p['pc'] == 0x41408b]
        assert len(entry) == 1
        e = entry[0];frame = e['frame'];assert e['eax'] == frame and 0 <= frame < 400
        assert e['edi'] == 0 and e['ecx'] == 0x50000000 and e['edx'] == frame*0x178
        assert e['esi'] == int(template['address'],16) and e['sp'] == 0x2000f000-20
        state = struct.unpack_from('<i',obj,0x7ac+frame*0x178)[0];states[state] += 1
        if original_frame != frame:new_entry_changed_frames += 1
        for p in c['checkpoints']:
            fp = p['fpu'];top = (fp['sw']>>11)&7
            assert fp['cw'] == c['fpcw'] and top == 6 and fp['tag'] == 0x4fff
            assert fp['registers'][top] == [0x8000000000000000,0x3fff] and fp['registers'][(top+1)&7] == [0,0]
        children = [p for p in c['checkpoints'] if p['pc'] == 0x10001178]
        continuation = [p for p in c['checkpoints'] if p['pc'] in (0x414099,0x414243)]
        assert len(continuation) == 1 and continuation[0]['ecx'] == 0x50000000
        assert continuation[0]['pc'] == (0x414099 if state == 5 else 0x414243)
        if state in (85,86):
            assert len(children) == 2 and [p['edx']&255 for p in children] == [0,1]
            assert all(p['ecx'] == (1 if state==85 else 0) and p['edi'] == 0 and p['sp'] == e['sp']-8 for p in children)
        else:assert not children
        for h in c['helperReturns']:
            assert h['actualSP'] == h['sp']+4+h['pop'] and h['actualSaved'] == h['saved']
            assert h['entry'] in c['instructions'] and h['returnPC'] in c['instructions']
            helpers += 1
        events.update(v['kind'] for v in c['events']);checkpoints += len(c['checkpoints']);all_pcs.update(c['instructions'])
    assert groups == {'new-states':4096,'routing':384,'same-call-transitions':2304,'later-frame-velocity':384}
    assert sorted(all_pcs) == doc['instructions'] and STOP_NOT_EXECUTED not in all_pcs
    static = json.loads((ROOT/'docs/evidence/lib-runtime-static.json').read_bytes())
    expected_hook = {r['address'] for r in static['instructions'] if 0x10001125 <= r['address'] <= 0x100011b8}
    actual_hook = {pc for pc in all_pcs if 0x10000000 <= pc < 0x10005000}
    assert actual_hook == expected_hook
    result = dict(cases=len(doc['cases']),rawBytes=len(raw),rawSHA256=digest(raw),completeInstallationReproduced=True,
        completeActorBytesMasksFromStores=True,completeGlobalsFromStores=True,completeObjectHashesFromInputs=True,
        actorStores=actor_stores,globalStores=global_stores,helperReturns=helpers,checkpoints=checkpoints,
        events=dict(events),statesAtHook=dict(states),framesChangedBeforeHook=new_entry_changed_frames,libraryFrameStores=dict(frame_stores),
        actualEXEPCs=sum(0x400000<=pc<0x500000 for pc in all_pcs),actualDLLPCs=len(actual_hook),allStaticHookStartsObserved=True,
        sourceEDIAndLiveFPUProvenanceVerified=True,nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-actor-control-source-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return result


STOP_NOT_EXECUTED = 0x30000000
if __name__ == '__main__':validate()
