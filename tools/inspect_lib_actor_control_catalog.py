#!/usr/bin/env python3
"""Locate library control states85/86 in the pinned original loaded DAT catalog.

The accepted CW027f catalog, its complete Object blobs/masks and original DAT
hashes are read-only evidence. Census all137 Objects and all400 inline frame
slots to identify actual state85/86 data and the next-slot storage relevant to
state85's conditional frame increment. This is a static data inventory, not a
control-call execution, proof that a next frame is reached, or native/Windows
behavior. Unknown fields remain unknown; no sparse frame is filled in.
"""
import base64
import hashlib
import json
import struct
import zlib
from collections import Counter
from pathlib import Path
from import_ntsd import ROOT, DEFAULT_SOURCE, read_bytes

digest = lambda data: hashlib.sha256(data).hexdigest()


def main():
    report = json.loads((ROOT/'docs/evidence/loaded-catalog53.json').read_bytes())
    assert report['nativeCompared'] and report['precision']['gameControlWord'] == 0x27f
    packed = (ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes()
    assert digest(packed) == report['fixtureSHA256']
    wrapper = json.loads(packed);raw = zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
    assert len(raw) == wrapper['count'] and digest(raw) == wrapper['sha256']
    assert digest(raw+b'\n') == report['sha256'] and len(raw)+1 == report['bytes']
    catalog = json.loads(raw)
    def blob(key):
        b = catalog['blobs'][key];value = zlib.decompress(base64.b64decode(b['deflate']),-15)
        assert digest(value) == key and len(value) == b['count']
        return value
    result = [];objects = 0;types = Counter();unknown_live_states = []
    present_frames = 0;known_states = 0;unknown_inactive_states = 0;state_histogram = Counter()
    for item in catalog['children']:
        if item['kind'] != 'object':continue
        objects += 1;types[item['objectType']] += 1
        path = (DEFAULT_SOURCE/item['path'].replace('\\','/')).resolve()
        assert DEFAULT_SOURCE.resolve() in path.parents
        assert digest(read_bytes(path)) == item['source']
        data = blob(item['storage']['bytes']);mask = blob(item['storage']['defined'])
        assert len(data) == len(mask) == 0x25360 and all(v in (0,1) for v in mask)
        frames = []
        for index in range(400):
            start = 0x7a4+index*0x178
            assert mask[start]
            present_frames += data[start] != 0
            if not all(mask[start+8:start+12]):
                if data[start] != 0:unknown_live_states.append(dict(objectIndex=item['index'],frame=index))
                else:unknown_inactive_states += 1
                continue
            state = struct.unpack_from('<i',data,start+8)[0]
            known_states += 1;state_histogram[state] += 1
            if state not in (85,86):continue
            def known_word(offset):
                return struct.unpack_from('<i',data,offset)[0] if all(mask[offset:offset+4]) else None
            following = start+0x178
            next_slot = dict(inFrameTable=index+1<400)
            if index+1<400:
                next_slot.update(flag=data[following] if mask[following] else None,
                    state=known_word(following+8),velocity=[known_word(following+o) for o in (0x14,0x18,0x1c)])
            frames.append(dict(index=index,present=data[start],state=state,velocity=[known_word(start+o) for o in (0x14,0x18,0x1c)],
                nextSlot=next_slot,frameBytesSHA256=digest(data[start:start+0x178]),frameMaskSHA256=digest(mask[start:start+0x178])))
        if frames:
            result.append(dict(index=item['index'],id=item['id'],objectType=item['objectType'],path=item['path'],sourceSHA256=item['source'],
                objectBytesSHA256=item['storage']['bytes'],objectMaskSHA256=item['storage']['defined'],frames=frames))
    assert objects == 137 and types[0] == 42
    counts = Counter(str(f['state']) for obj in result for f in obj['frames'])
    type_zero = Counter(str(f['state']) for obj in result if obj['objectType']==0 for f in obj['frames'])
    doc = dict(scope=__doc__,parent=dict(fixture=report['fixture'],fixtureSHA256=report['fixtureSHA256'],rawSHA256=report['sha256']),
        objectsScanned=objects,frameSlotsScanned=objects*400,objectTypes=dict(types),objectsWithStates=len(result),
        presentFrames=present_frames,knownStateSlots=known_states,knownStateHistogram=dict(state_histogram),unknownInactiveStateSlots=unknown_inactive_states,
        frameStates=dict(counts),typeZeroFrameStates=dict(type_zero),unknownLiveFrameStates=unknown_live_states,
        objects=result,staticOnly=True,nativeCompared=False,windowsVerified=False)
    (ROOT/'docs/evidence/lib-actor-control-catalog-inventory.json').write_text(json.dumps(doc,indent=2)+'\n')
    print(json.dumps({k:v for k,v in doc.items() if k not in ('scope','objects')},indent=2))


if __name__ == '__main__':main()
