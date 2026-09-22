#!/usr/bin/env python3
"""Verify the syntax-only loading candidate, patch and changed-file archive."""
import datetime
from decimal import Decimal
import difflib
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time
import traceback
from prepare_application_host_candidate import pin, same

ROOT = Path(__file__).resolve().parents[1]


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def read(p):
    return json.loads(p.read_bytes())


def write(p, data):
    assert not p.exists(), str(p)
    p.write_text(json.dumps(data, indent=2)+'\n')


def absent(pid):
    return not subprocess.run(['ps', '-p', str(pid), '-o', 'pid='], capture_output=True, text=True).stdout.strip()


def main(task):
    assert task.name == 'application-host-loading-candidate-20260922'
    assert not (task/'external-close1.json').exists()
    context = read(task/'context1.json')
    assert context['initialExternalFree']-shutil.disk_usage(task).free < context['stopThreshold']
    job = dict(schema='ntsd-host-loading-finalize-v1', status='running', pid=os.getpid(), startedUTC=now(),
        identity=subprocess.check_output(['ps', '-p', str(os.getpid()), '-o', 'pid=,lstart=,command='], text=True).strip(),
        cwd=subprocess.check_output(['lsof', '-a', '-p', str(os.getpid()), '-d', 'cwd', '-Fn'], text=True).strip())
    job_path = task/'finalize1.job.json'
    write(job_path, job)
    began = time.monotonic()
    try:
        for name in ['prepare1.job.json', 'parse1.job.json']:
            prior = read(task/name)
            assert prior['status'] == 'terminal' and prior['exitCode'] == 0 and absent(prior['pid'])
        parse = read(task/'parse1-config.json')
        for row in parse['inputs']:
            actual = pin(Path(row['path']))
            assert all(actual[k] == row[k] for k in ('bytes', 'sha256'))
        assert (task/'parse1.log').read_bytes() == b''
        for row in context['protected']:
            same(Path(row['path']), row)
        for row in context['sourceCodePins']:
            same(ROOT/row['path'], row)
        roots = read(Path(context['rootManifest']))
        for row in roots:
            same(ROOT/row['path'], row)
        members = {str(p.relative_to(ROOT)) for top in ('native/Sources', 'native/Tests') for p in (ROOT/top).rglob('*') if p.is_file()} | {'native/Package.swift'}
        assert members == {r['path'] for r in roots}
        baseline = Path(context['baseline'])
        old = {r['path']:r for r in read(task/'baseline-inputs1.json')}
        for row in old.values():
            same(baseline/row['path'], row)
        candidate = task/'candidate1'
        current = [dict(pin(p), path=str(p.relative_to(candidate))) for p in sorted(candidate.rglob('*')) if p.is_file()]
        assert len(current) == 1037 and {r['path'] for r in old.values()}.issubset({r['path'] for r in current})
        changed = [r['path'] for r in current if r['path'] not in old or any(r[k] != old[r['path']][k] for k in ('sha256', 'bytes', 'mode'))]
        assert changed == read(task/'changed-paths1.json') and len(changed) == 6
        for row in current:
            assert not (candidate/row['path']).is_symlink()
            if '/Fixtures/' in row['path'] or '/Resources/' in row['path'] or row['path'] == 'native/Package.swift':
                assert row == old[row['path']]
        write(task/'candidate1-inputs.json', current)
        methods = read(task/'selected-methods1.json')['methods']
        assert len(methods) == len(set(methods)) == 42
        patch = ''
        for name in changed:
            previous = (baseline/name).read_text() if name in old else ''
            fresh = (candidate/name).read_text()
            patch += ''.join(difflib.unified_diff(previous.splitlines(True), fresh.splitlines(True),
                fromfile='a/'+name if name in old else '/dev/null', tofile='b/'+name))
        patch_path = task/'candidate1.patch'
        assert not patch_path.exists()
        patch_path.write_text(patch)
        roundtrip = task/'patch-roundtrip1'
        roundtrip.mkdir()
        for name in changed:
            if name in old:
                dest = roundtrip/name
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(baseline/name, dest)
        subprocess.run(['git', 'apply', '--check', str(patch_path)], cwd=roundtrip, check=True)
        subprocess.run(['git', 'apply', str(patch_path)], cwd=roundtrip, check=True)
        for name in changed:
            assert (roundtrip/name).read_bytes() == (candidate/name).read_bytes()
        root_patch = ROOT/'docs/evidence/application-host-loading-candidate.patch'
        assert not root_patch.exists()
        root_patch.write_bytes(patch_path.read_bytes())
        # Prove the original final-state comparison body moved unchanged, and
        # all three old cycle method bodies still have their exact source text.
        old_cycle = (baseline/'native/Tests/NTSDCoreTests/OriginalApplicationLoadedCycleTests.swift').read_text()
        new_cycle = (candidate/'native/Tests/NTSDCoreTests/OriginalApplicationLoadedCycleTests.swift').read_text()
        start = old_cycle.index('        let current = try XCTUnwrap(app.session),owners = try XCTUnwrap(current.loadedOwners)')
        body = old_cycle[start:old_cycle.index('        } catch {', start)]
        assert body in new_cycle
        marker = '    func testActualBootstrapCyclesKeepCachedOwnersAndReachHeldSelectionBoundary()'
        assert old_cycle[old_cycle.index(marker):] == new_cycle[new_cycle.index(marker):]
        write(task/'author-review1.json', dict(UTC=now(), independent=False,
            coreScope='Host/ticket/Bootstrap packet boundary only; existing game loading/menu/timer handlers unchanged',
            oldCycleMethodsByteIdentical=True, movedFinalComparisonBodyByteIdentical=True,
            newMethodsWritten=4, totalMethodsSelected=42, runtimeResultsUnknown=True,
            reviewGap='No independent contract reviewer; syntax does not establish types or runtime behavior',
            helperDiscovery='Earlier candidate has no finalize1.py; sed read returned No such file or directory. Its prior inline procedure was not rerun; this helper reuses pin/patch/tar procedures.'))
        source = Path(context['sourceTask'])
        source_job = read(source/'capture1/source.job.json')
        identity = subprocess.check_output(['ps', '-p', str(source_job['pid']), '-o', 'pid=,lstart=,command='], text=True).strip()
        cwd = subprocess.check_output(['lsof', '-a', '-p', str(source_job['pid']), '-d', 'cwd', '-Fn'], text=True).strip()
        assert source_job['status'] == 'running' and identity.split() == source_job['processIdentity'].split() and cwd == source_job['cwdObservation']
        with (source/'capture1/source.stdout.log').open('rb') as stream:
            stream.seek(0, 2); size = stream.tell(); stream.seek(max(0, size-1500)); last = stream.read().decode().splitlines()[-1]
        write(task/'source-live1.json', dict(UTC=now(), identity=identity, cwd=cwd, jobStatus=source_job['status'], lastLog=last, codePinsVerified=55))
        shutil.copy2(Path(__file__), task/'finalize1.py')
        write(task/'verification1.json', dict(UTC=now(), rootFiles=1034, baselineFiles=1036, candidateFiles=1037,
            changedFiles=changed, fixtures=385, runtimeResources=102, sourceCodePins=55,
            fullBodiesModesMembershipVerified=True, patchRoundTrip=True, parsedFiles=6, testsRun=0,
            selectedMethods=42, independentReview=False))
        archive_files = {p.name:p for p in task.iterdir() if p.is_file() and p.name != 'finalize1.job.json'}
        archive_files.update({'candidate1/'+name:candidate/name for name in changed})
        archive = task/'candidate-metadata1.tar'
        with tarfile.open(archive, 'w', format=tarfile.PAX_FORMAT) as tar:
            for name, path in sorted(archive_files.items()):
                info = tar.gettarinfo(str(path), arcname=name)
                ns = path.stat().st_mtime_ns
                info.pax_headers['mtime'] = f'{ns//10**9}.{ns%10**9:09d}'
                with path.open('rb') as stream:
                    tar.addfile(info, stream)
        with tarfile.open(archive) as tar:
            assert set(tar.getnames()) == set(archive_files)
            for member in tar:
                path = archive_files[member.name]
                assert member.isfile() and tar.extractfile(member).read() == path.read_bytes()
                assert member.mode == (path.stat().st_mode & 0o7777)
                assert int(Decimal(member.pax_headers['mtime'])*10**9) == path.stat().st_mtime_ns
        publication = dict(schema='ntsd-host-loading-candidate-v1', UTC=now(), status='implemented; six-file syntax parse passed; not compiled or tested',
            baseHead=context['head'], task=str(task), context=pin(task/'context1.json'), plan=pin(task/'plan1.md'),
            candidateManifest=pin(task/'candidate1-inputs.json'), changedFiles=changed, candidateFiles=1037,
            patch=pin(patch_path), selectedMethods=pin(task/'selected-methods1.json'), verification=pin(task/'verification1.json'),
            parseJob=pin(task/'parse1.job.json'), archive=dict(pin(archive), members=len(archive_files), fullBodiesModesMtimesMembershipVerified=True),
            independentReview=False, compiled=False, testsRun=0, rootPromoted=False, actualDevices=False, fullGame=False)
        write(task/'publication1.json', publication)
        (ROOT/'docs/evidence/application-host-loading-candidate.json').write_bytes((task/'publication1.json').read_bytes())
        free, internal = shutil.disk_usage(task).free, shutil.disk_usage(ROOT).free
        assert context['initialExternalFree']-free < context['allowance'] and free > 40*2**30 and internal > 6*2**30
        close = dict(schema='ntsd-host-loading-candidate-close-v1', UTC=now(), candidateFrozen=True, taskFrozen=True,
            observedFreeDecrease=context['initialExternalFree']-free, allowance=context['allowance'], includesConcurrentSourceGrowth=True,
            externalFree=free, internalFree=internal, originalExternalReserve=40*2**30, originalInternalReserve=6*2**30,
            publication=pin(task/'publication1.json'), archive=pin(archive))
        write(task/'external-close1.json', close)
        (ROOT/'docs/evidence/application-host-loading-candidate-close.json').write_bytes((task/'external-close1.json').read_bytes())
        job.update(status='terminal', exitCode=0)
        print(json.dumps(dict(candidateFiles=1037, changedFiles=len(changed), archiveMembers=len(archive_files), observedFreeDecrease=close['observedFreeDecrease'])))
    except BaseException as error:
        job.update(status='terminal', exitCode=1, error=repr(error), traceback=traceback.format_exc())
        raise
    finally:
        job.update(endedUTC=now(), elapsedSeconds=time.monotonic()-began)
        job_path.write_text(json.dumps(job, indent=2)+'\n')
        print(json.dumps(job))


if __name__ == '__main__':
    main(Path(sys.argv[1]).resolve())
