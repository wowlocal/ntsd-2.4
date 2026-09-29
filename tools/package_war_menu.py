#!/usr/bin/env python3
"""Package the original War menu bitmaps (BATTLEMODE, BATTLETROOPS) for the app.

Extracts the two RT_BITMAP resources from the pinned NTSD EXE by PE structure
only (no execution) into native/Sources/NTSDCore/Resources/OriginalWarMenu with
a manifest, in the same form as OriginalCharacterMenu. The method is checked by
re-extracting CHARMENU and comparing it with the bundled CHARMENU.dib.
APPLICATION_WAR_PLAN.md W2.
"""
import hashlib, json
from pathlib import Path
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE, ROOT, read_bytes

EXE_SHA256 = '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
NAMES = ['BATTLEMODE', 'BATTLETROOPS']

def digest(b): return hashlib.sha256(b).hexdigest()

def main():
    exe = DEFAULT_SOURCE / 'NTSD 2.4.exe'
    raw = read_bytes(exe); assert digest(raw) == EXE_SHA256
    pe = PE(raw)
    bitmaps = {r['path'][1]: raw[r['fileOffset']:r['fileOffset'] + r['size']]
               for r in pe.resources() if r['path'][0] == 2}
    bundled = (ROOT / 'native/Sources/NTSDCore/Resources/OriginalCharacterMenu/CHARMENU.dib').read_bytes()
    assert bitmaps['CHARMENU'] == bundled, 'extraction method differs from the bundled menu DIBs'
    out = ROOT / 'native/Sources/NTSDCore/Resources/OriginalWarMenu'
    out.mkdir(exist_ok=True)
    entries = []
    for name in NAMES:
        data = bitmaps[name]
        assert int.from_bytes(data[:4], 'little') == 40
        (out / f'{name}.dib').write_bytes(data)
        entries.append(dict(name=name, path=f'{name}.dib', count=len(data), sha256=digest(data)))
    manifest = json.dumps(dict(version=1, exeSHA256=EXE_SHA256, entries=entries), indent=2) + '\n'
    (out / 'manifest.json').write_text(manifest)
    print(json.dumps(dict(entries=entries, manifestSHA256=digest(manifest.encode())), indent=1))

if __name__ == '__main__':
    main()
