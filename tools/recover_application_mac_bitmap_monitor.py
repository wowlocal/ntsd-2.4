#!/usr/bin/env python3
"""Publish the same build's actual exit witness and version the unstarted test monitor."""
import ast,datetime,difflib,json,os,subprocess
from pathlib import Path
from archive_catalog53_storage import ROOT,pin,checked
P=(ROOT/'build/research/application-mac-bitmap-20260926').resolve()
read=lambda p:json.loads(p.read_text())
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
def record(p):return dict(path=str(p.resolve()),**pin(p))
def absent(pid):return not subprocess.run(['ps','-p',str(pid),'-o','pid=,lstart=,command='],capture_output=True,text=True).stdout.strip()
def save(name,value):
 p=P/name;assert not p.exists();p.write_text(json.dumps(value,indent=2)+'\n')
def once(s,a,b):
 assert s.count(a)==1,(a,s.count(a));return s.replace(a,b)
def main():
 j=read(P/'build1.job.json');o=read(P/'build1-exit-observation.json');controls=read(P/'exit-observer-controls1.json')
 assert j['status']=='monitor-error' and j['error']=='AssertionError()' and 'assert pid!=59727' in j['traceback']
 assert o['status']=='exit-observed' and o['rawWaitStatus']==0 and o['exitCode']==0 and o['eventFFlags']&0x84000000==0x84000000
 assert o['targetPID']==j['pid']==54930 and o['targetIdentity']==j['processIdentity'] and o['targetCwd']==j['observedProcesses'][str(j['pid'])]['cwd']
 assert not o['targetIdentityAfter'] and not o['signals'] and not o['buildRestarted'] and o['monitorGap']
 assert [x['requestedCode'] for x in controls['controls']]==[0,7]
 assert all(x['decoded']==x['reaped']==x['requestedCode'] and x['fflags']&0x84000000==0x84000000 for x in controls['controls'])
 seen=set(j['observedProcesses'])|set(o['observedProcesses'])|{str(j['pid']),str(o['pid'])}
 assert all(absent(int(pid)) for pid in seen)
 ps=subprocess.check_output(['ps','-axo','pid=,ppid=,pgid=,command='],text=True)
 assert not any(len(a:=line.split(None,3))==4 and a[2]==str(j['pid']) for line in ps.splitlines())
 for row in read(P/'candidate1-inputs.json'):checked(P/'candidate1'/row['path'],row)
 for row in read(P/'context1.json')['protected']:checked(Path(row['path']),row)
 for row in read(P/'context1.json')['sourceCodePins']:checked(ROOT/row['path'],row)
 recovered=dict(j,status='terminal',exitCode=0,endedUTC=o['eventUTC'],elapsedSeconds=(datetime.datetime.fromisoformat(o['eventUTC'])-datetime.datetime.fromisoformat(j['startedUTC'])).total_seconds(),peakTreeRSS=max(j['peakTreeRSS'],o['peakTreeRSS']),remainingProcessGroup=[],remainingObservedProcesses={},signals=[],exitProvenance=record(P/'build1-exit-observation.json'),originalMonitorFailure=record(P/'build1.job.json'),recoveredUTC=now(),monitorGap=True,continuousResourceBoundVerified=False,buildRestarted=False)
 save('build1-recovered.job.json',recovered)
 generated=[]
 def write(name,new,old,source):
  ast.parse(new);p=P/'tools'/name;assert not p.exists();p.write_text(new)
  generated.append(dict(source=record(source),generated=record(p),patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=source.name,tofile=name))))
 src=P/'tools/run_application_host_gameplay_validation.py';old=src.read_text();s=old
 helper='''def same_lifetime(a, b):
    a,b=a.split(None,6),b.split(None,6)
    return len(a)==len(b)==7 and a[:6]==b[:6]


'''
 s=once(s,'def main(config_path,config_sha):',helper+'def main(config_path,config_sha):')
 s=s.replace("P/'runner-inputs1.json'","P/'runner-inputs2.json'")
 s=once(s,"read(P/(config['buildPhase']+'.job.json'))['exitCode']","read(P/(config['buildPhase']+'-recovered.job.json'))['exitCode']")
 s=once(s,"else:assert sj['status']=='terminal' and not sp","else:assert sj['status']=='terminal' and (not sp or not same_lifetime(sp,sj['processIdentity']))")
 s=once(s,'pid=int(a[0]);assert pid!=59727','pid=int(a[0])')
 s=once(s,'                        if not current:continue\n                        where_now=cwd(pid)',"                        if not current:continue\n                        assert not same_lifetime(current,sj['processIdentity']), 'protected source lifetime'\n                        where_now=cwd(pid)")
 # Guard loop, signal identity/cwd/PGID checks, reaping and terminal result stay exact.
 a='                external,internal=shutil.disk_usage(P).free';assert old[old.index(a):]==s[s.index(a):]
 ns={};exec(helper,ns);same=ns['same_lifetime']
 source=read(Path(read(P/'context1.json')['sourceTask'])/'capture1/source.job.json')['processIdentity']
 assert same(source,source) and same(source,' '.join(source.split(None,6)[:6])+ ' /changed/executable')
 assert not same(source,'59727 Fri Sep 25 00:00:00 2099 /replacement')
 assert not same(source,'1 Fri Sep 25 00:00:00 2099 /replacement')
 assert not same(source,'') and not same('',source)
 write('run_application_host_gameplay_validation2.py',s,old,src)
 src=P/'tools/run_application_host_gameplay_tests.py';old=src.read_text();s=old.replace('from run_application_host_gameplay_validation import','from run_application_host_gameplay_validation2 import').replace('/tools/run_application_host_gameplay_validation.py','/tools/run_application_host_gameplay_validation2.py')
 a,b='            done = re.findall(',"            job['completed'].append("
 assert old[old.index(a):old.index(b)]==s[s.index(a):s.index(b)]
 write('run_application_host_gameplay_tests2.py',s,old,src)
 src=P/'tools/verify_application_host_gameplay_package.py';old=src.read_text();s=once(old,"job_path = task/(build_phase+'.job.json')","job_path = task/(build_phase+'-recovered.job.json')")
 s=once(s,"    assert job['status'] == 'terminal' and job['exitCode'] == 0","    assert job['status'] == 'terminal' and job['exitCode'] == 0\n    assert job['monitorGap'] and not job['continuousResourceBoundVerified'] and not job['buildRestarted']\n    checked(Path(job['exitProvenance']['path']),job['exitProvenance'])\n    checked(Path(job['originalMonitorFailure']['path']),job['originalMonitorFailure'])")
 write('verify_application_host_gameplay_package2.py',s,old,src)
 src=P/'finalize1.py';old=src.read_text();s=old.replace('finalizer-inputs1.json','finalizer-inputs2.json').replace('finalize1.job.json','finalize2.job.json').replace('finalize1.log','finalize2.log').replace("'runner-inputs1.json'","'runner-inputs2.json'").replace("['prepare1.job.json','build1.job.json']","['prepare1.job.json','build1-recovered.job.json']").replace("P/'build1.job.json'","P/'build1-recovered.job.json'")
 s=s.replace('tools/run_application_host_gameplay_tests.py','tools/run_application_host_gameplay_tests2.py').replace('tools/run_application_host_gameplay_validation.py','tools/run_application_host_gameplay_validation2.py')
 s=s.replace('independentReview=False)', 'independentReview=False,buildMonitoringGap=True,continuousBuildResourceBoundVerified=False)')
 s=s.replace('bitmapProviderAdded=True,allOldTestBodiesUnchanged=True','bitmapProviderAdded=True,buildMonitoringGap=True,continuousBuildResourceBoundVerified=False,allOldTestBodiesUnchanged=True')
 ast.parse(s);dest=P/'finalize2.py';assert not dest.exists();dest.write_text(s)
 save('finalizer-inputs2.json',dict(source=record(src),finalizer=record(dest),patch=''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='finalize1.py',tofile='finalize2.py')),originalMonitorErrorPreserved=True))
 save('monitor-recovery1.json',dict(UTC=now(),oldJob=record(P/'build1.job.json'),recoveredJob=record(P/'build1-recovered.job.json'),exitObservation=record(P/'build1-exit-observation.json'),controls=record(P/'exit-observer-controls1.json'),adapter=record(Path(__file__)),plan=record(ROOT/'docs/research/APPLICATION_MAC_BITMAP_MONITOR_RECOVERY.md'),generated=generated,sameLifetimeControls=2,differentOrMissingControls=4,guardAndSignalBodyUnchanged=True,testResultPredicatesUnchanged=True,nativeInputsUnchanged=True,buildRestarted=False,monitorGap=True,unknownIdentityOfReused59727=True,sourceExecuted=False))
 required=[Path(row['generated']['path']) for row in generated]+[P/'build1-recovered.job.json',P/'build1.job.json',P/'build1-exit-observation.json',P/'exit-observer-controls1.json',P/'monitor-recovery1.json',P/'observe-build1.py',ROOT/'tools/archive_catalog53_storage.py',Path(__file__),ROOT/'docs/research/APPLICATION_MAC_BITMAP_MONITOR_RECOVERY.md']
 save('runner-inputs2.json',[record(p) for p in required])
 print(json.dumps(dict(exitCode=0,target=54930,buildRestarted=False,continuousResourceBoundVerified=False,unstartedMethods=48)))
if __name__=='__main__':main()
