#!/usr/bin/env python3
"""Adapt the frozen gameplay validation tools for the one-signature correction.

No reference execution. Generated copies retain the existing monitor/comparator.
Old tools, candidates and failures are never edited.
"""
import ast
import datetime
import difflib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
from prepare_application_host_candidate import pin, same

ROOT = Path(__file__).resolve().parents[1]
OLD_NAME = 'application-host-gameplay-validation-20260922'
NAME = 'application-host-gameplay-correction1-20260926'
TASK = Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/NAME
GENERATED = ROOT/'build/research'/f'{NAME}-tools'
NAMES = ['prepare_application_host_gameplay_validation.py',
         'run_application_host_gameplay_validation.py',
         'run_application_host_gameplay_tests.py',
         'verify_application_host_gameplay_package.py',
         'finalize_application_host_gameplay_validation.py']


def once(text, before, after):
    assert text.count(before) == 1, before
    return text.replace(before, after)


def load(name):
    spec = importlib.util.spec_from_file_location(name, GENERATED/(name+'.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def generate(name):
    original = (ROOT/'tools'/name).read_text()
    text = original.replace(OLD_NAME, NAME)
    # Resolve unchanged shared pin/archive helpers from the repository.
    marker = 'import ctypes' if name.startswith(('prepare_', 'finalize_')) else 'import datetime'
    text = once(text, marker, f'import sys\nsys.path.append({str(ROOT/"tools")!r})\n{marker}')
    for helper in NAMES:
        text = text.replace("ROOT/'tools/"+helper+"'", f'Path({str(GENERATED/helper)!r})')
    if name.startswith('prepare_'):
        text = once(text, 'ROOT = Path(__file__).resolve().parents[1]', f'ROOT = Path({str(ROOT)!r})')
        text = once(text, "TASK = Path('/Volumes/X5/ntsd-2.4-research/01a0c7b2-a956-7760-950e-ecf7dceaaa20/"+NAME+"')", f'TASK = Path({str(TASK)!r})')
        text = text.replace('APPLICATION_HOST_GAMEPLAY_VALIDATION_PLAN.md', 'APPLICATION_HOST_GAMEPLAY_CORRECTION1_PLAN.md')
        text = once(text, '    TASK.mkdir()', '''    failed = ROOT/'build/research/application-host-gameplay-validation-20260922'
    assert json.loads((failed/'external-close1.json').read_text())['taskFrozen']
    for item in candidate:
        same(failed/'candidate1'/item['path'], item)
    source_job_path = source_path.parent/'capture1/source.job.json'
    source_job = json.loads(source_job_path.read_text())
    assert source_job['status'] == 'terminal' and source_job['exitCode'] == 0
    assert not subprocess.run(['ps','-p',str(source_job['pid']),'-o','pid=,lstart=,command='],capture_output=True,text=True).stdout.strip()
    assert not subprocess.run(['lsof','-a','-p',str(source_job['pid']),'-d','cwd','-Fn'],capture_output=True,text=True).stdout.strip()
    TASK.mkdir()''')
        text = once(text, "        actual = {str(p.relative_to(TASK/'candidate1'))", '''        shutil.copy2(BASE/'candidate1-inputs.json', TASK/'baseline-inputs1.json')
        changed = 'native/Tests/NTSDCoreTests/OriginalApplicationActiveOutputTests.swift'
        destination = TASK/'candidate1'/changed
        before = destination.read_text()
        old = '    func sequence(_ reverse: Bool) throws {'
        new = '    func sequence(_ reverse: Bool, driver: OriginalApplicationLoadedTestDriver? = nil) throws {'
        assert before.count(old) == 1
        after = before.replace(old, new)
        destination.write_text(after)
        import difflib
        patch = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=changed, tofile=changed))
        (TASK/'correction1.patch').write_text(patch)
        candidate = [dict(pin(TASK/'candidate1'/r['path']), path=r['path']) for r in candidate]
        (TASK/'candidate1-inputs.json').write_text(json.dumps(candidate, indent=2)+'\\n')
        correction = dict(path=changed, before=pin(BASE/'candidate1'/changed), after=pin(destination),
            exactBeforeDeclaration=old, exactAfterDeclaration=new, onlyDeclarationChanged=after.replace(new,old)==before)
        (TASK/'correction1.json').write_text(json.dumps(correction,indent=2)+'\\n')
        actual = {str(p.relative_to(TASK/'candidate1'))''')
        text = once(text, "for name in ['candidate1-inputs.json', 'selected-methods1.json']:", "for name in ['selected-methods1.json']:")
        text = once(text, "        context = dict(schema=", f'''        protected_paths += [failed/'publication1.json', failed/'external-close1.json',
            failed/'candidate1-inputs.json', failed/'failure-diagnosis1.json',
            source_job_path, Path({str(Path(__file__).resolve())!r}),
            Path({str(GENERATED/'adaptation1.json')!r})]
        context = dict(schema=''')
        text = once(text, "            rootManifest=str(root_manifest)", "            failedCandidate=str((failed/'candidate1').resolve()), baselineManifest=str(TASK/'baseline-inputs1.json'),\n            rootManifest=str(root_manifest)")
    elif name.startswith('finalize_'):
        text = once(text, "        for item in candidate:checked(Path(context['candidateSource'])/item['path'], item)", '''        baseline = read(Path(context['baselineManifest']))
        for item in baseline:
            checked(Path(context['candidateSource'])/item['path'], item)
            checked(Path(context['failedCandidate'])/item['path'], item)
        changed = [r['path'] for r,b in zip(candidate,baseline) if r['sha256'] != b['sha256']]
        assert changed == ['native/Tests/NTSDCoreTests/OriginalApplicationActiveOutputTests.swift']
        correction = read(task/'correction1.json')
        before = (Path(context['candidateSource'])/changed[0]).read_text()
        after = (task/'candidate1'/changed[0]).read_text()
        assert after.replace(correction['exactAfterDeclaration'], correction['exactBeforeDeclaration']) == before''')
        start = "        source_identity = subprocess.check_output(['ps'"
        end = "        with (source/'capture1/source.stdout.log').open('rb') as stream:"
        a, b = text.index(start), text.index(end)
        text = text[:a]+'''        source_identity = subprocess.run(['ps', '-p', str(source_job['pid']), '-o', 'pid=,lstart=,command='], capture_output=True, text=True).stdout.strip()
        source_cwd = subprocess.run(['lsof', '-a', '-p', str(source_job['pid']), '-d', 'cwd', '-Fn'], capture_output=True, text=True).stdout.strip()
        assert source_job['status'] == 'terminal' and source_job['exitCode'] == 0 and not source_identity and not source_cwd
'''+text[b:]
        text = once(text, "            shutil.copy2(ROOT/'tools'/name, task/('frozen-'+name))", f"            shutil.copy2(Path({str(GENERATED)!r})/name, task/('frozen-'+name))")
        text = text.replace('docs/evidence/application-host-gameplay-validation', 'docs/evidence/application-host-gameplay-correction1')
        text = once(text, "            candidateUnchanged=True, previousCandidateManifest=", "            candidateUnchanged=True, candidateUnchangedMeaning='Corrected candidate unchanged since fresh build; exact one-declaration delta verified against both prior candidates', correction=pin(task/'correction1.json'), previousCandidateManifest=")
    ast.parse(text)
    return original, text


def main():
    assert not GENERATED.exists() and not TASK.exists()
    # The mounted volume and reserve checks remain in the reused preparation.
    TASK.parent.mkdir(parents=True, exist_ok=True)
    GENERATED.mkdir()
    records = []
    for name in NAMES:
        old, new = generate(name)
        path = GENERATED/name
        path.write_text(new)
        records.append(dict(source=pin(ROOT/'tools'/name), generated=pin(path),
            patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=name,tofile=name))))
    report = dict(UTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  records=records, originalExecuted=False, independentReview=False)
    (GENERATED/'adaptation1.json').write_text(json.dumps(report,indent=2)+'\n')
    assert sum(p.stat().st_size for p in GENERATED.iterdir()) < 2*2**20
    runner = load('run_application_host_gameplay_validation')
    old_runner = (ROOT/'tools'/NAMES[1]).read_text()
    new_runner = (GENERATED/NAMES[1]).read_text()
    begin, end = '    def identity(pid):', "if __name__=='__main__':"
    assert old_runner[old_runner.index(begin):old_runner.index(end)] == new_runner[new_runner.index(begin):new_runner.index(end)]
    t = TASK
    assert runner.owned_cwd(f'p123\nfcwd\nn{t}/candidate1',123,t)
    for v,pid in [(f'p124\nfcwd\nn{t}',123), ('',123), ('p123\nfcwd\nn/tmp',123), (f'p123\nfcwd\nn{t}-foreign',123)]:
        assert not runner.owned_cwd(v,pid,t)
    prefix = '123 Fri Sep 26 00:00:00 2026 '
    compiler = '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/'
    cwd = f'p123\nfcwd\nn{t}/candidate1'
    assert runner.compiler_transition(prefix+compiler+'swift-build',prefix+compiler+'swift-frontend',cwd,cwd,t)
    assert not runner.compiler_transition(prefix+compiler+'swift-build',prefix+'/bin/sh',cwd,cwd,t)
    assert not runner.compiler_transition(prefix+compiler+'swift-build',prefix+compiler+'swift-frontend',cwd,'',t)
    assert runner.transient_xctest_exit(prefix+'/Applications/Xcode.app/Contents/Developer/usr/bin/xctest a',prefix+'(xctest)','')
    assert not runner.transient_xctest_exit(prefix+'/bin/sh',prefix+'(xctest)','')
    pattern = r'build[123]|test-(0[1-9]|[1-6][0-9])'
    for phase in ['build1','build2','build3']+[f'test-{i:02d}' for i in range(1,70)]:
        assert re.fullmatch(pattern,phase)
    for phase in ['build0','build4','test-00','test-70','test-99','test-1','test-01x','other']:
        assert not re.fullmatch(pattern,phase)
    code = subprocess.call([sys.executable,str(GENERATED/NAMES[0])],cwd=ROOT)
    assert code == 0, code
    methods = json.loads((TASK/'selected-methods1.json').read_text())['methods']
    assert len(methods) == len(set(methods)) == 69
    for name in methods:
        cls, method = name.split('/')
        text = (TASK/'candidate1/native/Tests/NTSDCoreTests'/(cls+'.swift')).read_text()
        assert len(re.findall(r'func\s+'+method+r'\s*\(',text)) == 1, name
    pins = [pin(GENERATED/n) for n in NAMES]+[pin(ROOT/'tools/archive_catalog53_storage.py')]
    (TASK/'runner-inputs1.json').write_text(json.dumps(pins,indent=2)+'\n')
    controls = dict(UTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        monitorBodyUnchanged=True,cwdPositive=1,cwdNegative=4,compilerPositive=1,compilerNegative=2,
        transientPositive=1,transientNegative=1,phasePositive=72,phaseNegative=8,exactMethods=69,
        originalExecuted=False,nativeExecuted=False,independentReview=False)
    (TASK/'runner-controls1.json').write_text(json.dumps(controls,indent=2)+'\n')
    print(json.dumps(dict(task=str(TASK),generated=str(GENERATED),buildConfig=pin(TASK/'build1-config.json'))))


if __name__ == '__main__':
    main()
