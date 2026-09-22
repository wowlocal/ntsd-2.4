#!/usr/bin/env python3
"""Clone the validated host candidate for the bounded gameplay retention continuation."""
import ctypes
import datetime
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
BASE = (ROOT/'build/research/application-host-match-correction1-20260922').resolve()
TASK = Path('/Volumes/X5/ntsd-2.4-research/01a0c7b2-a956-7760-950e-ecf7dceaaa20/application-host-gameplay-candidate-20260922')
PLAN = ROOT/'docs/research/APPLICATION_HOST_GAMEPLAY_CANDIDATE_PLAN.md'


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def main():
    os.chdir(ROOT)
    volume = plistlib.loads(subprocess.check_output(['diskutil', 'info', '-plist', '/Volumes/X5']))
    assert volume['VolumeUUID'] == '3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and volume['FilesystemType'] == 'apfs'
    free = shutil.disk_usage(TASK.parent).free
    assert free > 61*2**30 and shutil.disk_usage(ROOT).free > 7*2**30
    assert not TASK.exists()
    inputs = json.loads((BASE/'candidate1-inputs.json').read_text())
    assert len(inputs) == 1039
    root_manifest = ROOT/'build/research/first-damage-loading53-native-20260922/candidate1-inputs.json'
    root_inputs = json.loads(root_manifest.read_text())
    for item in root_inputs:
        same(ROOT/item['path'], item)
    for item in inputs:
        same(BASE/'candidate1'/item['path'], item)
    source_manifest = ROOT/'build/research/first-damage-catalog53-source-20260922/launch1.json'
    source = json.loads(source_manifest.read_text())
    for item in source['codePins']:
        same(ROOT/item['path'], item)
    source_task = source_manifest.parent.resolve()
    source_job = json.loads((source_task/'capture1/source.job.json').read_text())
    identity = subprocess.check_output(['ps', '-p', str(source_job['pid']), '-o', 'pid=,lstart=,command='], text=True).strip()
    cwd = subprocess.check_output(['lsof', '-a', '-p', str(source_job['pid']), '-d', 'cwd', '-Fn'], text=True).strip()
    assert source_job['status'] == 'running' and identity.split() == source_job['processIdentity'].split() and cwd == source_job['cwdObservation']
    validation = ROOT/'docs/evidence/application-host-match-completion.json'
    assert json.loads(validation.read_text())['all53Passed']
    assert json.loads((BASE/'external-close1.json').read_text())['taskFrozen']
    TASK.mkdir()
    (ROOT/'build/research'/TASK.name).symlink_to(TASK, target_is_directory=True)
    began = time.monotonic()
    job = dict(schema='ntsd-host-gameplay-prepare-v1', pid=os.getpid(), status='running', startedUTC=now(),
        identity=subprocess.check_output(['ps', '-p', str(os.getpid()), '-o', 'pid=,lstart=,command='], text=True).strip(),
        cwd=subprocess.check_output(['lsof', '-a', '-p', str(os.getpid()), '-d', 'cwd', '-Fn'], text=True).strip())
    job_path = TASK/'prepare1.job.json'
    job_path.write_text(json.dumps(job, indent=2)+'\n')
    try:
        protected = [PLAN, Path(__file__), ROOT/'tools/prepare_application_host_candidate.py',
            BASE/'candidate1-inputs.json', BASE/'publication1.json', BASE/'external-close1.json',
            ROOT/'docs/evidence/application-host-gameplay-preflight-observations.json', validation, ROOT/'docs/evidence/application-host-gameplay-preflight.json',
            ROOT/'docs/research/APPLICATION_HOST_GAMEPLAY_PREFLIGHT.md', root_manifest, source_manifest,
            ROOT/'AGENTS_HISTORY_2026-09-12.md', ROOT/'docs/research/WORKFLOW.md',
            ROOT/'docs/research/TASK_TEMPLATE.md', ROOT/'docs/evidence/codex-safety-incidents-2026-09-12.json',
            ROOT/'docs/evidence/application-host-gameplay-preflight-context.json',
            ROOT/'docs/evidence/application-host-gameplay-preflight-budget-amendment.json']
        context = dict(schema='ntsd-host-gameplay-candidate-context-v1', UTC=now(),
            head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
            protected=[pin(p) for p in protected], baseline=str(BASE/'candidate1'), baselineManifest=pin(BASE/'candidate1-inputs.json'),
            rootManifest=str(root_manifest), sourceTask=str(source_task), sourceCodePins=source['codePins'],
            sourceIdentity=identity, sourceCwd=cwd, initialExternalFree=free, allowance=4*2**30, stopThreshold=3584*2**20,
            originalExternalReserve=40*2**30, originalInternalReserve=6*2**30,
            gitStatus=subprocess.check_output(['git', 'status', '--porcelain=v1'], text=True))
        (TASK/'context1.json').write_text(json.dumps(context, indent=2)+'\n')
        for old, name in [(PLAN, 'plan1.md'), (Path(__file__), 'prepare1.py'), (BASE/'candidate1-inputs.json', 'baseline-inputs1.json')]:
            shutil.copy2(old, TASK/name)
        clone = ctypes.CDLL(None, use_errno=True).clonefile
        clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
        clone.restype = ctypes.c_int
        for item in inputs:
            assert free-shutil.disk_usage(TASK).free < 3584*2**20
            old, new = BASE/'candidate1'/item['path'], TASK/'candidate1'/item['path']
            new.parent.mkdir(parents=True, exist_ok=True)
            if clone(os.fsencode(old), os.fsencode(new), 0):
                raise OSError(ctypes.get_errno(), str(new))
            same(new, item)
            assert old.stat().st_ino != new.stat().st_ino
        actual = {str(p.relative_to(TASK/'candidate1')) for p in (TASK/'candidate1').rglob('*') if p.is_file()}
        assert actual == {r['path'] for r in inputs}
        job.update(status='terminal', exitCode=0, files=len(inputs), distinctRegularInodes=True, fullCloneVerified=True)
    except BaseException as error:
        job.update(status='terminal', exitCode=1, error=repr(error), traceback=traceback.format_exc())
        raise
    finally:
        job.update(endedUTC=now(), elapsedSeconds=time.monotonic()-began)
        job_path.write_text(json.dumps(job, indent=2)+'\n')
        print(json.dumps(job))


if __name__ == '__main__':
    main()
