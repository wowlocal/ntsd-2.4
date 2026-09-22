#!/usr/bin/env python3
"""Verify and archive the terminal bounded host-driver validation task."""
import ctypes
import datetime
from decimal import Decimal
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
    assert task.name == 'application-host-match-validation-20260922'
    assert not (task/'external-close1.json').exists()
    context = read(task/'context1.json')
    assert context['startFree']-shutil.disk_usage(task).free < 22*2**30
    began = time.monotonic()
    job = dict(schema='ntsd-host-match-validation-finalizer-v1', pid=os.getpid(), status='running', startedUTC=now(),
        identity=subprocess.check_output(['ps', '-p', str(os.getpid()), '-o', 'pid=,lstart=,command='], text=True).strip(),
        cwd=subprocess.check_output(['lsof', '-a', '-p', str(os.getpid()), '-d', 'cwd', '-Fn'], text=True).strip())
    jp = task/'finalize1.job.json'
    write(jp, job)
    try:
        preparation = read(task/'prepare1.job.json')
        assert preparation['status'] == 'terminal' and preparation['exitCode'] == 0 and absent(preparation['pid'])
        build = read(task/'build1.job.json')
        assert build['status'] == 'terminal' and build['exitCode'] == 1 and absent(build['pid'])
        assert not build['remainingProcessGroup'] and not build['remainingObservedProcesses']
        assert not build.get('signals') and not build.get('guardReason')
        assert all(absent(int(pid)) for pid in build['observedProcesses'])
        text = (task/'build1.log').read_text()
        assert 'compile command failed due to signal 6' in text
        assert "Querying VarDecl's type before type-checking parent stmt" in text
        selected = read(task/'selected-methods1.json')['methods']
        assert len(selected) == len(set(selected)) == 53
        assert not (task/'tests1-queue.job.json').exists() and not list(task.glob('test-*.job.json'))
        assert not (task/'package-check1.json').exists()
        release = task/'swift/arm64-apple-macosx/release'
        assert not (release/'NTSDNativePackageTests.xctest/Contents/MacOS/NTSDNativePackageTests').exists()
        for item in read(task/'runner-inputs1.json') + context['protected']:
            checked(Path(item['path']), item)
        for item in context['sourceCodePins']:
            checked(ROOT/item['path'], item)
        root_inputs = read(Path(context['rootManifest']))
        for item in root_inputs:checked(ROOT/item['path'], item)
        root_members = {str(f.relative_to(ROOT)) for t in ('native/Sources','native/Tests') for f in (ROOT/t).rglob('*') if f.is_file()}|{'native/Package.swift'}
        assert len(root_inputs) == 1034 and root_members == {r['path'] for r in root_inputs}
        candidate = read(task/'candidate1-inputs.json')
        for item in candidate:
            checked(task/'candidate1'/item['path'], item)
            checked(Path(context['candidateSource'])/item['path'], item)
        actual = {str(f.relative_to(task/'candidate1')) for t in ('native/Sources','native/Tests') for f in (task/'candidate1'/t).rglob('*') if f.is_file()}|{'native/Package.swift'}
        assert len(candidate) == 1039 and actual == {r['path'] for r in candidate}
        copied_resources = []
        for bundle,marker in [('NTSDNative_NTSDCoreTests.bundle','native/Tests/NTSDCoreTests/'),('NTSDNative_NTSDCore.bundle','native/Sources/NTSDCore/Resources/')]:
            expected = {r['path'][len(marker):]:r for r in candidate if r['path'].startswith(marker) and ('/Fixtures/' in r['path'] if 'Tests' in bundle else True)}
            assert len(expected) == (385 if 'Tests' in bundle else 102)
            folder = release/bundle
            for f in sorted(folder.rglob('*')):
                if f.is_file():
                    key = str(f.relative_to(folder));assert key in expected and not f.is_symlink()
                    checked(f,{k:expected[key][k] for k in ('bytes','sha256')});copied_resources.append(dict(path=str(f),**pin(f)))
        # Preserve exact candidate and partial compiler products; no binary or
        # complete package is inferred from these successfully copied files.
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
        implicit_parents={'swift','swift/arm64-apple-macosx'}
        expected_dirs={str(f.relative_to(task)) for f in directories}|implicit_parents
        assert {str(f.relative_to(archive)) for f in archive.rglob('*') if f.is_dir() and not f.is_symlink()}==expected_dirs
        for f in directories:
            dest=archive/f.relative_to(task)
            assert stat.S_IMODE(dest.stat().st_mode)==stat.S_IMODE(f.stat().st_mode) and dest.stat().st_mtime_ns==f.stat().st_mtime_ns
        artifact_report = dict(schema='ntsd-host-match-validation-artifact-archive-v1', UTC=now(), files=files,
            directories=len(directories), implicitParentDirectories=sorted(implicit_parents), totalDirectories=len(expected_dirs), links=links, bytes=sum(r['bytes'] for r in files),
            fullBodyModeMtimeMembershipVerified=True, distinctRegularInodes=True)
        write(task/'artifact-archive1.json', artifact_report)
        write(task/'verification1.json',dict(UTC=now(),protectedPins=len(context['protected']),rootNativeFiles=1034,
            candidateFiles=1039,sourceCodePins=55,allPreserved=True,copiedResources=copied_resources,
            all53Passed=False,passedMethods=0,failedTestMethods=0,unstartedMethods=selected,tests=[],
            buildFailure=True,compilerReportedSignal=6,buildExitCode=1,taskProcessAbsenceVerified=True,
            independentReview=False,nativeCompared=False,packageAccepted=False))
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
        tools = ['prepare_application_host_match_validation.py', 'run_application_host_match_validation.py',
                 'verify_application_host_match_package.py', 'run_application_host_match_tests.py', Path(__file__).name]
        for name in tools:
            shutil.copy2(ROOT/'tools'/name, task/('frozen-'+name))
        metadata_files = [f for f in task.iterdir() if f.is_file() and f.name != 'finalize1.job.json']
        tar_path = task/'metadata1.tar'
        with tarfile.open(tar_path, 'w', format=tarfile.PAX_FORMAT) as tar:
            for f in sorted(metadata_files):
                info=tar.gettarinfo(str(f),arcname=f.name); ns=f.stat().st_mtime_ns
                info.mtime=ns//10**9;info.pax_headers['mtime']=f'{ns//10**9}.{ns%10**9:09d}'
                with f.open('rb') as body:tar.addfile(info,body)
        with tarfile.open(tar_path) as tar:
            members = tar.getmembers()
            assert len(members) == len(metadata_files) and {m.name for m in members} == {f.name for f in metadata_files}
            for member in members:
                f = task/member.name
                assert member.isfile() and member.mode == stat.S_IMODE(f.stat().st_mode) and int(Decimal(member.pax_headers['mtime'])*10**9) == f.stat().st_mtime_ns
                assert tar.extractfile(member).read() == f.read_bytes()
        publication = dict(schema='ntsd-host-match-validation-v1',UTC=now(),status='compiler-failure-before-tests',
            baseHead=context['head'],task=str(task),context=dict(path=str(task/'context1.json'),**pin(task/'context1.json')),
            candidateManifest=dict(path=str(task/'candidate1-inputs.json'),**pin(task/'candidate1-inputs.json')),
            build=dict(pid=build['pid'],exitCode=build['exitCode'],seconds=build['elapsedSeconds'],sampledTreeRSS=build['peakTreeRSS'],
                job=dict(path=str(task/'build1.job.json'),**pin(task/'build1.job.json')),log=dict(path=str(task/'build1.log'),**pin(task/'build1.log'))),
            compilerReportedSignal=6,compiledSourceCounts=None,binary=None,packageCheck=None,
            verification=dict(path=str(task/'verification1.json'),**pin(task/'verification1.json')),
            passedMethods=0,unstartedMethods=selected,copiedResourceFiles=len(copied_resources),
            sourceObservation=dict(path=str(task/'source-live1.json'),**pin(task/'source-live1.json')),
            artifactArchive=dict(path=str(archive),files=len(files),sourceTraversalDirectories=len(directories),implicitParentDirectories=2,totalDirectories=len(expected_dirs),bytes=artifact_report['bytes'],manifest=pin(task/'artifact-archive1.json')),
            metadataArchive=dict(path=str(tar_path),members=len(metadata_files),**pin(tar_path)),
            failureDiagnosis=dict(path=str(task/'failure-diagnosis1.json'),**pin(task/'failure-diagnosis1.json')),
            gates=dict(nativeComparison=False,packageBytes=False,archive=True,independentReview=False,
                rootPromotion=False,actualWindowInputAudio=False,wholeCatalogSource=False,fullGame=False),
            limitations=['Compiler assertion does not establish Native runtime behavior; all53 methods unstarted.',
                'Copied resource verification is not a complete built package.',
                'Source capture remains independent and incomplete; no source or device execution in this task.'])
        write(task/'publication1.json',publication)
        (ROOT/'docs/evidence/application-host-match-validation.json').write_bytes((task/'publication1.json').read_bytes())
        free, internal = shutil.disk_usage(task).free, shutil.disk_usage(ROOT).free
        assert context['startFree']-free < context['physicalAllowanceBytes'] and free > 40*2**30 and internal > 6*2**30
        closure = dict(schema='ntsd-host-match-validation-close-v1', UTC=now(), largePhaseClosed=True,
            taskFrozen=True, originalExternalReserve=40*2**30, originalInternalReserve=6*2**30,
            initialExternalFree=context['startFree'], externalFree=free, internalFree=internal,
            observedFreeDecrease=context['startFree']-free, allowance=context['physicalAllowanceBytes'],
            includesConcurrentSourceGrowth=True, publication=pin(task/'publication1.json'), metadataArchive=pin(tar_path))
        write(task/'external-close1.json', closure)
        (ROOT/'docs/evidence/application-host-match-validation-close.json').write_bytes((task/'external-close1.json').read_bytes())
        job.update(status='terminal', exitCode=0)
        print(json.dumps(dict(buildFailed=True,testsRun=0,unstarted=53,archivedFiles=len(files),metadataMembers=len(metadata_files),observedFreeDecrease=closure['observedFreeDecrease'])))
    except BaseException as error:
        job.update(status='terminal', exitCode=1, error=repr(error), traceback=traceback.format_exc())
        raise
    finally:
        job.update(endedUTC=now(), elapsedSeconds=time.monotonic()-began)
        jp.write_text(json.dumps(job, indent=2)+'\n')
        print(json.dumps(job))


if __name__ == '__main__':
    main(Path(sys.argv[1]).resolve())
