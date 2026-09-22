#!/usr/bin/env python3
"""Verify retained/new named results and archive only completion metadata."""
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


def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def read(p): return json.loads(p.read_bytes())
def record(p): return dict(path=str(p), **pin(p))
def save(p,d):
    assert not p.exists(), str(p)
    p.write_text(json.dumps(d,indent=2)+'\n')
def absent(pid):
    return not subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip()


def main(P):
    assert P.name=='application-host-match-completion-20260922' and not (P/'external-close1.json').exists()
    ctx=read(P/'context1.json');A=Path(ctx['artifactRoot']);began=time.monotonic()
    j=dict(status='running',pid=os.getpid(),startedUTC=now(),
        identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),
        cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip())
    jp=P/'finalize1.job.json';save(jp,j)
    def guard():
        assert ctx['startFree']-shutil.disk_usage(P).free<3584*2**20
        assert shutil.disk_usage(P).free>44*2**30 and shutil.disk_usage(ROOT).free>7*2**30
        assert sum(f.stat().st_size for f in P.rglob('*') if f.is_file())<64*2**20
    def result(task,r,require_pass=False):
        cp,lp=task/(r['phase']+'.job.json'),task/(r['phase']+'.log')
        checked(cp,r['job']);checked(lp,r['log']);child=read(cp);text=lp.read_text()
        assert child['status']=='terminal' and absent(child['pid'])
        assert not child['remainingProcessGroup'] and not child['remainingObservedProcesses']
        assert all(absent(int(pid)) for pid in child['observedProcesses'])
        done=re.findall(r"^Test Case '-\[NTSDCoreTests\.([^ ]+) ([^\]]+)\]' (passed|failed) \(([^)]*)\)\.$",text,re.M)
        passed=(child['exitCode']==0 and len(done)==1 and '/'.join(done[0][:2])==r['method'] and done[0][2]=='passed'
            and text.count('Executed 1 test, with 0 failures (0 unexpected)')==3 and "Test Suite 'Selected tests' passed" in text
            and not child.get('guardReason') and not child.get('signals'))
        assert passed==r['passed']
        if require_pass: assert passed
        return dict(method=r['method'],passed=passed,phase=r['phase'],job=record(cp),log=record(lp),pid=child['pid'],
            exitCode=child['exitCode'],seconds=child['elapsedSeconds'],sampledTreeRSS=child['peakTreeRSS'],
            guardReason=child.get('guardReason'),signals=child.get('signals',[]),namedResults=done,
            initialIdentityObservationGap=child.get('initialIdentityObservationGap'),
            transientExitObservations=child.get('transientExitObservations',[]))
    try:
        guard();prep=read(P/'prepare1.job.json')
        assert prep['status']=='terminal' and prep['exitCode']==0 and absent(prep['pid'])
        q=read(P/'tests1-queue.job.json');old=read(A/'tests1-queue.job.json')
        assert q['status']=='terminal' and q['exitCode'] in (0,1) and absent(q['pid'])
        assert old['status']=='terminal' and old['exitCode']==1 and absent(old['pid'])
        for item in ctx['protected']:checked(Path(item['path']),item)
        for item in ctx['sourceCodePins']:checked(ROOT/item['path'],item)
        for item in read(P/'runner-inputs1.json'):checked(Path(item['path']),item)
        methods=read(A/'selected-methods1.json')['methods'];assert len(methods)==len(set(methods))==53
        prior=[result(A,r,True) for r in old['completed'][:25]]
        assert [r['method'] for r in prior]==methods[:25]
        fresh=[result(P,r) for r in q['completed']]
        assert [r['method'] for r in fresh]==methods[25:25+len(fresh)] and len(fresh)<=28
        assert 1<=len(fresh)<=28 and all(r['passed'] for r in fresh[:-1])
        assert all(not (P/f'test-{i:02d}.job.json').exists() for i in range(26+len(fresh),54))
        complete=len(fresh)==28 and all(r['passed'] for r in fresh)
        assert complete==bool(q.get('all28RemainingPassed')) and q['exitCode']==(0 if complete else 1)
        passed={r['method'] for r in prior+fresh if r['passed']};remaining=[m for m in methods if m not in passed]
        if complete:assert passed==set(methods)
        else:
            assert not fresh[-1]['passed'] and q['reason']=='First nonpassing method; remainder not started'
            assert (P/'failure-diagnosis1.json').is_file()
        prior_guard=read(A/'test-26.job.json');assert prior_guard['exitCode']==-15 and prior_guard['guardReason']=='resident bound'
        for base,rows in [(A/'candidate1',read(A/'candidate1-inputs.json')),(ROOT,read(Path(ctx['rootManifest'])))]:
            members={str(f.relative_to(base)) for top in ('native/Sources','native/Tests') for f in (base/top).rglob('*') if f.is_file()}|{'native/Package.swift'}
            assert members=={r['path'] for r in rows}
            for r in rows:checked(base/r['path'],r)
        package=read(A/'package-check1.json');assert package['candidateFiles']==1039 and package['allInputBytesVerified']
        checked(Path(package['binary']['path']),package['binary'])
        for r in package['resourceFiles']:checked(Path(r['path']),r)
        archive=read(A/'artifact-archive1.json');aroot=A/'artifact-archive1'
        for i,r in enumerate(archive['files']):
            checked(A/r['path'],r);checked(aroot/r['path'],r)
            if i%128==0:guard()
        actual={str(f.relative_to(aroot)) for f in aroot.rglob('*') if f.is_file() and not f.is_symlink()}
        assert actual=={r['path'] for r in archive['files']} and len(actual)==2486
        implicit={'swift','swift/arm64-apple-macosx'}
        expected_dirs=set(implicit)
        for top in ('candidate1','swift/arm64-apple-macosx/release'):
            for f in [A/top,*sorted((A/top).rglob('*'))]:
                if f.is_dir() and not f.is_symlink():
                    relative=str(f.relative_to(A));expected_dirs.add(relative)
                    actual_dir=aroot/relative
                    assert stat.S_IMODE(actual_dir.stat().st_mode)==stat.S_IMODE(f.stat().st_mode)
                    assert actual_dir.stat().st_mtime_ns==f.stat().st_mtime_ns
        assert len(expected_dirs-implicit)==archive['directories']
        assert {str(f.relative_to(aroot)) for f in aroot.rglob('*') if f.is_dir() and not f.is_symlink()}==expected_dirs
        assert {str(f.relative_to(aroot)):os.readlink(f) for f in aroot.rglob('*') if f.is_symlink()}=={r['path']:r['target'] for r in archive['links']}
        source=Path(ctx['sourceTask']);sj=read(source/'capture1/source.job.json')
        identity=subprocess.run(['ps','-p',str(sj['pid']),'-o','pid=,lstart=,command='],capture_output=True,text=True).stdout.strip()
        cwd=subprocess.run(['lsof','-a','-p',str(sj['pid']),'-d','cwd','-Fn'],capture_output=True,text=True).stdout.strip()
        if sj['status']=='running':assert identity.split()==sj['processIdentity'].split() and cwd==sj['cwdObservation']
        else:assert sj['status']=='terminal' and not identity
        with (source/'capture1/source.stdout.log').open('rb') as stream:
            stream.seek(0,2);size=stream.tell();stream.seek(max(0,size-1500));tail=stream.read().decode().splitlines()[-1]
        save(P/'source-live1.json',dict(UTC=now(),identity=identity,cwd=cwd,jobStatus=sj['status'],lastLog=tail,sourcePinsVerified=55))
        verification=dict(schema='ntsd-host-match-completion-verification-v1',UTC=now(),all53Passed=complete,verifiedMethods=len(passed),remaining=remaining,
            priorPasses=prior,newResults=fresh,oldGuard=record(A/'test-26.job.json'),oldGuardPreserved=True,
            newQueueSeconds=q['elapsedSeconds'],newTestSeconds=sum(r['seconds'] for r in fresh),
            sampledNewTestPeakRSS=max((r['sampledTreeRSS'] for r in fresh),default=0),zeroRSSMeansNoSample=True,
            rootNativeFilesUnchanged=1034,candidateFilesUnchanged=1039,resourceFilesUnchanged=487,sourceCodePinsUnchanged=55,
            priorArtifactFilesUnchanged=2486,priorArchiveFilesBodiesModesMtimesMembershipVerified=True,
            archivedTraversalDirectories=154,implicitArchiveParentDirectories=2,archiveDirectoryMembershipVerified=True,
            taskProcessesAbsent=True,originalExecuted=False,independentReview=False)
        save(P/'verification1.json',verification)
        names=['prepare_application_host_match_completion.py','run_application_host_match_validation3.py','run_application_host_match_tests3.py',Path(__file__).name]
        for n in names:shutil.copy2(ROOT/'tools'/n,P/('frozen-'+n))
        metadata=sorted(f for f in P.iterdir() if f.is_file() and f!=jp)
        save(P/'metadata-inputs1.json',[dict(path=f.name,**pin(f)) for f in metadata]);metadata.append(P/'metadata-inputs1.json')
        tar=P/'metadata1.tar'
        with tarfile.open(tar,'w',format=tarfile.PAX_FORMAT) as tf:
            for f in metadata:
                info=tf.gettarinfo(str(f),arcname=f.name);ns=f.stat().st_mtime_ns
                info.mtime=ns//10**9;info.pax_headers['mtime']=f'{ns//10**9}.{ns%10**9:09d}'
                with f.open('rb') as body:tf.addfile(info,body)
        with tarfile.open(tar) as tf:
            assert len(tf.getmembers())==len(metadata) and {m.name for m in tf.getmembers()}=={f.name for f in metadata}
            for f in metadata:
                m=tf.getmember(f.name);assert m.isfile() and m.mode==stat.S_IMODE(f.stat().st_mode) and m.size==f.stat().st_size
                assert int(Decimal(m.pax_headers['mtime'])*10**9)==f.stat().st_mtime_ns
                assert tf.extractfile(m).read()==f.read_bytes()
        assert tar.stat().st_size<32*2**20;guard()
        publication=dict(schema='ntsd-host-match-completion-v1',UTC=now(),status='all53-passed-review-open' if complete else 'partial-validation-open',
            task=str(P),baseHead=ctx['head'],artifactRoot=str(A),context=record(P/'context1.json'),verification=record(P/'verification1.json'),
            resourceContract=record(P/'resource-contract1.json'),priorPublication=record(A/'publication1.json'),candidateManifest=record(A/'candidate1-inputs.json'),binary=package['binary'],
            packageCheck=record(A/'package-check1.json'),priorArtifactArchive=record(A/'artifact-archive1.json'),
            all53Passed=complete,verifiedMethods=len(passed),newMethods=len(fresh),remaining=remaining,
            newQueueSeconds=q['elapsedSeconds'],newTestSeconds=verification['newTestSeconds'],sampledNewTestPeakRSS=verification['sampledNewTestPeakRSS'],
            metadataArchive=dict(members=len(metadata),**record(tar)),sourceObservation=record(P/'source-live1.json'),
            failureDiagnosis=None if complete else record(P/'failure-diagnosis1.json'),
            gates=dict(nativeComparison=complete,packageBytes=True,archive=True,independentReview=False,rootPromotion=False,actualWindowInputAudio=False,wholeCatalogSource=False,fullGame=False),
            limitations=['Typed-host changes have not received independent contract review.','Old assertion failure and old resident-guard termination remain immutable outcomes.',
                'First gameplay input inspection stops with rollback; it does not establish retained gameplay or a complete tick, match or whole Catalog53 source.',
                'Actual providers/timing/devices, retained gameplay, full match and full game remain open.'])
        save(P/'publication1.json',publication)
        target=ROOT/'docs/evidence/application-host-match-completion.json';assert not target.exists();target.write_bytes((P/'publication1.json').read_bytes())
        closure=dict(schema='ntsd-host-match-completion-close-v1',UTC=now(),largePhaseClosed=True,taskFrozen=True,
            originalExternalReserve=40*2**30,originalInternalReserve=6*2**30,runtimeExternalFloor=44*2**30,runtimeInternalFloor=7*2**30,
            initialExternalFree=ctx['startFree'],externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(ROOT).free,
            observedFreeDecrease=ctx['startFree']-shutil.disk_usage(P).free,allowance=4*2**30,includesConcurrentSourceGrowth=True,
            publication=pin(P/'publication1.json'),metadataArchive=pin(tar))
        save(P/'external-close1.json',closure);target=ROOT/'docs/evidence/application-host-match-completion-close.json';assert not target.exists();target.write_bytes((P/'external-close1.json').read_bytes())
        j.update(status='terminal',exitCode=0,validationPassed=complete,verifiedMethods=len(passed),metadataMembers=len(metadata))
    except BaseException as error:
        j.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
    finally:
        j.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);jp.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(j))


if __name__=='__main__':main(Path(sys.argv[1]).resolve())
