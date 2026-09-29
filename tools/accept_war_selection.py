#!/usr/bin/env python3
"""Install the War (mode4) character-screen corpus as a test fixture.

Packs build/research/war-selection/capture1.json (tools/oracle_war_selection.py)
in the transport form read by OriginalLibSelectionStageTests: raw deflate split
into enveloped parts plus a small index. Writes docs/evidence/application-war-selection.json.
The Native comparison itself is the test (NTSD_WAR_SELECTION may point at the raw capture).
APPLICATION_WAR_PLAN.md W1.
"""
import base64, hashlib, json, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = ROOT / 'build/research/war-selection/capture1.json'
FIXTURES = ROOT / 'native/Tests/NTSDCoreTests/Fixtures'
NAME = 'original-war-selection'
PART = 50_000_000


def digest(b): return hashlib.sha256(b).hexdigest()


def raw_deflate(data):
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    return c.compress(data) + c.flush()


def envelope(raw):
    return (json.dumps(dict(count=len(raw), sha256=digest(raw),
                            deflate=base64.b64encode(raw_deflate(raw)).decode()),
                       separators=(',', ':')) + '\n').encode()


def main():
    raw = CAPTURE.read_bytes()
    doc = json.loads(raw)
    deflate = raw_deflate(raw)
    parts = []
    for i in range(0, len(deflate), PART):
        name = f'{NAME}-part{len(parts)}.json'
        data = envelope(deflate[i:i + PART])
        (FIXTURES / name).write_bytes(data)
        parts.append(dict(name=name, bytes=len(data), sha256=digest(data)))
    index = (json.dumps(dict(count=len(raw), sha256=digest(raw), deflateSHA256=digest(deflate),
                             deflateParts=[p['name'] for p in parts]), separators=(',', ':')) + '\n').encode()
    (FIXTURES / f'{NAME}.json').write_bytes(index)
    cases = doc['cases']
    report = dict(
        scope=doc['scope'].strip(),
        tool='tools/oracle_war_selection.py',
        exeSHA256=doc['exeSHA256'], libSHA256=doc['libSHA256'], crtSHA256=doc['crtSHA256'],
        capture=str(CAPTURE.relative_to(ROOT)), captureBytes=len(raw), captureSHA256=digest(raw),
        cases=len(cases), chains={'main': sum(1 for c in cases if not c['spec']['control']),
                                  'control': sum(1 for c in cases if c['spec']['control'])},
        events=sum(len(c['events']) for c in cases),
        ends=sorted({c['end'] for c in cases}),
        fixture=dict(index=f'{NAME}.json', indexSHA256=digest(index), parts=parts),
        nativeComparison='OriginalLibSelectionStageTests.testWarComputerSelectionWithLibraryText',
        windowsVerified=False)
    (ROOT / 'docs/evidence/application-war-selection.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ('cases', 'chains', 'events', 'captureSHA256')}, indent=1), [p['bytes'] for p in parts])


if __name__ == '__main__':
    main()
