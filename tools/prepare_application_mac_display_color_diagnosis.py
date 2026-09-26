"""Prepare one bounded host-only color probe using the existing process monitor."""
import ast, datetime, difflib, json, os, plistlib, shutil, subprocess, sys
from pathlib import Path
from archive_catalog53_storage import ROOT, checked, pin

NAME = 'application-mac-display-color-diagnosis-20260926'
OLD = (ROOT/'build/research/application-mac-display-correction1-20260926').resolve()
P = OLD.parent/NAME
read = lambda p: json.loads(p.read_text())
record = lambda p: dict(path=str(p.resolve()), **pin(p))
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()

def save(name, value):
    p = P/name
    assert not p.exists()
    p.write_text(json.dumps(value, indent=2)+'\n')

def main():
    volume = plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
    assert volume['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and volume['Writable'] and volume['FilesystemType']=='apfs'
    free = shutil.disk_usage(OLD.parent).free
    assert free > 65*2**30 and shutil.disk_usage(ROOT).free > 9*2**30
    assert read(OLD/'external-close1.json')['taskFrozen']
    for n in ['prepare1.job.json','build1.job.json','tests1-queue.job.json','finalize1.job.json']:
        j=read(OLD/n)
        assert j['status']=='terminal' and not subprocess.run(['ps','-p',str(j['pid']),'-o','pid='],capture_output=True,text=True).stdout.strip()
    base=read(OLD/'context1.json')
    for root, manifest in [(ROOT,Path(base['rootManifest'])),(OLD/'candidate1',OLD/'candidate1-inputs.json')]:
        for row in read(manifest): checked(root/row['path'],row)
    for row in base['sourceCodePins']: checked(ROOT/row['path'],row)
    assert not P.exists()
    P.mkdir(); (ROOT/'build/research'/NAME).symlink_to(P,target_is_directory=True)
    for name in ['candidate1','tools','tmp','modules']: (P/name).mkdir()
    plan=ROOT/'docs/research/APPLICATION_MAC_DISPLAY_COLOR_DIAGNOSIS_PLAN.md'
    for src,dst in [(plan,'plan1.md'),(Path(__file__),'prepare1.py'),(ROOT/'tools/probe_application_mac_display_color.swift','candidate1/probe.swift')]:
        shutil.copy2(src,P/dst)
    source=(OLD/'tools/run_application_host_gameplay_validation.py').read_text()
    adapted=source.replace(OLD.name,NAME).replace("r'build1|test-(0[1-9]|[12][0-9]|3[0-4])'", "r'build1|probe1'")
    begin=adapted.index("    if config['kind']=='build':")
    end=adapted.index('    volume=plistlib.loads',begin)
    adapted=adapted[:begin]+'''    if config['kind']=='build':
        assert phase=='build1' and Path(config['command'][0]).name=='swiftc'
        assert config['command'][-4:]==['-o',str(P/'probe1'),'-module-cache-path',str(P/'modules')]
    else:
        assert config['kind']=='probe' and phase=='probe1'
        assert read(P/'build1.job.json')['exitCode']==0
        checked(P/'probe1',read(P/'probe1-binary.json'))
        assert config['command']==[str(P/'probe1'),str(P/'result1.json')]
'''+adapted[end:]
    marker='    def identity(pid):'
    assert source[source.index(marker):]==adapted[adapted.index(marker):]
    ast.parse(adapted)
    (P/'tools/monitor.py').write_text(adapted)
    save('adaptation1.json',dict(original=record(OLD/'tools/run_application_host_gameplay_validation.py'),generated=record(P/'tools/monitor.py'),monitorBodyUnchanged=True,patch=''.join(difflib.unified_diff(source.splitlines(True),adapted.splitlines(True)))))
    save('candidate1-inputs.json',[dict(path='probe.swift',**pin(P/'candidate1/probe.swift'))])
    env={k:os.environ[k] for k in ['HOME','USER','LOGNAME','LANG','LC_ALL'] if k in os.environ}
    env.update(PATH='/usr/bin:/bin:/usr/sbin:/sbin',TMPDIR=str(P/'tmp'))
    protected=[plan,Path(__file__),ROOT/'tools/probe_application_mac_display_color.swift',P/'plan1.md',P/'prepare1.py',P/'adaptation1.json',OLD/'failure-diagnosis1.json',OLD/'publication1.json',OLD/'external-close1.json',OLD/'candidate1-inputs.json',ROOT/'AGENTS.md',ROOT/'AGENTS_HISTORY_2026-09-12.md',ROOT/'docs/research/WORKFLOW.md',ROOT/'docs/evidence/codex-safety-incidents-2026-09-12.json']
    parent=OLD/'candidate1/native'
    for n in ['Sources/NTSDMacPlatform/OriginalMacDisplayBackend.swift','Sources/NTSDMacPlatform/OriginalMacWindowBackend.swift','Tests/NTSDCoreTests/OriginalMacDisplayBackendTests.swift']: protected.append(parent/n)
    sdk=Path(subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip())
    for n in ['NSView','NSWindow','NSBitmapImageRep','NSColor','NSColorSpace']: protected.append(sdk/f'System/Library/Frameworks/AppKit.framework/Headers/{n}.h')
    save('context1.json',dict(UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),protected=[record(p) for p in protected],sourceTask=base['sourceTask'],sourceCodePins=base['sourceCodePins'],rootManifest=base['rootManifest'],startFree=free,physicalAllowanceBytes=4*2**30,stopObservedDecrease=3*2**30,environment=env,sdk=str(sdk),swiftVersion=subprocess.check_output(['xcrun','swift','--version'],text=True),gitStatus=subprocess.check_output(['git','status','--porcelain'],text=True)))
    save('runner-inputs1.json',[record(P/'tools/monitor.py'),record(ROOT/'tools/archive_catalog53_storage.py')])
    swift=subprocess.check_output(['xcrun','--find','swiftc'],text=True).strip()
    for phase,kind,command,seconds,rss in [
        ('build1','build',[swift,'-parse-as-library',str(P/'candidate1/probe.swift'),'-o',str(P/'probe1'),'-module-cache-path',str(P/'modules')],300,4),
        ('probe1','probe',[str(P/'probe1'),str(P/'result1.json')],120,2)]:
        save(phase+'-config.json',dict(phase=phase,kind=kind,command=command,cwd=str(P/'candidate1'),environment=env,contextSHA256=pin(P/'context1.json')['sha256'],candidateManifestSHA256=pin(P/'candidate1-inputs.json')['sha256'],stopObservedDecrease=3*2**30,externalGuardBytes=57*2**30,internalGuardBytes=6*2**30,logicalLimitBytes=8*2**30,residentGuardBytes=rss*2**30,timeoutSeconds=seconds,pollSeconds=1,rssPollSeconds=2,logicalPollSeconds=15))
    save('prepare1.job.json',dict(UTC=now(),status='terminal',exitCode=0,pid=os.getpid(),identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=str(Path.cwd()),nativeExecuted=False,originalExecuted=False))
    print(json.dumps(dict(task=str(P),buildConfig=record(P/'build1-config.json'))))

if __name__=='__main__': main()
