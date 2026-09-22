#!/usr/bin/env python3
"""Pin existing host-loading products and prior passes for eight whole methods."""
import ast
import datetime
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import time
import traceback
from archive_catalog53_storage import ROOT, checked, pin

TASK = Path('/Volumes/X5/ntsd-2.4-research/01a0c7b2-a956-7760-950e-ecf7dceaaa20/application-host-loading-regressions-20260922')
ARTIFACT = TASK.with_name('application-host-loading-correction3-20260922')
PLAN = ROOT/'docs/research/APPLICATION_HOST_LOADING_REGRESSIONS_PLAN.md'


def read(p): return json.loads(p.read_bytes())
def save(p, d): p.write_text(json.dumps(d, indent=2)+'\n')
def record(p): return dict(path=str(p.resolve()), **pin(p))
def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()


def main():
    assert not TASK.exists()
    volume = plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
    assert volume['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and volume['FilesystemType']=='apfs'
    start_free = shutil.disk_usage(TASK.parent).free
    assert start_free > 62*2**30 and shutil.disk_usage(ROOT).free > 7*2**30
    assert read(ARTIFACT/'external-close1.json')['taskFrozen']
    TASK.mkdir(); (ROOT/'build/research'/TASK.name).symlink_to(TASK, target_is_directory=True)
    (TASK/'tmp').mkdir(); began = time.monotonic()
    job = dict(status='running',pid=os.getpid(),startedUTC=now(),
        processIdentity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),
        cwdObservation=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip())
    save(TASK/'prepare1.job.json',job)
    try:
        old = read(ARTIFACT/'context1.json')
        protected = list(old['protected'])
        paths = [PLAN,Path(__file__),ARTIFACT/'context1.json',ARTIFACT/'publication1.json',ARTIFACT/'external-close1.json',
            ARTIFACT/'candidate1-inputs.json',ARTIFACT/'package-check1.json',ARTIFACT/'tests1-queue.job.json',
            ARTIFACT/'selected-methods1.json',ARTIFACT/'guard-diagnosis1.json',ARTIFACT/'test-35.job.json',ARTIFACT/'test-35.log',
            ARTIFACT/'artifact-archive1.json',ARTIFACT/'metadata1.tar',
            ROOT/'tools/run_application_host_loading_validation4.py',ROOT/'tools/run_application_host_loading_tests4.py']
        protected += [record(f) for f in paths]
        for item in protected: checked(Path(item['path']),item)
        for item in old['sourceCodePins']: checked(ROOT/item['path'],item)
        for base,rows in [(ARTIFACT/'candidate1',read(ARTIFACT/'candidate1-inputs.json')),(ROOT,read(Path(old['rootManifest'])))]:
            members={str(f.relative_to(base)) for top in ('native/Sources','native/Tests') for f in (base/top).rglob('*') if f.is_file()}|{'native/Package.swift'}
            assert members=={r['path'] for r in rows}
            for item in rows: checked(base/item['path'],item)
        package=read(ARTIFACT/'package-check1.json'); checked(Path(package['binary']['path']),package['binary'])
        for item in package['resourceFiles']: checked(Path(item['path']),item)
        queue=read(ARTIFACT/'tests1-queue.job.json');assert queue['status']=='terminal' and queue['exitCode']==1
        assert len(queue['completed'])==35 and [r['passed'] for r in queue['completed']]==[True]*34+[False]
        methods=read(ARTIFACT/'selected-methods1.json')['methods'];prior=[]
        for index,r in enumerate(queue['completed'][:34]):
            assert r['method']==methods[index]
            jp,lp=ARTIFACT/(r['phase']+'.job.json'),ARTIFACT/(r['phase']+'.log')
            checked(jp,r['job']);checked(lp,r['log']);j=read(jp);text=lp.read_text()
            assert j['status']=='terminal' and j['exitCode']==0 and not j.get('guardReason') and not j.get('signals')
            assert not j['remainingProcessGroup'] and not j['remainingObservedProcesses']
            done=re.findall(r"^Test Case '-\[NTSDCoreTests\.([^ ]+) ([^\]]+)\]' (passed|failed) \(([^)]*)\)\.$",text,re.M)
            assert len(done)==1 and '/'.join(done[0][:2])==r['method'] and done[0][2]=='passed'
            assert text.count('Executed 1 test, with 0 failures (0 unexpected)')==3 and "Test Suite 'Selected tests' passed" in text
            prior.append(dict(method=r['method'],job=record(jp),log=record(lp)))
            protected.extend([record(jp),record(lp)])
        save(TASK/'prior-passes1.json',dict(methods=prior,count=34,remaining=methods[34:],required=methods))
        environment=dict(old['environment'],TMPDIR=str(TASK/'tmp'))
        context=dict(schema='ntsd-host-loading-completion-context-v1',UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
            artifactRoot=str(ARTIFACT),rootManifest=old['rootManifest'],sourceTask=old['sourceTask'],sourceCodePins=old['sourceCodePins'],
            protected=protected,startFree=start_free,physicalAllowanceBytes=2**30,stopObservedDecrease=768*2**20,
            originalExternalReserve=40*2**30,originalInternalReserve=6*2**30,environment=environment,
            physicalMemoryBytes=int(subprocess.check_output(['sysctl','-n','hw.memsize'],text=True)),
            vmStat=subprocess.check_output(['vm_stat'],text=True),candidateFiles=1037,rootNativeFiles=1034,packageResourceFiles=487,
            allInputBytesVerified=True,retainedPasses=34,remainingMethods=8,sourceExecuted=False,independentReview=False,
            gitStatus=subprocess.check_output(['git','status','--porcelain=v1'],text=True))
        assert context['physicalMemoryBytes']==24*2**30
        save(TASK/'resource-contract1.json',dict(revisedAfterThreeRounds=True,diagnosis=record(ARTIFACT/'guard-diagnosis1.json'),retainedPasses=34,remainingMethods=methods[34:],residentBytes={f'test-{i:02d}':(12 if i<=37 else 8)*2**30 for i in range(35,43)},candidateOrExpectedChanged=False,timeLimitSeconds=600,independentReview=False))
        save(TASK/'context1.json',context)
        config=dict(read(ARTIFACT/'test-35-config.json'),artifactRoot=str(ARTIFACT),environment=environment,
            contextSHA256=pin(TASK/'context1.json')['sha256'],stopObservedDecrease=768*2**20,externalGuardBytes=44*2**30,
            internalGuardBytes=7*2**30,logicalLimitBytes=64*2**20,residentGuardBytes=12*2**30)
        config.pop('selectionDeadlineUnix',None);save(TASK/'test-template1.json',config)
        previous=(ROOT/'tools/run_application_host_loading_validation4.py').read_text();current=(ROOT/'tools/run_application_host_loading_validation5.py').read_text()
        def function(s,n):return ast.get_source_segment(s,next(f for f in ast.parse(s).body if isinstance(f,ast.FunctionDef) and f.name==n))
        names=['owned_cwd','compiler_transition','transient_xctest_exit']
        for n in names:assert function(previous,n)==function(current,n)
        a=previous[previous.index('    job=P/(phase+'):];b=current[current.index('    job=P/(phase+'):]
        a=a.replace('owned_cwd(where,p.pid,P)','owned_cwd(where,p.pid,A)').replace("compiler_transition(before,current,known[a[0]]['cwd'],where_now,P)","compiler_transition(before,current,known[a[0]]['cwd'],where_now,A)").replace('owned_cwd(where_now,pid,P)','owned_cwd(where_now,pid,A)')
        assert a==b
        from run_application_host_loading_validation5 import owned_cwd
        cases=[('artifact root',f'p123\nfcwd\nn{ARTIFACT}/candidate1',True),('artifact child',f'p123\nfcwd\nn{ARTIFACT}/candidate1/native',True),('other task',f'p123\nfcwd\nn{TASK}/tmp',False),('prefix sibling',f'p123\nfcwd\nn{ARTIFACT}-wrong/candidate1',False),('wrong pid',f'p124\nfcwd\nn{ARTIFACT}/candidate1',False),('empty','',False)]
        for _,observed,want in cases:assert owned_cwd(observed,123,ARTIFACT)==want
        valid=[f'test-{i:02d}' for i in range(35,43)];invalid=['test-34','test-43','test-00','build1','other']
        for phase in valid:assert re.fullmatch(r'test-(3[5-9]|4[0-2])',phase)
        for phase in invalid:assert not re.fullmatch(r'test-(3[5-9]|4[0-2])',phase)
        save(TASK/'runner-preflight1.json',dict(identicalPredicates=names,monitorLoopIdenticalExceptVerifiedArtifactRootArgument=True,
            cwdControls=[dict(name=n,expected=w,passed=True) for n,_,w in cases],validPhases=valid,invalidPhases=invalid,
            syntheticClassificationOnly=True,newOriginalOrDarwinTransitionExecution=False))
        inputs=[ROOT/'tools/run_application_host_loading_validation5.py',ROOT/'tools/run_application_host_loading_tests5.py',
            ROOT/'tools/archive_catalog53_storage.py',TASK/'runner-preflight1.json',TASK/'prior-passes1.json',TASK/'test-template1.json',TASK/'resource-contract1.json']
        save(TASK/'runner-inputs1.json',[record(f) for f in inputs])
        shutil.copy2(PLAN,TASK/'plan1.md');shutil.copy2(Path(__file__),TASK/'prepare1.py')
        assert start_free-shutil.disk_usage(TASK).free<768*2**20
        job.update(status='terminal',exitCode=0,allInputsVerified=True,retainedPasses=34,remaining=8,context=record(TASK/'context1.json'))
    except BaseException as error:
        job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
    finally:
        job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);save(TASK/'prepare1.job.json',job);print(json.dumps(job))


if __name__=='__main__':main()
