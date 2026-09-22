#!/usr/bin/env python3
"""Verify and archive the terminal bounded host-driver validation task."""
import ctypes
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import time
import traceback
from archive_catalog53_storage import ROOT, checked, pin


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def read(path):
    return json.loads(path.read_bytes())


def write(path, value):
    assert not path.exists(), str(path)
    path.write_text(json.dumps(value, indent=2)+'\n')


def absent(pid):
    return not subprocess.run(['ps', '-p', str(pid), '-o', 'pid='], capture_output=True, text=True).stdout.strip()


def main(task):
    assert task.name == 'application-host-loading-validation-20260922'
    assert not (task/'external-close1.json').exists()
    context = read(task/'context1.json')
    assert context['startFree']-shutil.disk_usage(task).free < 22*2**30
    began = time.monotonic()
    job = dict(schema='ntsd-host-loading-validation-finalizer-v1', pid=os.getpid(), status='running', startedUTC=now(),
        identity=subprocess.check_output(['ps', '-p', str(os.getpid()), '-o', 'pid=,lstart=,command='], text=True).strip(),
        cwd=subprocess.check_output(['lsof', '-a', '-p', str(os.getpid()), '-d', 'cwd', '-Fn'], text=True).strip())
    jp = task/'finalize1.job.json'
    write(jp, job)
    try:
        queue = read(task/'tests1-queue.job.json')
        assert queue['status'] == 'terminal' and queue['exitCode'] == 1 and not queue.get('all42Passed', False) and absent(queue['pid'])
        selected = read(task/'selected-methods1.json')['methods']
        assert len(selected) == 42 and selected[:26] == [r['method'] for r in queue['completed']]
        assert len(queue['completed']) == 26 and [r['passed'] for r in queue['completed']] == [True]*25+[False]
        assert all(not (task/f'test-{i:02d}.job.json').exists() for i in range(27,43))
        tests = []
        for record in queue['completed']:
            child_path, log_path = task/(record['phase']+'.job.json'), task/(record['phase']+'.log')
            checked(child_path, record['job']); checked(log_path, record['log'])
            child = read(child_path)
            assert child['status'] == 'terminal' and child['exitCode'] == record['exitCode'] == (0 if record['passed'] else 1) and absent(child['pid'])
            assert not child['remainingProcessGroup'] and not child['remainingObservedProcesses']
            assert not child.get('guardReason') and not child.get('signals')
            text = log_path.read_text()
            done = re.findall(r"^Test Case '-\[NTSDCoreTests\.([^ ]+) ([^\]]+)\]' (passed|failed) \(([^)]*)\)\.$", text, re.M)
            assert len(done) == 1 and '/'.join(done[0][:2]) == record['method'] and done[0][2] == ('passed' if record['passed'] else 'failed')
            count = 0 if record['passed'] else 2
            assert text.count(f'Executed 1 test, with {count} failures (0 unexpected)') == 3
            assert f"Test Suite 'Selected tests' {done[0][2]}" in text
            assert all(absent(int(pid)) for pid in child['observedProcesses'])
            tests.append(dict(method=record['method'], pid=child['pid'], exitCode=child['exitCode'], passed=record['passed'],
                seconds=child['elapsedSeconds'], sampledTreeRSS=child['peakTreeRSS'],
                transientExitObservations=child.get('transientExitObservations', []),
                initialIdentityObservationGap=child.get('initialIdentityObservationGap')))
        builds = [read(task/(name+'.job.json')) for name in ('build1',)]
        assert [b['exitCode'] for b in builds] == [0]
        for b in builds:
            assert b['status'] == 'terminal' and absent(b['pid']) and not b['remainingProcessGroup'] and not b['remainingObservedProcesses']
            assert all(absent(int(pid)) for pid in b['observedProcesses'])
        for item in context['protected']:
            checked(Path(item['path']), item)
        for item in context['sourceCodePins']:
            checked(ROOT/item['path'], item)
        root_inputs = read(Path(context['rootManifest']))
        for item in root_inputs:
            checked(ROOT/item['path'], item)
        root_members = {str(f.relative_to(ROOT)) for t in ('native/Sources', 'native/Tests') for f in (ROOT/t).rglob('*') if f.is_file()} | {'native/Package.swift'}
        assert root_members == {r['path'] for r in root_inputs}
        candidate = read(task/'candidate1-inputs.json')
        for item in candidate:
            checked(task/'candidate1'/item['path'], item)
            checked(Path(context['candidateSource'])/item['path'], item)
        package = read(task/'package-check1.json')
        checked(Path(package['binary']['path']), package['binary'])
        for item in package['resourceFiles']:
            checked(Path(item['path']), item)
        for target in package['targets'].values():
            for item in target['freshOutputs']:
                checked(Path(item['path']), item)
        # One regular clone archive of exact candidate and successful products.
        archive = task/'artifact-archive1'
        assert not archive.exists()
        archive.mkdir()
        clone = ctypes.CDLL(None, use_errno=True).clonefile
        clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
        clone.restype = ctypes.c_int
        files, directories, links = [], [], []
        for top in ('candidate1', 'swift/arm64-apple-macosx/release'):
            source = task/top
            for f in [source, *sorted(source.rglob('*'))]:
                relative, destination = f.relative_to(task), archive/f.relative_to(task)
                if f.is_symlink():
                    target = os.readlink(f)
                    assert not Path(target).is_absolute() and (f.parent/target).resolve().is_relative_to(task)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    os.symlink(target, destination)
                    os.utime(destination, ns=(f.lstat().st_atime_ns, f.lstat().st_mtime_ns), follow_symlinks=False)
                    links.append(dict(path=str(relative), target=target))
                elif f.is_dir():
                    destination.mkdir(parents=True, exist_ok=True)
                    directories.append(f)
                else:
                    assert context['startFree']-shutil.disk_usage(task).free < 22*2**30
                    record = dict(path=str(relative), **pin(f))
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    if clone(os.fsencode(f), os.fsencode(destination), 0):
                        raise OSError(ctypes.get_errno(), str(destination))
                    checked(destination, record)
                    assert f.stat().st_ino != destination.stat().st_ino
                    files.append(record)
        for f in reversed(directories):
            shutil.copystat(f, archive/f.relative_to(task), follow_symlinks=False)
        for item in files:
            checked(archive/item['path'], item)
        actual = {str(f.relative_to(archive)) for f in archive.rglob('*') if f.is_file() and not f.is_symlink()}
        assert actual == {r['path'] for r in files}
        artifact_report = dict(schema='ntsd-host-loading-validation-artifact-archive-v1', UTC=now(), files=files,
            directories=len(directories), links=links, bytes=sum(r['bytes'] for r in files),
            fullBodyModeMtimeMembershipVerified=True, distinctRegularInodes=True)
        write(task/'artifact-archive1.json', artifact_report)
        write(task/'verification1.json', dict(UTC=now(), protectedPins=len(context['protected']), rootNativeFiles=1034,
            candidateFiles=1037, sourceCodePins=55, allPreserved=True, resourceFiles=487,
            all42Passed=False, passedMethods=25, failedMethods=1, unstartedMethods=selected[26:], tests=tests,
            totalTestProcessSeconds=sum(t['seconds'] for t in tests), sampledTestPeakRSS=max(t['sampledTreeRSS'] for t in tests),
            zeroRSSMeansNoSample=True, taskProcessAbsenceVerified=True, independentReview=False))
        source = Path(context['sourceTask'])
        source_job = read(source/'capture1/source.job.json')
        source_identity = subprocess.check_output(['ps', '-p', '59727', '-o', 'pid=,lstart=,command='], text=True).strip()
        source_cwd = subprocess.check_output(['lsof', '-a', '-p', '59727', '-d', 'cwd', '-Fn'], text=True).strip()
        assert source_identity.split() == source_job['processIdentity'].split() and source_cwd == source_job['cwdObservation']
        with (source/'capture1/source.stdout.log').open('rb') as stream:
            stream.seek(0, 2); size = stream.tell(); stream.seek(max(0, size-1500))
            tail = stream.read().decode().splitlines()[-1]
        write(task/'source-live1.json', dict(UTC=now(), identity=source_identity, cwd=source_cwd,
            jobStatus=source_job['status'], lastLog=tail, sourceCodePinsVerified=55))
        tools = ['prepare_application_host_loading_validation.py', 'run_application_host_loading_validation.py',
                 'verify_application_host_loading_package.py', 'run_application_host_loading_tests.py', Path(__file__).name]
        for name in tools:
            shutil.copy2(ROOT/'tools'/name, task/('frozen-'+name))
        metadata_files = [f for f in task.iterdir() if f.is_file() and f.name != 'finalize1.job.json']
        tar_path = task/'metadata1.tar'
        with tarfile.open(tar_path, 'w', format=tarfile.PAX_FORMAT) as tar:
            for f in sorted(metadata_files):
                tar.add(f, arcname=f.name, recursive=False)
        with tarfile.open(tar_path) as tar:
            members = tar.getmembers()
            assert len(members) == len(metadata_files) and {m.name for m in members} == {f.name for f in metadata_files}
            for member in members:
                f = task/member.name
                assert member.isfile() and member.mode == stat.S_IMODE(f.stat().st_mode) and member.mtime == f.stat().st_mtime
                assert tar.extractfile(member).read() == f.read_bytes()
        publication = dict(schema='ntsd-host-loading-validation-v1', UTC=now(), status='first-new-method-failed-25-passed-16-unstarted',
            baseHead=context['head'], task=str(task), context=dict(path=str(task/'context1.json'), **pin(task/'context1.json')),
            candidateManifest=dict(path=str(task/'candidate1-inputs.json'), **pin(task/'candidate1-inputs.json')),
            builds=[dict(pid=b['pid'], exitCode=b['exitCode'], seconds=b['elapsedSeconds'], sampledTreeRSS=b['peakTreeRSS']) for b in builds],
            compiledSourceCounts={k: v['originalSources'] for k, v in package['targets'].items()},
            binary=package['binary'], packageCheck=dict(path=str(task/'package-check1.json'), **pin(task/'package-check1.json')),
            tests=read(task/'verification1.json'), sourceObservation=dict(path=str(task/'source-live1.json'), **pin(task/'source-live1.json')),
            artifactArchive=dict(path=str(archive), files=len(files), directories=len(directories), bytes=artifact_report['bytes'], manifest=pin(task/'artifact-archive1.json')),
            metadataArchive=dict(path=str(tar_path), members=len(metadata_files), **pin(tar_path)),
            corrections=[], failureDiagnosis=dict(path=str(task/'failure-diagnosis1.json'), **pin(task/'failure-diagnosis1.json')),
            gates=dict(nativeComparison=False, packageBytes=True, archive=True, independentReview=False,
                       rootPromotion=False, actualWindowInputAudio=False, wholeCatalogSource=False, fullGame=False),
            limitations=['Short test processes can finish before any RSS sample; recorded0 is not known zero RSS.',
                         'Controlled platform replies do not establish actual host clock/event/reentrancy/raster/audio behavior.',
                         'Prepared clock packets still need an actual acquisition contract for live timing.',
                         'Later typed child outcomes and actual IO remain open; an injected fourth-input stop is not an outer return.'])
        write(task/'publication1.json', publication)
        (ROOT/'docs/evidence/application-host-loading-validation.json').write_bytes((task/'publication1.json').read_bytes())
        free, internal = shutil.disk_usage(task).free, shutil.disk_usage(ROOT).free
        assert context['startFree']-free < context['physicalAllowanceBytes'] and free > 40*2**30 and internal > 6*2**30
        closure = dict(schema='ntsd-host-loading-validation-close-v1', UTC=now(), largePhaseClosed=True,
            taskFrozen=True, originalExternalReserve=40*2**30, originalInternalReserve=6*2**30,
            initialExternalFree=context['startFree'], externalFree=free, internalFree=internal,
            observedFreeDecrease=context['startFree']-free, allowance=context['physicalAllowanceBytes'],
            includesConcurrentSourceGrowth=True, publication=pin(task/'publication1.json'), metadataArchive=pin(tar_path))
        write(task/'external-close1.json', closure)
        (ROOT/'docs/evidence/application-host-loading-validation-close.json').write_bytes((task/'external-close1.json').read_bytes())
        job.update(status='terminal', exitCode=0)
        print(json.dumps(dict(all42Passed=False, passed=25, failed=1, unstarted=16, testSeconds=publication['tests']['totalTestProcessSeconds'],
            archivedFiles=len(files), metadataMembers=len(metadata_files), observedFreeDecrease=closure['observedFreeDecrease'])))
    except BaseException as error:
        job.update(status='terminal', exitCode=1, error=repr(error), traceback=traceback.format_exc())
        raise
    finally:
        job.update(endedUTC=now(), elapsedSeconds=time.monotonic()-began)
        jp.write_text(json.dumps(job, indent=2)+'\n')
        print(json.dumps(job))


if __name__ == '__main__':
    main(Path(sys.argv[1]).resolve())
