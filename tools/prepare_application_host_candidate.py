#!/usr/bin/env python3
"""Clone the pinned Native inputs for the declared host-driver candidate only."""
import ctypes
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import time
import traceback

ROOT = Path(__file__).resolve().parents[1]
TASK = Path('/Volumes/X5/ntsd-2.4-research/01a0c7b2-a956-7760-950e-ecf7dceaaa20/application-host-transaction-candidate-20260922')
BASE = ROOT/'build/research/first-damage-loading53-native-20260922'
PLAN = ROOT/'docs/research/APPLICATION_HOST_TRANSACTION_CANDIDATE_PLAN.md'


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def pin(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    s = path.stat()
    return dict(path=str(path), bytes=s.st_size, sha256=h.hexdigest(), mode=stat.S_IMODE(s.st_mode))


def same(path, expected):
    actual = pin(path)
    assert all(actual[k] == expected[k] for k in ('bytes', 'sha256', 'mode')), str(path)
    assert path.is_file() and not path.is_symlink(), str(path)


def save(name, value):
    (TASK/name).write_text(json.dumps(value, indent=2)+'\n')


def main():
    os.chdir(ROOT)
    info = plistlib.loads(subprocess.check_output(['diskutil', 'info', '-plist', '/Volumes/X5']))
    assert info['VolumeUUID'] == '3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548'
    start_free = shutil.disk_usage('/Volumes/X5').free
    assert start_free > (40+17+12)*2**30 and shutil.disk_usage(ROOT).free > 6*2**30
    assert not TASK.exists()
    inputs_path = BASE/'candidate1-inputs.json'
    inputs = json.loads(inputs_path.read_text())
    assert len(inputs) == 1034
    actual = {str(p.relative_to(ROOT)) for top in ('native/Sources', 'native/Tests')
              for p in (ROOT/top).rglob('*') if p.is_file()} | {'native/Package.swift'}
    assert actual == {r['path'] for r in inputs}
    for item in inputs:
        same(ROOT/item['path'], item)
        same(BASE/'candidate1'/item['path'], item)
    source_path = ROOT/'build/research/first-damage-catalog53-source-20260922/launch1.json'
    source = json.loads(source_path.read_text())
    for item in source['codePins']:
        same(ROOT/item['path'], item)
    TASK.mkdir()
    alias = ROOT/'build/research'/TASK.name
    assert not alias.exists() and not alias.is_symlink()
    alias.symlink_to(TASK, target_is_directory=True)
    identity = subprocess.check_output(['ps', '-p', str(os.getpid()), '-o', 'pid=,lstart=,command='], text=True).strip()
    cwd = subprocess.check_output(['lsof', '-a', '-p', str(os.getpid()), '-d', 'cwd', '-Fn'], text=True).strip()
    job = dict(schema='ntsd-host-candidate-preparation-job-v1', pid=os.getpid(), identity=identity,
               cwd=cwd, startedUTC=now(), status='running', command=['python3', str(Path(__file__).relative_to(ROOT))])
    save('prepare1.job.json', job)
    started = time.monotonic()
    try:
        save('context1.json', dict(schema='ntsd-host-candidate-context-v1', UTC=now(),
             head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
             plan=pin(PLAN), producer=pin(Path(__file__)), nativeManifest=pin(inputs_path),
             sourceManifest=pin(source_path), sourceCodePins=source['codePins'],
             sourceRoot=str(BASE/'candidate1'), baselineFiles=1034,
             initialExternalFree=start_free, allowance=256*2**20, stopThreshold=224*2**20,
             originalExternalReserve=40*2**30, originalInternalReserve=6*2**30,
             gitStatus=subprocess.check_output(['git', 'status', '--porcelain=v1'], text=True)))
        shutil.copy2(PLAN, TASK/'plan1.md')
        shutil.copy2(Path(__file__), TASK/'prepare1.py')
        shutil.copy2(inputs_path, TASK/'baseline-inputs1.json')
        clone = ctypes.CDLL(None, use_errno=True).clonefile
        clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
        clone.restype = ctypes.c_int
        target = TASK/'candidate1'
        target.mkdir()
        for item in inputs:
            assert start_free-shutil.disk_usage('/Volumes/X5').free < 224*2**20
            original, destination = BASE/'candidate1'/item['path'], target/item['path']
            destination.parent.mkdir(parents=True, exist_ok=True)
            result = clone(os.fsencode(original), os.fsencode(destination), 0)
            if result:
                raise OSError(ctypes.get_errno(), str(destination))
            same(destination, item)
            assert original.stat().st_ino != destination.stat().st_ino
        actual = {str(p.relative_to(target)) for p in target.rglob('*') if p.is_file()}
        assert actual == {r['path'] for r in inputs}
        (TASK/'tmp').mkdir()
        save('clone1.json', dict(UTC=now(), files=len(inputs), bytes=sum(r['bytes'] for r in inputs),
             bodyModeMembershipVerified=True, distinctRegularInodes=True, noBuildCaches=True,
             observedFreeDecrease=start_free-shutil.disk_usage('/Volumes/X5').free))
        job.update(status='terminal', exitCode=0)
    except Exception as error:
        job.update(status='terminal', exitCode=1, error=repr(error), traceback=traceback.format_exc())
        raise
    finally:
        job.update(endedUTC=now(), elapsedSeconds=time.monotonic()-started)
        save('prepare1.job.json', job)
        print(json.dumps(job))


if __name__ == '__main__':
    main()
