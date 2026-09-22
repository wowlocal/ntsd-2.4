#!/usr/bin/env python3
"""Verify fresh native-SwiftPM products and exact declared resource payloads."""
import datetime
import json
from pathlib import Path
import subprocess
import sys
from archive_catalog53_storage import ROOT, checked, pin


def main(task, build_phase):
    assert task.name == 'application-host-loading-validation-20260922'
    output = task/'package-check1.json'
    assert not output.exists()
    assert build_phase in ('build1', 'build2', 'build3')
    job_path = task/(build_phase+'.job.json')
    job = json.loads(job_path.read_text())
    assert job['status'] == 'terminal' and job['exitCode'] == 0
    assert not job['remainingProcessGroup'] and not job['remainingObservedProcesses']
    start = datetime.datetime.fromisoformat(job['startedUTC']).timestamp()
    inputs = json.loads((task/'candidate1-inputs.json').read_text())
    for item in inputs:
        checked(task/'candidate1'/item['path'], item)
    actual = {str(p.relative_to(task/'candidate1')) for top in ('native/Sources', 'native/Tests')
              for p in (task/'candidate1'/top).rglob('*') if p.is_file()} | {'native/Package.swift'}
    assert actual == {r['path'] for r in inputs}
    release = task/'swift/arm64-apple-macosx/release'
    description = json.loads((release/'description.json').read_text())
    targets = {}
    for name, source_dir in [('NTSDCore', 'native/Sources/NTSDCore'),
                             ('NTSDReferenceChecks', 'native/Sources/NTSDReferenceChecks'),
                             ('NTSDCoreTests', 'native/Tests/NTSDCoreTests')]:
        command = description['swiftCommands']['C.'+name+'-arm64-apple-macosx-release.module']
        original_sources = {str(task/'candidate1'/r['path']) for r in inputs
                            if r['path'].startswith(source_dir+'/') and r['path'].endswith('.swift')}
        supplied = set(command['sources'])
        assert original_sources.issubset(supplied)
        generated = supplied-original_sources
        expected_generated = {str(release/(name+'.build/DerivedSources/resource_bundle_accessor.swift'))} if name != 'NTSDReferenceChecks' else set()
        assert generated == expected_generated, (name, generated)
        args = command['otherArguments']
        assert command['wholeModuleOptimization'] and args[args.index('-target')+1] == 'arm64-apple-macosx14.0'
        assert '-O' in args and '-enable-testing' in args and args[args.index('-swift-version')+1] == '5'
        outputs = []
        for value in command['objects']+[command['moduleOutputPath']]:
            f = Path(value)
            assert f.is_file() and not f.is_symlink() and f.stat().st_size > 0 and f.stat().st_mtime >= start, str(f)
            outputs.append(dict(path=str(f), **pin(f)))
        targets[name] = dict(originalSources=len(original_sources), generatedSources=sorted(generated),
                             command=command, freshOutputs=outputs)
    product = description['builtTestProducts']
    assert len(product) == 1 and product[0]['productName'] == 'NTSDNativePackageTests'
    binary = Path(product[0]['binaryPath'])
    assert binary.is_file() and binary.stat().st_mtime >= start
    bundle = binary.parents[2]
    assert bundle.suffix == '.xctest' and bundle.parent == release
    resources = []
    for name, marker, count in [('NTSDNative_NTSDCoreTests.bundle', 'native/Tests/NTSDCoreTests/', 385),
                                 ('NTSDNative_NTSDCore.bundle', 'native/Sources/NTSDCore/Resources/', 102)]:
        expected = {r['path'][len(marker):]: r for r in inputs if r['path'].startswith(marker) and
                    ('/Fixtures/' in r['path'] if 'Tests' in name else True)}
        assert len(expected) == count
        directory = release/name
        actual = {str(f.relative_to(directory)) for f in directory.rglob('*') if f.is_file()}
        assert actual == set(expected), (name, actual-set(expected), set(expected)-actual)
        for relative, record in expected.items():
            f = directory/relative
            assert not f.is_symlink()
            checked(f, {k: record[k] for k in ('bytes', 'sha256')})
            resources.append(dict(path=str(f), **pin(f)))
    linked = subprocess.check_output(['otool', '-L', str(binary)], text=True)
    assert all(value not in linked for value in ['first-damage-catalog53', 'application-host-transaction-candidate-20260922', 'application-host-loading-candidate-20260922'])
    report = dict(schema='ntsd-host-loading-native-package-check-v1', UTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        buildPhase=build_phase, buildJob=dict(path=str(job_path), **pin(job_path)),
        candidateFiles=len(inputs), allInputBytesVerified=True, sourceMembershipVerified=True,
        description=dict(path=str(release/'description.json'), **pin(release/'description.json')),
        targets=targets, binary=dict(path=str(binary), **pin(binary)), bundle=str(bundle),
        fixtureFiles=385, runtimeFiles=102, resourceFiles=resources,
        layout='native SwiftPM: two regular sibling resource bundles; no nested duplicate claimed',
        dylibs=linked, applicationWindowTested=False, independentReview=False)
    output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(dict(binaryBytes=report['binary']['bytes'], fixtureFiles=385, runtimeFiles=102,
                          targets={k:v['originalSources'] for k,v in targets.items()})))


if __name__ == '__main__':
    main(Path(sys.argv[1]).resolve(), sys.argv[2])
