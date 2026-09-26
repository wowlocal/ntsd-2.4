#!/usr/bin/env python3
"""Reuse frozen completion tools for saved-result recovery and methods59–69."""
import ast
import datetime
import difflib
import json
from pathlib import Path
import re
import subprocess
import sys
from archive_catalog53_storage import ROOT, checked, pin

TASK_NAME = 'application-host-gameplay-completion-20260926'
BASE_NAME = 'application-host-gameplay-correction1-20260926'
TASK = Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/TASK_NAME
GENERATED = ROOT/'build/research'/(TASK_NAME+'-tools')
NAMES = ['prepare_application_host_match_completion.py','run_application_host_match_validation3.py',
         'run_application_host_match_tests3.py','finalize_application_host_match_completion.py']
OLD_PATTERN = r"^Test Case '-\[NTSDCoreTests\.([^ ]+) ([^\]]+)\]' (passed|failed) \(([^)]*)\)\.$"
NEW_PATTERN = OLD_PATTERN[1:]


def once(text, before, after):
    assert text.count(before)==1,(before,text.count(before))
    return text.replace(before,after)


def check_reader(artifact, task):
    """Read-only controls: only the leading anchor changes; all old bytes stay."""
    queue=json.loads((artifact/'tests1-queue.job.json').read_text())
    assert len(queue['completed'])==58 and [r['passed'] for r in queue['completed']]==[True]*57+[False]
    for name in ('tests1-queue.job.json','build1.job.json','finalize1.job.json'):
        old_job=json.loads((artifact/name).read_text())
        assert old_job['status']=='terminal'
        assert not subprocess.run(['ps','-p',str(old_job['pid']),'-o','pid='],capture_output=True,text=True).stdout.strip()
    diagnosis=json.loads((artifact/'failure-diagnosis1.json').read_text())
    method=queue['completed'][-1]['method'];raw=(artifact/'test-58.log').read_bytes();text=raw.decode()
    checked(artifact/'test-58.log',queue['completed'][-1]['log'])
    matches=list(re.finditer(NEW_PATTERN,text,re.M))
    assert not re.findall(OLD_PATTERN,text,re.M) and len(matches)==1
    match=matches[0];span=diagnosis['exactNamedSpan']
    assert raw[span['startByte']:span['endByte']]==match[0].encode()==span['text'].encode()
    assert len(text[:match.start()].encode())==span['startByte']
    def accepts(value,name=method,code=0,guard=False,signals=False,remaining=False):
        done=re.findall(NEW_PATTERN,value,re.M)
        return (code==0 and len(done)==1 and '/'.join(done[0][:2])==name and done[0][2]=='passed'
            and value.count('Executed 1 test, with 0 failures (0 unexpected)')==3
            and "Test Suite 'Selected tests' passed" in value and not guard and not signals and not remaining)
    normal=match[0]+"\nTest Suite 'Selected tests' passed\n"+('Executed 1 test, with 0 failures (0 unexpected)\n'*3)
    positive=[('actual interleaved log',text),('ordinary complete result',normal)]
    controls=[]
    for name,value in positive:
        assert accepts(value);controls.append(dict(name=name,expected=True,passed=True))
    negative=[('absent result',text.replace(match[0],''),{}),
        ('failed result',text.replace(match[0],match[0].replace(' passed ',' failed ')),{}),
        ('duplicate result',text+'\n'+match[0]+'\n',{}),
        ('foreign method',text,dict(name=method+'Foreign')),
        ('unterminated result',text.replace(match[0],match[0][:-1]),{}),
        ('missing summary',text.replace('Executed 1 test, with 0 failures (0 unexpected)','removed',1),{}),
        ('extra summary',text+'\nExecuted 1 test, with 0 failures (0 unexpected)',{}),
        ('missing selected pass',text.replace("Test Suite 'Selected tests' passed",'removed'),{}),
        ('nonzero exit',text,dict(code=1)),('guard',text,dict(guard=True)),
        ('signal',text,dict(signals=True)),('remaining process',text,dict(remaining=True))]
    for name,value,options in negative:
        assert not accepts(value,**options);controls.append(dict(name=name,expected=False,passed=True))
    prior=[]
    for r in queue['completed'][:57]:
        lp=artifact/(r['phase']+'.log');checked(lp,r['log']);value=lp.read_text()
        assert re.findall(OLD_PATTERN,value,re.M)==re.findall(NEW_PATTERN,value,re.M)
        assert accepts(value,name=r['method']);prior.append(dict(method=r['method'],log=pin(lp)))
    child=json.loads((artifact/'test-58.job.json').read_text());assert child['status']=='terminal' and child['exitCode']==0
    assert not child.get('guardReason') and not child.get('signals') and not child['remainingProcessGroup'] and not child['remainingObservedProcesses']
    assert not subprocess.run(['ps','-p',str(child['pid']),'-o','pid='],capture_output=True,text=True).stdout.strip()
    report=dict(UTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),oldPattern=OLD_PATTERN,newPattern=NEW_PATTERN,
        exactOneAnchorChange=NEW_PATTERN==OLD_PATTERN[1:],controls=controls,prior57ClassificationsUnchanged=prior,
        recoveredMethod=method,recoveredOrdinal=58,rawLog=dict(path=str(artifact/'test-58.log'),**pin(artifact/'test-58.log')),
        job=dict(path=str(artifact/'test-58.job.json'),**pin(artifact/'test-58.job.json')),exactNamedSpan=span,
        oldQueueUnchanged=True,oldNonpassRetained=True,recoveredPass=True,nativeRerun=False,originalExecuted=False,independentReview=False)
    path=task/'reader-recovery1.json';assert not path.exists();path.write_text(json.dumps(report,indent=2)+'\n')


