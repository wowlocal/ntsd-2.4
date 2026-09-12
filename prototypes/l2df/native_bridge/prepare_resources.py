#!/usr/bin/env python3
"""Export native game inputs from the pinned distribution, without executing it.

Build tooling only: copy original data, extract PE bitmap resources and the
file-backed globals prefix. Preserve PE zero-fill provenance in metadata. This
does not recover runtime DLL patches or prove a loaded session/gameplay match.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys

from build import MAIN, REVISION, ROOT, now, run_owned, sha, storage_check, write_json

BASELINE = MAIN / 'downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a'
EXE_SHA = '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
DATA_SUFFIXES = {'.bmp', '.dat', '.wav', '.wma', '.txt', '.lfr'}


def file_pin(path):
    return {'path': str(path), 'bytes': path.stat().st_size, 'sha256': sha(path)}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def inspect_pe(raw):
    # Existing static parser; no EXE/DLL execution, emulation or capture imports.
    sys.path.insert(0, str(MAIN / 'tools'))
    from inspect_original import PE, dib_to_bmp
    pe = PE(raw)
    section, = [s for s in pe.sections if s['name'] == '.data']
    assert pe.base == 0x400000
    assert section == {'name': '.data', 'rva': 0x4d000, 'virtualSize': 0xc724,
                       'fileSize': 0x2000, 'fileOffset': 0x4d000}
    return pe, section, dib_to_bmp


def worker(study):
    manifest = json.loads((study / 'inputs.json').read_text())
    for pin in manifest['tools']:
        assert sha(Path(pin['path'])) == pin['sha256'], pin['path']
        assert sha(Path(pin['copy'])) == pin['sha256'], pin['copy']
    actual = {p.relative_to(BASELINE).as_posix() for p in BASELINE.rglob('*') if p.is_file()}
    assert actual == {p['relative'] for p in manifest['sourceFiles']}
    raw = (BASELINE / 'NTSD 2.4.exe').read_bytes()
    assert digest(raw) == EXE_SHA
    pe, section, dib_to_bmp = inspect_pe(raw)
    output = study / 'resources'
    output.mkdir(exist_ok=False)
    copied = []
    for pin in manifest['sourceFiles']:
        source = BASELINE / pin['relative']
        assert not source.is_symlink()
        data = source.read_bytes()
        assert len(data) == pin['bytes'] and digest(data) == pin['sha256'], source
        if source.suffix.lower() not in DATA_SUFFIXES:
            assert source.name in ('NTSD 2.4.exe', 'lib.dll'), source
            continue
        relative = 'original/' + pin['relative']
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        copied.append({'path': relative, 'source': pin['relative'],
                       'bytes': len(data), 'sha256': digest(data)})
    # No byte from the EXE's code sections enters the runtime input tree.
    globals_data = raw[section['fileOffset']:section['fileOffset'] + section['fileSize']]
    (output / 'static').mkdir()
    (output / 'static/globals-data.bin').write_bytes(globals_data)
    (output / 'embedded').mkdir()
    embedded = []
    for index, resource in enumerate(r for r in pe.resources() if r['path'][0] == 2):
        _, key, language = resource['path']
        dib = raw[resource['fileOffset']:resource['fileOffset'] + resource['size']]
        bmp = dib_to_bmp(dib)
        width, height = struct.unpack_from('<ii', dib, 4)
        dib_path = f'embedded/{index:03d}.dib'
        bmp_path = f'embedded/{index:03d}.bmp'
        (output / dib_path).write_bytes(dib)
        (output / bmp_path).write_bytes(bmp)
        embedded.append({'key': key, 'language': language, 'dibPath': dib_path, 'bmpPath': bmp_path,
                         'width': width, 'height': height, 'fileOffset': resource['fileOffset'],
                         'dibBytes': len(dib), 'dibSHA256': digest(dib),
                         'bmpBytes': len(bmp), 'bmpSHA256': digest(bmp)})
    assert len(embedded) == 64
    assert len({(str(e['key']).casefold(), e['language']) for e in embedded}) == len(embedded)
    assert len({p['path'].casefold() for p in copied}) == len(copied)
    result = {'schemaVersion': 1, 'originalEXESHA256': EXE_SHA,
              'scope': 'Original file resources and pristine PE initialization data only; not DLL-enabled startup',
              'original': copied, 'embedded': embedded,
              'globals': {'base': 0x44d000, 'count': 0xb440, 'dataPath': 'static/globals-data.bin',
                          'fileBytes': len(globals_data), 'sha256': digest(globals_data),
                          'zeroFillStart': 0x44f000, 'zeroFillEnd': 0x459724,
                          'section': section},
              'runtimeContainsOriginalExecutable': False}
    write_json(output / 'manifest.json', result)
    print(json.dumps({'resourceRoot': str(output), 'originalFiles': len(copied),
                      'originalBytes': sum(p['bytes'] for p in copied), 'embeddedBitmaps': len(embedded)}))


def verify(study):
    inputs = json.loads((study / 'inputs.json').read_text())
    output = study / 'resources'
    result = json.loads((output / 'manifest.json').read_text())
    assert result['schemaVersion'] == 1 and result['originalEXESHA256'] == EXE_SHA
    assert result['runtimeContainsOriginalExecutable'] is False
    source_paths = list(BASELINE.rglob('*'))
    assert not any(path.is_symlink() for path in source_paths)
    actual_sources = {path.relative_to(BASELINE).as_posix() for path in source_paths if path.is_file()}
    assert actual_sources == {pin['relative'] for pin in inputs['sourceFiles']}
    expected = {'manifest.json', 'static/globals-data.bin'}
    for pin in inputs['sourceFiles']:
        source = BASELINE / pin['relative']
        assert source.stat().st_size == pin['bytes'] and sha(source) == pin['sha256'], source
    for pin in inputs['tools']:
        for key in ('path', 'copy'):
            assert sha(Path(pin[key])) == pin['sha256'], pin[key]
    expected_originals = [
        {'path': 'original/' + pin['relative'], 'source': pin['relative'],
         'bytes': pin['bytes'], 'sha256': pin['sha256']}
        for pin in inputs['sourceFiles'] if Path(pin['relative']).suffix.lower() in DATA_SUFFIXES]
    assert result['original'] == expected_originals
    for pin in result['original']:
        source = BASELINE / pin['source']; target = output / pin['path']
        assert source.read_bytes() == target.read_bytes()
        assert target.stat().st_size == pin['bytes'] and sha(target) == pin['sha256']
        expected.add(pin['path'])
    raw = (BASELINE / 'NTSD 2.4.exe').read_bytes()
    pe, section, dib_to_bmp = inspect_pe(raw)
    assert result['globals'] == {
        'base': pe.base + section['rva'], 'count': 0xb440,
        'dataPath': 'static/globals-data.bin', 'fileBytes': section['fileSize'],
        'sha256': digest(raw[section['fileOffset']:section['fileOffset'] + section['fileSize']]),
        'zeroFillStart': pe.base + section['rva'] + section['fileSize'],
        'zeroFillEnd': pe.base + section['rva'] + section['virtualSize'], 'section': section}
    source_bitmaps = [r for r in pe.resources() if r['path'][0] == 2]
    assert len(result['embedded']) == len(source_bitmaps) == 64
    for item, source in zip(result['embedded'], source_bitmaps):
        assert source['path'] == [2, item['key'], item['language']]
        dib = raw[source['fileOffset']:source['fileOffset'] + source['size']]
        assert item['fileOffset'] == source['fileOffset'] and item['dibBytes'] == len(dib)
        assert (item['width'], item['height']) == struct.unpack_from('<ii', dib, 4)
        assert item['bmpBytes'] == 14 + len(dib)
        assert (output / item['dibPath']).read_bytes() == dib
        assert (output / item['bmpPath']).read_bytes() == dib_to_bmp(dib)
        assert sha(output / item['dibPath']) == item['dibSHA256']
        assert sha(output / item['bmpPath']) == item['bmpSHA256']
        expected.update((item['dibPath'], item['bmpPath']))
    assert (output / 'static/globals-data.bin').read_bytes() == raw[0x4d000:0x4f000]
    actual = {p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file()}
    assert actual == expected
    assert not any(p.is_symlink() for p in output.rglob('*'))
    assert not any(Path(p).suffix.lower() in ('.exe', '.dll') for p in actual)
    return {'pass': True, 'filesVerified': len(expected), 'originalFiles': len(result['original']),
            'embeddedDIBs': len(source_bitmaps), 'embeddedBMPs': len(source_bitmaps),
            'sourceFilesVerified': len(inputs['sourceFiles']), 'toolsVerified': len(inputs['tools']),
            'manifestSHA256': sha(output / 'manifest.json'), 'originalExecution': False,
            'gameplayCompared': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--worker', action='store_true')
    args = parser.parse_args()
    assert args.label and Path(args.label).name == args.label and args.label not in ('.', '..')
    storage, volume = storage_check()
    study = storage / 'loaded-session-20260912' / args.label
    if args.worker:
        worker(study)
        return
    assert subprocess.check_output(['git', '-C', str(MAIN), 'rev-parse', 'HEAD'], text=True).strip() == REVISION
    study.mkdir(parents=True, exist_ok=False)
    sources = []
    for path in sorted(BASELINE.rglob('*')):
        assert not path.is_symlink(), path
        if path.is_file():
            sources.append({'relative': path.relative_to(BASELINE).as_posix(),
                            'bytes': path.stat().st_size, 'sha256': sha(path)})
    assert sha(BASELINE / 'NTSD 2.4.exe') == EXE_SHA
    tools = []
    snapshot = study / 'tool-inputs'; snapshot.mkdir()
    for path in [Path(__file__).resolve(), Path(__file__).with_name('build.py').resolve(),
                 MAIN / 'tools/inspect_original.py', MAIN / 'tools/import_ntsd.py']:
        target = snapshot / path.name; shutil.copy2(path, target)
        tools.append({**file_pin(path), 'copy': str(target)})
    write_json(study / 'inputs.json', {'createdAtUTC': now(), 'mainRevision': REVISION,
               'baseline': str(BASELINE), 'storage': volume, 'sourceFiles': sources, 'tools': tools})
    (study / 'plan.md').write_text(
        '# Native resource export, finite scope\n\n'
        'Game purpose: supply exact original resources and independently sourced pristine boot data '
        'to the owned native session, without an EXE/DLL in its runtime.\n'
        'Reference: the pinned original distribution and its EXE SHA ' + EXE_SHA + '.\n'
        'Operation: static PE parsing, byte copying, DIB-to-BMP file-header addition; '
        'no original execution, emulation, hooks or new gameplay capture.\n'
        'One export, at most120 seconds/2GiB output, X5 reserve6GiB. '
        'All declared original data files,64 embedded bitmaps and8192 file-backed globals bytes.\n'
        'Compare complete originals, DIBs/BMP derivatives, PE-data bytes, exact output set and pins. '
        'Preserve any failure and diagnose before a new label; never overwrite completed exports.\n'
        'PE BSS is provenance metadata; this does not establish DLL patches, CRT/startup, '
        'a loaded session, pixel equivalence or the full game.\n')
    job = run_owned([sys.executable, str(Path(__file__).resolve()), '--label', args.label, '--worker'],
                    ROOT, study / 'job', 120, env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'), size_root=study)
    if job['exitCode'] != 0 or job.get('terminationReason'):
        raise SystemExit('Export did not complete; inspect retained job before another run')
    verification = verify(study)
    write_json(study / 'verification.json', verification)
    print(json.dumps({'study': str(study), **verification}))


if __name__ == '__main__':
    main()
