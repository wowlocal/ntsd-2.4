#!/usr/bin/env python3
"""Bundle original graphics and WAV audio; never include Windows executables."""
import shutil
from import_ntsd import ROOT, DEFAULT_SOURCE, read_bytes

destination = ROOT / 'build/NTSD Native.app/Contents/Resources/Assets'
count = 0
for path in DEFAULT_SOURCE.rglob('*'):
    if not path.is_file() or path.suffix.lower() not in {'.bmp', '.wav'}:
        continue
    read_bytes(path)  # fail on any un-restored LFS pointer
    target = destination / path.relative_to(DEFAULT_SOURCE)
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or target.stat().st_size != path.stat().st_size or target.stat().st_mtime_ns != path.stat().st_mtime_ns:
        shutil.copy2(path, target)
    count += 1
print(f'Packaged {count} original BMP/WAV resources.')
shutil.copytree(ROOT / 'build/original/bitmaps', destination.parent / 'OriginalInterface', dirs_exist_ok=True)
