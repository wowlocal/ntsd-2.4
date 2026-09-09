#!/usr/bin/env python3
"""Static opoint inventory from the accepted original-loaded53-bit catalog."""
import base64
import json
import struct
import zlib
from collections import Counter
from import_ntsd import ROOT, DEFAULT_SOURCE, read_bytes
from accept_initialized_gameplay import digest


def main():
    parent = json.loads((ROOT/'docs/evidence/loaded-catalog53.json').read_bytes())
    raw = (ROOT/'build/original'/parent['corpus']).read_bytes()
    assert digest(raw) == parent['sha256'] and len(raw) == parent['bytes']
    assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/parent['fixture']).read_bytes()) == parent['fixtureSHA256']
    catalog = json.loads(raw)
    records = []; unknown = []; objects = 0
    for obj in catalog['children']:
        if obj['kind'] != 'object': continue
        objects += 1
        assert digest(read_bytes(DEFAULT_SOURCE/obj['path'].replace('\\', '/'))) == obj['source']
        values = []
        for which in ('bytes', 'defined'):
            key = obj['storage'][which]; blob = catalog['blobs'][key]
            data = zlib.decompress(base64.b64decode(blob['deflate']), -15)
            assert len(data) == blob['count'] and digest(data) == key
            values.append(data)
        data, mask = values
        for number in range(400):
            offset = 0x7a4+number*0x178
            if not data[offset]: continue
            if not all(mask[offset+0x58:offset+0x78]): unknown.append([obj['index'], number]); continue
            fields = struct.unpack_from('<8i', data, offset+0x58)
            if fields[0] > 0 and fields[6] > 0:
                records.append(dict(object=obj['index'], id=obj['id'], frame=number, kind=fields[0], action=fields[3],
                                    oid=fields[6], facing=fields[7], count=fields[7]//10 if fields[7] > 10 else 1))
    report = dict(exeSHA256=catalog['exeSHA256'], parentSHA256=parent['sha256'],
                  parentFixtureSHA256=parent['fixtureSHA256'], objects=objects,
                  scope='Static inventory of present Frames in the accepted original-loaded catalog; no opoint execution, native or Windows claim.',
                  entries=len(records), unknown=unknown, counts=dict(Counter(r['count'] for r in records)),
                  invalidActions=[r for r in records if not 0 <= r['action'] < 400], records=records)
    raw = (json.dumps(report, separators=(',', ':'))+'\n').encode()
    (ROOT/'build/research/postdraw-opoint-dat-survey.json').write_bytes(raw)
    report.pop('records')
    report.update(corpus='postdraw-opoint-dat-survey.json', bytes=len(raw), sha256=digest(raw), nativeCompared=False, windowsVerified=False)
    (ROOT/'docs/evidence/postdraw-opoint-dat-survey.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__': main()
