#!/usr/bin/env python3
"""Verify and losslessly package saved NTSD library-transform reference data.

The existing pinned EXE/lib Unicorn results describe the slot-prefix behavior
under declared allocation bindings. This reads those completed JSON captures,
checks their summaries and the retained 897-case prefix, and roundtrips full raw
bytes into the existing Native test envelope. No source harness is imported or
executed. Four source memory faults remain separate from returned comparisons.
This is corpus/transport verification, not a new instruction or full-store audit.
"""

import argparse
import base64
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import zlib

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'native/Tests/NTSDCoreTests/Fixtures'
PROFILES = {
    'lib-transforms': (1622913, 'afbba6e63fcc3b94ba8453e332ace5659d0b0c50e6311eca0308a1cc35f19dd6', 1688, 2827, 371, 744),
    'lib-transform-boundaries': (107457, 'cbfd623e3a64e0b6ac96ec7c71796e81b746bb6b316b984a7ea7282708d3427d', 72, 653, 68, 568),
}


def require(condition, detail):
    if not condition:
        raise ValueError(detail)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def unpack(raw):
    value = json.loads(raw)
    decoded = zlib.decompress(base64.b64decode(value['deflate']), -15)
    require(len(decoded) == value['count'] and sha(decoded) == value['sha256'], 'envelope pin')
    return decoded


def verify_and_package(output):
    results = {}
    documents = {}
    for name, (size, digest, cases, events, writes, starts) in PROFILES.items():
        source = ROOT / 'build/original' / (name + '.json')
        raw = source.read_bytes()
        require(len(raw) == size and sha(raw) == digest, name + ' immutable raw')
        d = json.loads(raw)
        report = json.loads((ROOT / 'build/research' / (name + '.json')).read_bytes())
        require(report['bytes'] == size and report['sha256'] == digest, 'historical report pin')
        require(d['exeSHA256'] == '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
                and d['libSHA256'] == '28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba', 'artifacts')
        require(len(d['cases']) == len({c['label'] for c in d['cases']}) == cases, 'case identities')
        require(len(d['instructions']) == len(set(d['instructions'])) == starts, 'observed instruction union')
        require(sum(len(c['events']) for c in d['cases']) == events, 'ordered event count')
        require(sum(len(c['extendedWrites']) for c in d['cases']) == writes, 'recorded write count')
        require(d['fpcw'] == 0x27f and d['actorSize'] == 0x420 and d['actorStride'] == 0x500,
                'declared source environment')
        require(d['poolAddress'] == 0x70000020 and d['tailCount'] == 0x1000 and d['tailInitial'] == 'a5', 'declared storage')
        for case in d['cases']:
            require(case['endPC'] in (0x41fb0b, 0x4214c6), 'returned boundary')
            for field in ('poolSHA256', 'maskSHA256', 'globalsSHA256', 'tailSHA256'):
                require(len(bytes.fromhex(case[field])) == 32, 'record digest')
            for write in case['extendedWrites']:
                require(0 <= write['actor'] < 400 and write['pc'] == 0x36001112, 'write identity')
                require(write['address'] == d['poolAddress'] + write['actor'] * d['actorStride'] + 0x7b4,
                        'declared write location')
                require(len(bytes.fromhex(write['before'])) == 4 and 0 <= write['value'] <= 0xffffffff, 'write bytes')
        faults = d.get('faults', [])
        require(len(faults) == (4 if name.endswith('boundaries') else 0), 'separate fault count')
        for fault in faults:
            require(fault['errno'] == 7 and fault['error'] == 'Invalid memory write (UC_ERR_WRITE_UNMAPPED)', 'fault kind')
            require(fault['event']['pc'] == 0x36001112 and fault['event']['size'] == 4
                    and fault['event']['address'] == 0x70000020 + 399 * 0x500 + 0x7b4, 'recorded terminal fault')
        compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
        packed = compressor.compress(raw) + compressor.flush()
        envelope = (json.dumps(dict(count=len(raw), sha256=sha(raw), deflate=base64.b64encode(packed).decode()),
                               separators=(',', ':')) + '\n').encode()
        require(unpack(envelope) == raw, 'full raw byte roundtrip')
        path = FIXTURES / ('original-' + name + '.json')
        if path.exists():
            require(path.read_bytes() == envelope, 'existing fixture differs; preserve it')
        else:
            with path.open('xb') as stream:
                stream.write(envelope)
        require(unpack(path.read_bytes()) == raw, 'published fixture roundtrip')
        results[name] = dict(source=str(source), rawBytes=size, rawSHA256=digest,
                             fixture=str(path.relative_to(ROOT)), packedBytes=len(envelope), packedSHA256=sha(envelope),
                             returnedCases=cases, events=events, recordedExtendedWrites=writes,
                             instructionStarts=starts, sourceFaults=len(faults), groups=dict(Counter(c['group'] for c in d['cases'])))
        documents[name] = d
    main, boundary = documents.values()
    for key in ('header', 'headerPatches', 'ids', 'states', 'fpcw', 'installation'):
        require(main[key] == boundary[key], 'shared reference inputs: ' + key)
    pristine = json.loads(unpack((FIXTURES / 'original-postdraw-slot-prefix.json').read_bytes()))
    retained = [{k: v for k, v in c.items() if k not in ('extendedWrites', 'tailSHA256')} for c in main['cases'][:897]]
    require(retained == pristine['cases'], '897 retained pristine cases')
    result = dict(scope=__doc__, timeUTC=datetime.now(timezone.utc).isoformat(), corpora=results,
                  retainedPristineCases=897, originalExecuted=False, nativeCompared=False,
                  fullLoopCompared=False, windowsVerified=False)
    with output.open('x') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print({name: row['packedBytes'] for name, row in results.items()})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    require(not args.output.exists(), 'verification output exists')
    verify_and_package(args.output)
