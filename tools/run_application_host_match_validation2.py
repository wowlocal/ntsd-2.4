"""One fresh host-candidate build/test command, reusing Catalog53 job monitoring.

The descendant RSS/space/guard/reap loop is derived from the frozen earlier
runner. New preflight gates describe the host candidate. No original execution.
"""
import datetime
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import subprocess
import sys
import time
import traceback
from archive_catalog53_storage import ROOT, checked, pin


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def read(path):
    return json.loads(path.read_bytes())


def owned_cwd(observed,pid,task):
    prefix=f'p{pid}\nfcwd\nn'
    return observed.startswith(prefix) and Path(observed[len(prefix):]).is_relative_to(task)


def compiler_transition(before,current,old_cwd,new_cwd,task):
    a,b=before.split(None,6),current.split(None,6)
    if len(a)!=7 or len(b)!=7 or a[:6]!=b[:6] or old_cwd!=new_cwd:return False
    if not owned_cwd(new_cwd,int(b[0]),task):return False
    allowed={'swift-build','swiftc','swift-driver','swift-frontend','clang','ld','codesign','sandbox-exec'}
    def executable(command):
        path=Path(command.split(' ',1)[0])
        return path.name in allowed and (str(path).startswith('/Applications/Xcode.app/Contents/') or str(path) in ('/usr/bin/codesign','/usr/bin/sandbox-exec'))
    return executable(a[6]) and executable(b[6])


def transient_xctest_exit(before, current, observed_cwd):
    """Recognize the saved read observation, never infer an exit or allow a signal."""
    a,b=before.split(None,6),current.split(None,6)
    return (len(a)==len(b)==7 and a[:6]==b[:6] and
            a[6].startswith('/Applications/Xcode.app/Contents/Developer/usr/bin/xctest ')and
            b[6]=='(xctest)'and observed_cwd=='')