def generate(name):
    old=(ROOT/'tools'/name).read_text()
    text=old.replace('application-host-match-completion-20260922',TASK_NAME).replace('application-host-match-correction1-20260922',BASE_NAME)
    text=text.replace('Pin existing typed-host products and prior passes for28 whole methods.',
        'Pin unchanged gameplay products,58 recovered passes and11 unstarted methods.')
    text=text.replace('Run the 28 remaining whole methods','Run the 11 remaining whole methods')
    text=once(text,'import datetime',f'import sys\nsys.path.append({str(ROOT/"tools")!r})\nimport datetime')
    for helper in NAMES:
        text=text.replace("ROOT/'tools/"+helper+"'",f'Path({str(GENERATED/helper)!r})')
    text=text.replace(OLD_PATTERN,NEW_PATTERN)
    if name.startswith('prepare_'):
        text=once(text,"TASK = Path('/Volumes/X5/ntsd-2.4-research/01a0c7b2-a956-7760-950e-ecf7dceaaa20/"+TASK_NAME+"')",f'TASK = Path({str(TASK)!r})')
        text=text.replace('APPLICATION_HOST_MATCH_COMPLETION_PLAN.md','APPLICATION_HOST_GAMEPLAY_COMPLETION_PLAN.md')
        text=text.replace("ARTIFACT/'test-26.job.json',ARTIFACT/'test-26.log'","ARTIFACT/'test-58.job.json',ARTIFACT/'test-58.log'")
        text=once(text,"        protected += [record(f) for f in paths]",f"        paths += [Path({str(Path(__file__).resolve())!r}),Path({str(GENERATED/'adaptation1.json')!r}),Path({str(GENERATED/NAMES[-1])!r})]\n        protected += [record(f) for f in paths]")
        text=once(text,"        assert len(queue['completed'])==26 and [r['passed'] for r in queue['completed']]==[True]*25+[False]", "        assert len(queue['completed'])==58 and [r['passed'] for r in queue['completed']]==[True]*57+[False]\n        from prepare_application_host_gameplay_completion import check_reader\n        check_reader(ARTIFACT,TASK)")
        text=text.replace('==53','==69').replace("queue['completed'][:25]","queue['completed'][:58]").replace('count=25,remaining=methods[25:]','count=58,remaining=methods[58:]')
        text=text.replace('candidateFiles=1039','candidateFiles=1040').replace('retainedPasses=25,remainingMethods=28','retainedPasses=58,remainingMethods=11')
        start=text.index("        save(TASK/'resource-contract1.json'")
        end=text.index("        save(TASK/'context1.json'",start)
        text=text[:start]+'''        queue_seconds=14400-queue['elapsedSeconds']
        assert queue_seconds>0
        save(TASK/'resource-contract1.json',dict(readerRecovery=record(TASK/'reader-recovery1.json'),retainedPasses=58,
            remainingMethods=methods[58:],residentBytes={f'test-{i:02d}':16*2**30 for i in range(59,70)},
            candidateOrExpectedChanged=False,timeLimitSeconds={f'test-{i:02d}':1800 if i>=64 else 900 for i in range(59,70)},
            queueSeconds=queue_seconds,originalQueueSeconds=14400,priorQueueSeconds=queue['elapsedSeconds'],independentReview=False))
'''+text[end:]
        text=text.replace("ARTIFACT/'test-26-config.json'","ARTIFACT/'test-59-config.json'").replace('residentGuardBytes=12*2**30','residentGuardBytes=16*2**30')
        text=text.replace('range(26,54)','range(59,70)').replace("['test-25','test-54','test-00','build1','other']","['test-58','test-70','test-00','build1','other']")
        text=text.replace("r'test-(2[6-9]|[34][0-9]|5[0-3])'","r'test-(59|6[0-9])'")
        text=text.replace('completePassParserByteIdentical=True','completePassPredicatesByteIdentical=True,resultPatternOnlyLeadingAnchorChanged=True')
        text=text.replace("TASK/'resource-contract1.json']","TASK/'resource-contract1.json',TASK/'reader-recovery1.json']")
        text=text.replace('retainedPasses=25,remaining=28','retainedPasses=58,remaining=11')
    elif name.startswith('run_application_host_match_validation'):
        text=text.replace("r'test-(2[6-9]|[34][0-9]|5[0-3])'","r'test-(59|6[0-9])'")
        text=once(text,"assert config['residentGuardBytes']==(16 if ordinal>=51 else 12 if ordinal in (26,28,35,36,37) or 43<=ordinal<=50 else 8)*2**30","assert config['residentGuardBytes']==16*2**30")
        text=once(text,"assert config['timeoutSeconds']==(900 if ordinal>=51 else 600)","assert config['timeoutSeconds']==(1800 if ordinal>=64 else 900)")
    elif name.startswith('run_application_host_match_tests'):
        text=text.replace('== 53','== 69').replace('methods[25:]','methods[58:]').replace('== 28','== 11').replace('enumerate(methods, 26)','enumerate(methods, 59)')
        text=once(text,'deadline = time.time()+7200',"deadline = time.time()+json.loads((task/'resource-contract1.json').read_text())['queueSeconds']")
        text=once(text,'timeoutSeconds=900 if index>=51 else 600, residentGuardBytes=(16 if index>=51 else 12 if index in (26,28,35,36,37) or 43<=index<=50 else 8)*2**30', 'timeoutSeconds=1800 if index>=64 else 900, residentGuardBytes=16*2**30')
        text=text.replace('all28RemainingPassed','all11RemainingPassed').replace('same exact named XCTest regex and one-test zero-failure summary as Catalog53 completion','Exact named XCTest result with only leading anchor removed; all one-test zero-failure gates unchanged')
    else:
        text=text.replace('==53','==69')
        text=once(text,"        prior=[result(A,r,True) for r in old['completed'][:25]]",'''        recovery=read(P/'reader-recovery1.json');assert recovery['recoveredPass'] and recovery['recoveredOrdinal']==58
        prior_records=[dict(r) for r in old['completed'][:58]]
        assert [r['passed'] for r in prior_records]==[True]*57+[False]
        assert prior_records[57]['method']==recovery['recoveredMethod']
        prior_records[57]['passed']=True  # Separate recovered view; immutable old queue remains false.
        prior=[result(A,r,True) for r in prior_records]''')
        text=text.replace('methods[:25]','methods[:58]').replace('methods[25:25+len(fresh)]','methods[58:58+len(fresh)]').replace('len(fresh)<=28','len(fresh)<=11').replace('len(fresh)==28','len(fresh)==11').replace('range(26+len(fresh),54)','range(59+len(fresh),70)').replace('all28RemainingPassed','all11RemainingPassed')
        text=once(text,"        prior_guard=read(A/'test-26.job.json');assert prior_guard['exitCode']==-15 and prior_guard['guardReason']=='resident bound'", "        prior_reader=read(A/'test-58.job.json');assert prior_reader['exitCode']==0 and not prior_reader.get('guardReason') and old['completed'][57]['passed'] is False")
        text=text.replace('==1039','==1040').replace('==2486','==2488').replace('candidateFilesUnchanged=1039','candidateFilesUnchanged=1040').replace('priorArtifactFilesUnchanged=2486','priorArtifactFilesUnchanged=2488')
        text=text.replace('all53Passed','all69Passed').replace('all53-passed-review-open','all69-passed-review-open')
        text=text.replace("oldGuard=record(A/'test-26.job.json'),oldGuardPreserved=True", "readerRecovery=record(P/'reader-recovery1.json'),oldReaderFailure=record(A/'failure-diagnosis1.json'),oldReaderNonpassPreserved=True")
        text=once(text,"        for n in names:shutil.copy2(ROOT/'tools'/n,P/('frozen-'+n))",f"        for n in names:shutil.copy2(Path({str(GENERATED)!r})/n,P/('frozen-'+n))")
        text=text.replace('docs/evidence/application-host-match-completion','docs/evidence/application-host-gameplay-completion')
        text=text.replace('First gameplay input inspection stops with rollback; it does not establish retained gameplay or a complete tick, match or whole Catalog53 source.','Selected host gameplay retention comparison does not establish installed whole-application, match or whole Catalog53 source equivalence.')
        text=text.replace('Actual providers/timing/devices, retained gameplay, full match and full game remain open.','Actual providers/timing/devices, installed trajectory, full match and full game remain open.')
        text=text.replace('Old assertion failure and old resident-guard termination remain immutable outcomes.','The prior compile failure and original result-reader nonpass remain immutable outcomes.')
    ast.parse(text)
    return old,text


def main():
    assert not GENERATED.exists() and not TASK.exists()
    GENERATED.mkdir()
    records=[]
    for name in NAMES:
        old,new=generate(name);path=GENERATED/name;path.write_text(new)
        records.append(dict(source=dict(path=str(ROOT/'tools'/name),**pin(ROOT/'tools'/name)),generated=dict(path=str(path),**pin(path)),
            patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=name,tofile=name))))
    (GENERATED/'adaptation1.json').write_text(json.dumps(dict(records=records,originalExecuted=False,independentReview=False),indent=2)+'\n')
    assert sum(f.stat().st_size for f in GENERATED.iterdir())<2*2**20
    result=subprocess.call([sys.executable,str(GENERATED/NAMES[0])],cwd=ROOT)
    assert result==0,result
    print(json.dumps(dict(task=str(TASK),generated=str(GENERATED),readerRecovery=dict(path=str(TASK/'reader-recovery1.json'),**pin(TASK/'reader-recovery1.json')))))


if __name__=='__main__':main()
