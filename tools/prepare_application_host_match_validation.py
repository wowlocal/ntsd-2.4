#!/usr/bin/env python3
"""Prepare a fresh SwiftPM validation task for the frozen host-driver candidate."""
import ctypes
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import time
import traceback
from prepare_application_host_candidate import pin, same

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'build/research/application-host-match-candidate-20260922'
TASK = Path('/Volumes/X5/ntsd-2.4-research/01a0c7b2-a956-7760-950e-ecf7dceaaa20/application-host-match-validation-20260922')
PLAN = ROOT/'docs/research/APPLICATION_HOST_MATCH_VALIDATION_PLAN.md'


def main():
    os.chdir(ROOT)
    volume = plistlib.loads(subprocess.check_output(['diskutil', 'info', '-plist', '/Volumes/X5']))
    assert volume['VolumeUUID'] == '3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and volume['FilesystemType'] == 'apfs'
    free = shutil.disk_usage(TASK.parent).free
    assert free > 81*2**30 and shutil.disk_usage(ROOT).free > 7*2**30
    assert not TASK.exists()
    publication = json.loads((BASE/'publication1.json').read_text())
    for key in ['plan', 'context', 'candidateManifest', 'patch', 'verification', 'archive']:
        same(Path(publication[key]['path']), publication[key])
    assert json.loads((BASE/'external-close1.json').read_text())['candidateFrozen']
    candidate = json.loads((BASE/'candidate1-inputs.json').read_text())
    assert len(candidate) == 1039
    root_manifest = ROOT/'build/research/first-damage-loading53-native-20260922/candidate1-inputs.json'
    baseline = json.loads(root_manifest.read_text())
    for item in candidate:
        same(BASE/'candidate1'/item['path'], item)
    for item in baseline:
        same(ROOT/item['path'], item)
    source_path = ROOT/'build/research/first-damage-catalog53-source-20260922/launch1.json'
    source = json.loads(source_path.read_text())
    for item in source['codePins']:
        same(ROOT/item['path'], item)
    TASK.mkdir()
    (ROOT/'build/research'/TASK.name).symlink_to(TASK, target_is_directory=True)
    started = time.monotonic()
    job = dict(schema='ntsd-host-match-validation-prepare-job-v1', status='running', pid=os.getpid(),
        identity=subprocess.check_output(['ps', '-p', str(os.getpid()), '-o', 'pid=,lstart=,command='], text=True).strip(),
        cwd=subprocess.check_output(['lsof', '-a', '-p', str(os.getpid()), '-d', 'cwd', '-Fn'], text=True).strip(),
        startedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat())
    job_path = TASK/'prepare1.job.json'
    job_path.write_text(json.dumps(job, indent=2)+'\n')
    try:
        clone = ctypes.CDLL(None, use_errno=True).clonefile
        clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
        clone.restype = ctypes.c_int
        for item in candidate:
            assert free-shutil.disk_usage(TASK).free < 22*2**30
            old, new = BASE/'candidate1'/item['path'], TASK/'candidate1'/item['path']
            new.parent.mkdir(parents=True, exist_ok=True)
            if clone(os.fsencode(old), os.fsencode(new), 0):
                raise OSError(ctypes.get_errno(), str(new))
            same(new, item)
            assert old.stat().st_ino != new.stat().st_ino
        actual = {str(p.relative_to(TASK/'candidate1')) for p in (TASK/'candidate1').rglob('*') if p.is_file()}
        assert actual == {r['path'] for r in candidate}
        for name in ['tmp', 'cache', 'config', 'security']:
            (TASK/name).mkdir()
        for name in ['candidate1-inputs.json', 'selected-methods1.json']:
            shutil.copy2(BASE/name, TASK/name)
        shutil.copy2(PLAN, TASK/'plan1.md')
        shutil.copy2(Path(__file__), TASK/'prepare1.py')
        swift = subprocess.check_output(['xcrun', '--find', 'swift-build'], text=True).strip()
        environment = {k: os.environ[k] for k in ['HOME', 'USER', 'LOGNAME', 'LANG', 'LC_ALL'] if k in os.environ}
        environment.update(PATH='/usr/bin:/bin:/usr/sbin:/sbin', TMPDIR=str(TASK/'tmp'))
        version = subprocess.check_output(['xcrun', 'swift', '--version'], text=True, env=environment)
        sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
        protected_paths = [PLAN, Path(__file__), ROOT/'tools/prepare_application_host_candidate.py',
            ROOT/'tools/run_application_host_match_validation.py', BASE/'publication1.json', BASE/'external-close1.json',
            BASE/'candidate1-inputs.json', BASE/'selected-methods1.json', source_path, root_manifest,
            ROOT/'AGENTS_HISTORY_2026-09-12.md', ROOT/'docs/research/WORKFLOW.md',
            ROOT/'tools/run_application_host_match_tests.py', ROOT/'tools/verify_application_host_match_package.py',
            ROOT/'docs/research/APPLICATION_HOST_MATCH_CANDIDATE.md',
            ROOT/'docs/evidence/application-host-loading-regressions.json',
            ROOT/'docs/evidence/application-host-loading-correction3.json',
            ROOT/'docs/evidence/application-host-loading-completion.json']
        context = dict(schema='ntsd-host-match-validation-context-v1', UTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
            protected=[pin(f) for f in protected_paths], candidateSource=str((BASE/'candidate1').resolve()),
            rootManifest=str(root_manifest), sourceTask=str(source_path.parent.resolve()), sourceCodePins=source['codePins'],
            startFree=free, physicalAllowanceBytes=24*2**30, stopObservedDecrease=22*2**30,
            originalExternalReserve=40*2**30, originalInternalReserve=6*2**30,
            fullCloneVerified=True, cloneFiles=len(candidate), distinctRegularInodes=True,
            swiftVersion=version, sdk=sdk, environment=environment,
            gitStatus=subprocess.check_output(['git', 'status', '--porcelain=v1'], text=True))
        (TASK/'context1.json').write_text(json.dumps(context, indent=2)+'\n')
        command = [swift, '--package-path', str(TASK/'candidate1/native'), '--scratch-path', str(TASK/'swift'),
            '--cache-path', str(TASK/'cache'), '--config-path', str(TASK/'config'), '--security-path', str(TASK/'security'),
            '--manifest-cache', 'local', '--build-system', 'native', '--build-tests', '-c', 'release',
            '--jobs', '2', '--disable-index-store', '-Xswiftc', '-enable-testing']
        config = dict(schema='ntsd-host-match-validation-run-config-v1', phase='build1', buildPhase='build1', kind='build', command=command,
            cwd=str(TASK/'candidate1'), environment=environment, contextSHA256=pin(TASK/'context1.json')['sha256'],
            candidateManifestSHA256=pin(TASK/'candidate1-inputs.json')['sha256'],
            stopObservedDecrease=22*2**30, externalGuardBytes=40*2**30, internalGuardBytes=6*2**30,
            logicalLimitBytes=150*2**30, residentGuardBytes=12*2**30, timeoutSeconds=3600,
            pollSeconds=1, rssPollSeconds=2, logicalPollSeconds=15)
        (TASK/'build1-config.json').write_text(json.dumps(config, indent=2)+'\n')
        job.update(status='terminal', exitCode=0, files=len(candidate), swiftVersion=version,
                   buildConfig=pin(TASK/'build1-config.json'), observedFreeDecrease=free-shutil.disk_usage(TASK).free)
    except Exception as error:
        job.update(status='terminal', exitCode=1, error=repr(error), traceback=traceback.format_exc())
        raise
    finally:
        job.update(endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(), elapsedSeconds=time.monotonic()-started)
        job_path.write_text(json.dumps(job, indent=2)+'\n')
        print(json.dumps(job))


if __name__ == '__main__':
    main()
