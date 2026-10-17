#!/usr/bin/env python3
"""Static 2.4 tree / later ZIP inventory. Does not execute either distribution.

Outer ZIP absence is deliberately not called removal: built-in later-version
content can be bundled in the executable. Registry identity is not character
identity. DAT summaries are lexical inventories, not loader compatibility.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
from zipfile import ZipFile

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, POINTER, ROOT, decode_dat, parse_object
from inspect_original import PE


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def normalized(path: str) -> str:
    return path.replace('\\', '/').lower()


def registry(raw: bytes) -> list[dict]:
    result, section = [], None
    for line_number, original in enumerate(raw.decode('latin-1').splitlines(), 1):
        line = original.split('#', 1)[0].strip()
        if line in ('<object>', '<background>'):
            section = line[1:-1]
        elif line in ('<object_end>', '<background_end>'):
            section = None
        match = re.search(r'\bid:\s*(-?\d+)\s+(?:type:\s*(-?\d+)\s+)?file:\s*(\S+)', line)
        if section and match:
            result.append(dict(section=section, id=int(match[1]),
                               type=int(match[2]) if match[2] is not None else None,
                               path=match[3].replace('\\', '/'), line=line_number,
                               raw=original))
    return result


def registry_summary(rows: list[dict], visible: dict) -> dict:
    return dict(entries=len(rows), objects=sum(r['section'] == 'object' for r in rows),
                objectTypes=dict(Counter(str(r['type']) for r in rows if r['section'] == 'object')),
                backgrounds=sum(r['section'] == 'background' for r in rows),
                visibleReferences=sum(normalized(r['path']) in visible for r in rows),
                notVisibleReferences=[r for r in rows if normalized(r['path']) not in visible])


def object_summary(raw: bytes) -> dict:
    if raw.startswith(POINTER):
        return dict(status='missing-lfs-content')
    try:
        text = decode_dat(raw)
        obj = parse_object(text)
    except ValueError as error:
        return dict(status='unsupported', error=str(error))
    occurrences = obj['frameOccurrences']
    fields, blocks, states, kinds, effects = (Counter() for _ in range(5))
    for occurrence in occurrences:
        frame = occurrence['frame']
        fields.update(frame['fields'].keys())
        if 'state' in frame['fields']:
            states.update([frame['fields']['state']])
        for group, items in frame['blocks'].items():
            blocks[group] += len(items)
            for item in items:
                fields.update(f'{group}.{key}' for key in item)
                if group == 'itr':
                    kinds.update([item.get('kind', '<omitted>')])
                    effects.update([item.get('effect', '<omitted>')])
    numbers = [f['number'] for f in occurrences]
    return dict(status='decoded-object-lexical-inventory', decodedSHA256=sha(text.encode('latin-1')),
                name=obj['header'].get('name'), frameOccurrences=len(occurrences),
                distinctFrameNumbers=len(set(numbers)), minFrame=min(numbers), maxFrame=max(numbers),
                occurrencesOutside0to399=sum(n < 0 or n >= 400 for n in numbers),
                duplicateDefinitions=len(obj['duplicateFrames']), states=dict(states),
                itrKinds=dict(kinds), itrEffects=dict(effects), fields=dict(fields), blocks=dict(blocks))


def inspect_exe(raw: bytes) -> dict:
    try:
        pe = PE(raw)
    except (ValueError, IndexError, UnicodeError) as error:
        return dict(status='unsupported', error=str(error))
    result = dict(status='PE32-headers-read', machine=hex(pe.machine), imageBase=hex(pe.base),
                  entryVA=hex(pe.entry), sections=pe.sections)
    for name, reader in [('imports', pe.imports), ('resources', pe.resources)]:
        try:
            result[name] = reader()
        except (ValueError, IndexError, UnicodeError) as error:
            result[name + 'Error'] = f'{type(error).__name__}: {error}'
    result['dllNameStringsOnly'] = sorted(set(m.group().decode('ascii') for m in
        re.finditer(rb'[A-Za-z0-9_.-]{2,60}\.dll\b', raw, re.I)))
    result['dllNameStringsMeaning'] = 'Strings only; not a recovered import table or observed loading.'
    return result


def git(*args: str) -> str:
    return subprocess.check_output(['git', *args], cwd=ROOT).decode().strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, default=DEFAULT_SOURCE)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--prefix', default='NTSD2.8.3.3/')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Output exists; retain earlier runs and choose a new run ID')
    base = args.baseline.resolve()
    if sha((base / 'NTSD 2.4.exe').read_bytes()) != EXE_SHA256:
        raise ValueError('2.4 EXE does not match pinned baseline')
    baseline, later, base_paths, later_paths = {}, {}, {}, {}
    for path in sorted(base.rglob('*')):
        if not path.is_file():
            continue
        if path.is_symlink():
            raise ValueError(f'Unexpected symlink: {path}')
        relative = path.relative_to(base).as_posix()
        key = normalized(relative)
        if key in baseline:
            raise ValueError(f'Case-colliding baseline paths: {relative}')
        raw = path.read_bytes()
        baseline[key] = dict(path=relative, size=len(raw), sha256=sha(raw),
                             contentStatus='lfs-pointer' if raw.startswith(POINTER) else 'file-bytes')
        base_paths[key] = path
    with ZipFile(args.archive) as archive:
        members = [i for i in archive.infolist() if not i.is_dir()]
        for info in members:
            if not info.filename.startswith(args.prefix):
                raise ValueError(f'Member outside declared root: {info.filename}')
            relative = info.filename[len(args.prefix):]
            if '..' in PurePosixPath(relative).parts or PurePosixPath(relative).is_absolute():
                raise ValueError(f'Unsafe member: {relative}')
            key = normalized(relative)
            if key in later:
                raise ValueError(f'Case-colliding ZIP paths: {relative}')
            # ZipFile.read verifies CRC for each complete member. No extraction.
            raw = archive.read(info)
            later[key] = dict(path=relative, size=len(raw), compressedSize=info.compress_size,
                              sha256=sha(raw), crc32=f'{info.CRC:08x}')
            later_paths[key] = info.filename
        old_rows = registry(base_paths['data/data.txt'].read_bytes())
        new_rows = registry(archive.read(later_paths['data/data.txt']))
        old_objects, new_objects = {}, {}
        for rows, paths, dest, read in [
            (old_rows, base_paths, old_objects, lambda path: path.read_bytes()),
            (new_rows, later_paths, new_objects, archive.read),
        ]:
            for row in rows:
                key = normalized(row['path'])
                if row['section'] == 'object' and key in paths and key not in dest:
                    dest[key] = object_summary(read(paths[key]))
        by_old, by_new = defaultdict(list), defaultdict(list)
        for row in old_rows:
            by_old[(row['section'], row['id'])].append(row)
        for row in new_rows:
            by_new[(row['section'], row['id'])].append(row)
        common_ids = sorted(by_old.keys() & by_new.keys())
        id_correspondence = [dict(section=k[0], id=k[1], baseline=by_old[k], later=by_new[k])
                             for k in common_ids]
        docs = {}
        for key, member in later_paths.items():
            if key.startswith('instructions/special features for modding/') and key.endswith('.txt') or key == '2.8 full changelog.txt':
                raw = archive.read(member)
                text = raw.decode('utf-8-sig', errors='replace')
                docs[key] = dict(sha256=sha(raw), lines=len(text.splitlines()),
                                 decodingReplacementCount=text.count('\ufffd'))
        common = baseline.keys() & later.keys()
        same = sorted(k for k in common if baseline[k]['sha256'] == later[k]['sha256'])
        changed = sorted(common - set(same))
        dirty = {}
        status = subprocess.check_output(['git', 'status', '--porcelain=v1', '-z'], cwd=ROOT).decode()
        # Record file pins for actual pending inputs without including their contents.
        for record in status.split('\0'):
            if len(record) > 3:
                path = ROOT / record[3:]
                if path.is_file():
                    dirty[record[3:]] = sha(path.read_bytes())
        result = dict(schemaVersion=1, generatedUTC=datetime.now(timezone.utc).isoformat(),
            scope='Static outer-distribution/registry/visible-DAT comparison; no original execution.',
            revision=git('rev-parse', 'HEAD'), branch=git('branch', '--show-current'),
            dirtyFileSHA256=dirty, toolSHA256=sha(Path(__file__).read_bytes()),
            dependencySHA256={n: sha((ROOT / 'tools' / n).read_bytes()) for n in ['import_ntsd.py', 'inspect_original.py']},
            baselineRoot=str(base), archive=str(args.archive.resolve()), archiveSHA256=sha(args.archive.read_bytes()),
            summary=dict(baselineFiles=len(baseline), baselineBytes=sum(f['size'] for f in baseline.values()),
                baselineLFSPointers=[k for k, v in baseline.items() if v['contentStatus'] == 'lfs-pointer'],
                zipFiles=len(later), zipUncompressedBytes=sum(f['size'] for f in later.values()),
                zipCompressedBytes=sum(f['compressedSize'] for f in later.values()),
                equalSamePath=len(same), changedSamePath=len(changed),
                baselinePathsNotVisibleInZip=len(baseline.keys() - later.keys()),
                zipPathsNotInBaseline=len(later.keys() - baseline.keys())),
            fileDiff=dict(equalSamePath=same, changedSamePath=changed,
                baselinePathsNotVisibleInZip=sorted(baseline.keys() - later.keys()),
                zipPathsNotInBaseline=sorted(later.keys() - baseline.keys()),
                warning='Not visible in outer ZIP does not mean removed. Executable-contained assets are not inventoried.'),
            baselineFiles=baseline, laterFiles=later,
            registries=dict(baseline=dict(summary=registry_summary(old_rows, baseline), entries=old_rows),
                later=dict(summary=registry_summary(new_rows, later), entries=new_rows),
                idCorrespondence=id_correspondence,
                warning='IDs/paths may be reassigned; correspondence is not equivalence of characters or behaviors.'),
            visibleObjectInventories=dict(baseline=old_objects, later=new_objects,
                warning='Occurrence counters retain duplicates. Only visible registered objects are read. Decoder is verified for 2.4, not 2.8.3.3.'),
            executables=dict(baseline=inspect_exe(base_paths['ntsd 2.4.exe'].read_bytes()),
                             later=inspect_exe(archive.read(later_paths['ntsd.exe']))),
            bundledDocumentation=docs,
            verification=dict(zipCRC='all regular members read successfully',
                filePartitions='disjoint normalized-path comparison sets',
                behavior='not executed; no behavioral equivalence claimed', independentReview='open'))
    assert len(same) + len(changed) + result['summary']['baselinePathsNotVisibleInZip'] == len(baseline)
    assert len(same) + len(changed) + result['summary']['zipPathsNotInBaseline'] == len(later)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=True) + '\n')
    print(json.dumps(dict(summary=result['summary'],
        registries={k: result['registries'][k]['summary'] | {'notVisibleReferences': len(result['registries'][k]['summary']['notVisibleReferences'])} for k in ['baseline', 'later']},
        output=str(args.output), outputSHA256=sha(args.output.read_bytes())), indent=2))


if __name__ == '__main__':
    main()
