#!/usr/bin/env python3
"""Run the 28 remaining whole methods through the existing guarded runner."""
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import traceback
from archive_catalog53_storage import ROOT, checked, pin
from run_application_host_match_validation3 import main as run_one


def save(path, value):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value, indent=2)+'\n')
    os.replace(temp, path)


def main(task):
    context = json.loads((task/'context1.json').read_text())
    artifact = Path(context['artifactRoot'])
    package = json.loads((artifact/'package-check1.json').read_text())
    assert package['allInputBytesVerified'] and package['buildPhase'] == 'build1'
    checked(Path(package['binary']['path']), package['binary'])
    methods = json.loads((artifact/'selected-methods1.json').read_text())['methods']
    assert len(methods) == len(set(methods)) == 53
    methods = methods[25:]
    assert len(methods) == 28
    template = json.loads((task/'test-template1.json').read_text())
    job_path = task/'tests1-queue.job.json'
    assert not job_path.exists()
    deadline = time.time()+7200
    cases = []
    for index, method in enumerate(methods, 26):
        phase = f'test-{index:02d}'
        config = dict(template, phase=phase, kind='test',
            command=['/Applications/Xcode.app/Contents/Developer/usr/bin/xctest', '-XCTest', 'NTSDCoreTests.'+method, package['bundle']],
            timeoutSeconds=900 if index>=51 else 600, residentGuardBytes=(16 if index>=51 else 12 if index in (26,28,35,36,37) or 43<=index<=50 else 8)*2**30, selectionDeadlineUnix=deadline)
        path = task/(phase+'-config.json')
        assert not path.exists()
        path.write_text(json.dumps(config, indent=2)+'\n')
        cases.append(dict(method=method, phase=phase, config=str(path), pin=pin(path)))
    selection = dict(schema='ntsd-host-match-test-commands-v1', cases=cases, packageCheck=pin(artifact/'package-check1.json'),
        selectedMethods=pin(artifact/'selected-methods1.json'), queueProducer=pin(Path(__file__)),
        runner=pin(ROOT/'tools/run_application_host_match_validation3.py'), completeResultParser='same exact named XCTest regex and one-test zero-failure summary as Catalog53 completion')
    save(task/'tests1-commands.json', selection)
    shutil.copy2(Path(__file__), task/'tests1-queue.py')
    started = time.monotonic()
    job = dict(schema='ntsd-host-match-test-queue-v1', pid=os.getpid(), status='running',
        processIdentity=subprocess.check_output(['ps', '-p', str(os.getpid()), '-o', 'pid=,lstart=,command='], text=True).strip(),
        cwdObservation=subprocess.check_output(['lsof', '-a', '-p', str(os.getpid()), '-d', 'cwd', '-Fn'], text=True).strip(),
        startedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(), selection=pin(task/'tests1-commands.json'), completed=[], current=None)
    save(job_path, job)
    try:
        for case in cases:
            assert time.time() < deadline
            checked(Path(case['config']), case['pin'])
            job['current'] = case
            save(job_path, job)
            code = run_one(Path(case['config']), case['pin']['sha256'])
            child_path = task/(case['phase']+'.job.json')
            child = json.loads(child_path.read_text())
            assert child['status'] == 'terminal' and not child['remainingProcessGroup'] and not child['remainingObservedProcesses']
            log_path = task/(case['phase']+'.log')
            text = log_path.read_text()
            done = re.findall(r"^Test Case '-\[NTSDCoreTests\.([^ ]+) ([^\]]+)\]' (passed|failed) \(([^)]*)\)\.$", text, re.M)
            passed = (code == 0 and len(done) == 1 and '/'.join(done[0][:2]) == case['method'] and
                      done[0][2] == 'passed' and text.count('Executed 1 test, with 0 failures (0 unexpected)') == 3 and
                      "Test Suite 'Selected tests' passed" in text and
                      not child.get('guardReason'))
            job['completed'].append(dict(method=case['method'], phase=case['phase'], exitCode=code,
                passed=passed, completed=done, job=pin(child_path), log=pin(log_path)))
            save(job_path, job)
            print(json.dumps(dict(method=case['method'], passed=passed, completed=len(job['completed']))), flush=True)
            if not passed:
                job.update(status='terminal', exitCode=1, reason='First nonpassing method; remainder not started')
                break
        else:
            job.update(status='terminal', exitCode=0, all28RemainingPassed=True)
    except BaseException as error:
        job.update(status='queue-error', error=repr(error), traceback=traceback.format_exc())
        raise
    finally:
        job.update(endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(), elapsedSeconds=time.monotonic()-started)
        save(job_path, job)
    return job['exitCode']


if __name__ == '__main__':
    sys.exit(main(Path(sys.argv[1]).resolve()))