def main(config_path,config_sha):
    P=config_path.parent
    assert P.name=='application-host-match-correction1-20260922'
    checked(config_path,{'sha256':config_sha})
    config=read(config_path);context=read(P/'context1.json');phase=config['phase']
    assert re.fullmatch(r'build[123]|test-(0[1-9]|[1-4][0-9]|5[0-3])',phase)
    assert config_path.name==phase+'-config.json'
    checked(P/'context1.json',{'sha256':config['contextSHA256']})
    checked(P/'candidate1-inputs.json',{'sha256':config['candidateManifestSHA256']})
    for item in read(P/'runner-inputs1.json'):checked(Path(item['path']),item)
    assert read(P/'prepare1.job.json')['exitCode']==0
    for item in context['protected']:checked(Path(item['path']),item)
    for item in context['sourceCodePins']:checked(ROOT/item['path'],item)
    for item in read(P/'candidate1-inputs.json'):checked(P/'candidate1'/item['path'],item)
    assert config['environment']==context['environment']
    assert set(config['environment'])<={'HOME','USER','LOGNAME','LANG','LC_ALL','PATH','TMPDIR'}
    assert config['cwd']==str(P/'candidate1') and config['environment']['TMPDIR']==str(P/'tmp')
    if config['kind']=='build':
        assert phase.startswith('build') and Path(config['command'][0]).name=='swift-build'
        assert '--build-tests' in config['command'] and '--build-system' in config['command']
    else:
        assert phase.startswith('test-') and config['kind']=='test'
        package=read(P/'package-check1.json');assert package['allInputBytesVerified']
        checked(Path(package['binary']['path']),package['binary'])
        assert read(P/(config['buildPhase']+'.job.json'))['exitCode']==0 and package['buildPhase']==config['buildPhase']
        selection=read(P/'selected-methods1.json')['methods'];index=int(phase[-2:])-1
        assert config['command']==['/Applications/Xcode.app/Contents/Developer/usr/bin/xctest','-XCTest','NTSDCoreTests.'+selection[index],package['bundle']]
    volume=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
    assert volume['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and volume['FilesystemType']=='apfs'
    source=Path(context['sourceTask']);sj=read(source/'capture1/source.job.json')
    sp=subprocess.run(['ps','-p',str(sj['pid']),'-o','pid=,lstart=,command='],capture_output=True,text=True).stdout.strip()
    sc=subprocess.run(['lsof','-a','-p',str(sj['pid']),'-d','cwd','-Fn'],capture_output=True,text=True).stdout.strip()
    if sj['status']=='running':
        assert sj['pid']==59727 and sp.split()==sj['processIdentity'].split() and sc==sj['cwdObservation']
    else:assert sj['status']=='terminal' and not sp
    total=0;vanished=0
    for f in (source/'capture1').rglob('*'):
        try:
            if f.is_file():total+=f.stat().st_size
        except FileNotFoundError:vanished+=1
    metadata=sum(f.stat().st_size for f in source.iterdir()if f.is_file())
    gib=2**30;free=shutil.disk_usage(P).free
    spent=max(0,context['startFree']-free);remaining=max(0,context['physicalAllowanceBytes']-spent)
    assert free-max(0,16*gib-total)-max(0,gib-metadata)-remaining>=40*gib
    assert free-max(0,14*gib-total)-remaining>=44*gib
    assert spent<config['stopObservedDecrease'] and shutil.disk_usage(ROOT).free>=config['internalGuardBytes']
    job=P/(phase+'.job.json');assert not job.exists()
    def save():
        q=job.with_suffix('.tmp');q.write_text(json.dumps(j,indent=2)+'\n');os.replace(q,job)
    def identity(pid):
        return subprocess.run(['ps','-p',str(pid),'-o','pid=,lstart=,command='],capture_output=True,text=True).stdout.strip()
    def cwd(pid):
        return subprocess.run(['lsof','-a','-p',str(pid),'-d','cwd','-Fn'],capture_output=True,text=True).stdout.strip()
    def allowed_leader(observed):
        command=observed.split(None,6)[6]if len(observed.split(None,6))==7 else ''
        if command==' '.join(config['command']):return True
        if Path(config['command'][0]).name!='swiftc':return False
        driver=config['command'][0].replace('/swiftc','/swift-driver')
        return command==' '.join([driver,'--driver-mode=swiftc','-Xfrontend','-new-driver-path','-Xfrontend',driver,*config['command'][1:]])
    j=dict(config,status='prepared',UTC=now(),config=pin(config_path),launcher=pin(Path(__file__)),runnerInputs=pin(P/'runner-inputs1.json'),
           sourceObservation=dict(jobStatus=sj['status'],processIdentity=sp,cwd=sc,bytesObservedNonAtomic=total,
             sourceMetadataBytes=metadata,vanishedDuringObservation=vanished),independentReview=False,sourceExecuted=False)
    save();began=time.monotonic();p=None;peak=0;peak_rss=0;minimum=free;minimum_internal=shutil.disk_usage(ROOT).free
    try:
        with (P/(phase+'.log')).open('xb')as log,(P/(phase+'-storage.jsonl')).open('x')as storage:
            p=subprocess.Popen(config['command'],cwd=config['cwd'],env=config['environment'],stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            ident,where=identity(p.pid),cwd(p.pid)
            j.update(pid=p.pid,startedUTC=now(),processIdentity=ident,cwdObservation=where,status='running')
            if p.poll()is None:
                assert str(p.pid)+' 'in ident and allowed_leader(ident),('unexpected initial identity',ident)
                assert owned_cwd(where,p.pid,P),where
            else:j['initialIdentityObservationGap']='Child terminal before complete OS snapshot; command is Popen argv and exit is reaped'
            save();print(json.dumps(dict(phase=phase,pid=p.pid,status=j['status'],startedUTC=j['startedUTC'])),flush=True)
            next_size=0;next_rss=0;size=0;rss=0;known={};live=[]
            while p.poll()is None:
                elapsed=time.monotonic()-began
                heavy=elapsed>=next_size
                if heavy:
                    size=0
                    for f in P.rglob('*'):
                        try:
                            if f.is_file()and not f.is_symlink():size+=f.stat().st_size
                        except FileNotFoundError:pass
                    next_size=elapsed+config['logicalPollSeconds']
                if elapsed>=next_rss:
                    ps=subprocess.check_output(['ps','-axo','pid=,ppid=,pgid=,rss='],text=True)
                    rows=[a for line in ps.splitlines()if len(a:=line.split())==4]
                    selected={str(p.pid)}
                    while True:
                        expanded=selected|{a[0]for a in rows if a[1]in selected}
                        if expanded==selected:break
                        selected=expanded
                    selected|=set(known)
                    live=[]
                    for a in rows:
                        if a[0]not in selected:continue
                        pid=int(a[0]);assert pid!=59727
                        current=identity(pid)
                        if not current:continue
                        where_now=cwd(pid)
                        if not identity(pid):continue
                        if pid==p.pid and p.poll()is not None:
                            j.setdefault('terminalSamplingObservations',[]).append(dict(pid=pid,identity=current,cwd=where_now,exitCode=p.returncode))
                            continue
                        if a[0]in known:
                            before=known[a[0]]['identity']
                            if current!=before:
                                j['lastIdentityChangeObservation']=dict(pid=pid,before=before,current=current,cwd=where_now,leaderPoll=p.poll())
                                if pid==p.pid and p.returncode is not None:continue
                                if pid==p.pid and transient_xctest_exit(before,current,where_now):
                                    j.setdefault('transientExitObservations',[]).append(j['lastIdentityChangeObservation'])
                                    save()
                                    # Retain the last full identity for action checks;
                                    # this read observation supplies no terminal code.
                                    live.append(a)
                                    continue
                                assert compiler_transition(before,current,known[a[0]]['cwd'],where_now,P), (before,current,where_now)
                                j.setdefault('identityTransitions',[]).append(dict(pid=pid,before=before,after=current))
                        else:
                            assert a[1]in selected or pid==p.pid
                        assert owned_cwd(where_now,pid,P),where_now
                        known[a[0]]=dict(identity=current,cwd=where_now,ppid=int(a[1]),pgid=int(a[2]))
                        live.append(a)
                    rss=sum(int(a[3])*1024 for a in live)
                    j['observedProcesses']=known
                    next_rss=elapsed+config['rssPollSeconds']
                external,internal=shutil.disk_usage(P).free,shutil.disk_usage(ROOT).free
                minimum=min(minimum,external);minimum_internal=min(minimum_internal,internal)
                peak=max(peak,size);peak_rss=max(peak_rss,rss)
                sample=dict(UTC=now(),seconds=elapsed,logicalBytes=size,logicalResampled=heavy,treeRSS=rss,
                  externalFree=external,internalFree=internal,observedDecrease=max(0,context['startFree']-minimum))
                storage.write(json.dumps(sample)+'\n');storage.flush()
                reason=('external guard'if external<config['externalGuardBytes']else 'internal guard'if internal<config['internalGuardBytes']else
                  'observed decrease guard'if sample['observedDecrease']>=config['stopObservedDecrease']else
                  'logical bound'if size>config['logicalLimitBytes']else 'resident bound'if rss>config['residentGuardBytes']else
                  'selection time limit'if time.time()>config.get('selectionDeadlineUnix',float('inf'))else
                  'timeout'if elapsed>config['timeoutSeconds']else None)
                if heavy:
                    j.update(elapsedSeconds=elapsed,peakLogicalBytes=peak,peakTreeRSS=peak_rss,minimumExternalFree=minimum,minimumInternalFree=minimum_internal)
                    save()
                if reason and p.poll()is None:
                    recorded=read(job)
                    assert recorded['pid']==p.pid and recorded['processIdentity']==ident and recorded['cwdObservation']==where
                    j.update(status='guard-stopping',guardReason=reason,guardObservation=sample)
                    save()
                    for a in sorted(live,key=lambda a:a[0]==str(p.pid)):
                        pid=int(a[0]);current=identity(pid)
                        if not current:continue
                        expected=known[a[0]]
                        assert current==expected['identity'] and cwd(pid)==expected['cwd'] and os.getpgid(pid)==expected['pgid']
                        j.setdefault('signals',[]).append(dict(pid=pid,identity=current,cwd=expected['cwd'],signal='SIGTERM'))
                        save();os.kill(pid,signal.SIGTERM)
                    p.wait(timeout=30);break
                time.sleep(config['pollSeconds'])
            code=p.wait()
        ps=subprocess.check_output(['ps','-axo','pid=,ppid=,pgid=,command='],text=True)
        descendants=[line.strip()for line in ps.splitlines()if len(a:=line.split(None,3))==4 and a[2]==str(p.pid)]
        remaining_observed={pid:identity(int(pid))for pid in known if identity(int(pid))}
        minimum=min(minimum,shutil.disk_usage(P).free)
        j.update(status='terminal',exitCode=code,endedUTC=now(),elapsedSeconds=time.monotonic()-began,
          peakLogicalBytes=peak,peakTreeRSS=peak_rss,minimumExternalFree=minimum,minimumInternalFree=minimum_internal,
          observedFreeDecrease=max(0,context['startFree']-minimum),remainingProcessGroup=descendants,remainingObservedProcesses=remaining_observed)
        save()
        print(json.dumps({k:j[k]for k in ('status','pid','exitCode','elapsedSeconds','peakLogicalBytes','peakTreeRSS','observedFreeDecrease','remainingProcessGroup')}),flush=True)
        return code
    except BaseException as error:
        j.update(status='monitor-error',error=repr(error),traceback=traceback.format_exc(),leaderPoll=None if p is None else p.poll())
        save();raise


if __name__=='__main__':
    sys.exit(main(Path(sys.argv[1]).resolve(),sys.argv[2]))
