#!/usr/bin/env python3
"""Pin/copy immutable Core+codec and build one isolated native bridge product."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
MAIN = Path('/Users/michael/Developer/ntsd-2.4')
REVISION = 'ab0db06c6f0a6162f1935a1badbfc2a750822096'
UUID = '3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548'
BUILD_LIMIT = 2 * 1024**3
RESERVE = 6 * 1024**3


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def storage_check():
    storage = ROOT / 'build/l2df-prototype'
    volume = plistlib.loads(subprocess.check_output(['diskutil', 'info', '-plist', '/Volumes/X5']))
    assert volume['VolumeUUID'] == UUID and volume['MountPoint'] == '/Volumes/X5'
    assert storage.is_symlink() and storage.resolve().is_relative_to(Path('/Volumes/X5'))
    assert shutil.disk_usage('/Volumes/X5').free >= RESERVE + BUILD_LIMIT
    return storage.resolve(), {'uuid': UUID, 'freeBytes': shutil.disk_usage('/Volumes/X5').free, 'reserveBytes': RESERVE}


def directory_size(path):
    return sum(p.stat().st_size for p in path.rglob('*') if p.is_file() and not p.is_symlink())


def verify_package(root):
    manifest = json.loads((root / 'inputs.json').read_text())
    package = root / 'package'
    expected = {}
    copied_inputs = 0
    for pin in manifest['pins']:
        if 'copy' not in pin:
            continue
        copied = Path(pin['copy'])
        assert sha(copied) == pin['sha256'], copied
        copied_inputs += 1
        if copied.is_relative_to(package):
            expected[copied] = pin['sha256']
    for relative in ['Package.swift', 'Sources/NTSDNativeBridge/Bridge.swift']:
        expected[package / relative] = sha(root / 'wrapper-inputs' / relative)
    actual = {p for p in (package / 'Sources').rglob('*') if p.is_file()}
    actual.add(package / 'Package.swift')
    assert actual == set(expected), 'Actual compiled source/manifest file set differs'
    for path, expected_sha in expected.items():
        assert not path.is_symlink() and sha(path) == expected_sha, path
    return {'pass': True, 'compiledFiles': len(expected), 'copiedInputs': copied_inputs,
            'compiledFilesAndManifest': [{'path': str(p), 'sha256': value} for p, value in sorted(expected.items())]}


def run_owned(command, cwd, output, timeout, env=None, size_root=None):
    """Same retained job/Popen pattern as l2df/run.py; one child, no retries."""
    output.mkdir(parents=True, exist_ok=False)
    with (output / 'stdout.log').open('wb') as log:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        start = subprocess.check_output(['ps', '-p', str(process.pid), '-o', 'lstart='], text=True).strip()
        job = {'command': command, 'cwd': str(cwd), 'pid': process.pid, 'processStart': start,
               'createdAtUTC': now(), 'state': 'running', 'limitSeconds': timeout,
               'sizeLimitBytes': BUILD_LIMIT if size_root else None, 'output': str(output)}
        write_json(output / 'job.json', job)
        print(json.dumps(job), flush=True)
        began = time.monotonic()
        while process.poll() is None:
            reason = None
            if time.monotonic() - began > timeout:
                reason = 'time limit'
            if size_root and directory_size(size_root) > BUILD_LIMIT:
                reason = 'build size limit'
            if shutil.disk_usage('/Volumes/X5').free < RESERVE:
                reason = 'storage reserve'
            if reason:
                # Revalidate this owned, still-live child before signaling its
                # own process group; never inspect/act on earlier app jobs.
                observed = subprocess.check_output(['ps', '-p', str(process.pid), '-o', 'lstart='], text=True).strip()
                assert observed == start and os.getpgid(process.pid) == process.pid
                job['terminationReason'] = reason
                write_json(output / 'job.json', job)
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    observed = subprocess.check_output(['ps', '-p', str(process.pid), '-o', 'lstart='], text=True).strip()
                    assert observed == start and os.getpgid(process.pid) == process.pid
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                break
            time.sleep(1)
        job.update(state='terminal', exitCode=process.wait(), endedAtUTC=now(), elapsedSeconds=time.monotonic()-began)
        write_json(output / 'job.json', job)
        print(json.dumps(job), flush=True)
        return job


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    assert args.label and Path(args.label).name == args.label and args.label not in ('.', '..')
    storage, volume = storage_check()
    root = storage / 'native-bridge-20260912' / args.label
    root.mkdir(parents=True, exist_ok=False)
    package = root / 'package'
    package.mkdir()
    actual_revision = subprocess.check_output(['git', '-C', str(MAIN), 'rev-parse', 'HEAD'], text=True).strip()
    assert actual_revision == REVISION, 'Revisit source pins if main has advanced'
    tree = subprocess.check_output(['git', '-C', str(MAIN), 'ls-tree', '-rz', REVISION,
                                    'native/Sources/NTSDCore', 'native/Sources/NTSDReplayCodec', 'native/Package.swift'])
    pins = []
    for entry in tree.split(b'\0'):
        if not entry:
            continue
        metadata, name = entry.split(b'\t')
        mode, kind, blob = metadata.decode().split()
        assert kind == 'blob' and mode in ('100644', '100755')
        source = MAIN / name.decode()
        assert source.is_file() and not source.is_symlink()
        raw = source.read_bytes()
        assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == blob, source
        pin = {'path': str(source), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(), 'gitBlob': blob}
        if source.name != 'Package.swift':
            target = package / source.relative_to(MAIN / 'native')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
            assert sha(target) == pin['sha256']
            pin['copy'] = str(target)
        pins.append(pin)
    wrapper = root / 'wrapper-inputs'
    wrapper.mkdir()
    for source in sorted(HERE.rglob('*')):
        if not source.is_file() or '__pycache__' in source.parts:
            continue
        target = wrapper / source.relative_to(HERE)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        pins.append({'path': str(source), 'copy': str(target), 'bytes': source.stat().st_size, 'sha256': sha(source)})
    shutil.copy2(wrapper / 'Package.swift', package / 'Package.swift')
    shutil.copytree(wrapper / 'Sources/NTSDNativeBridge', package / 'Sources/NTSDNativeBridge')
    plan = ROOT / 'docs/research/L2DF_NATIVE_BRIDGE.md'
    shutil.copy2(plan, root / 'plan.md')
    pins.append({'path': str(plan), 'copy': str(root / 'plan.md'), 'bytes': plan.stat().st_size, 'sha256': sha(plan)})
    manifest = {'createdAtUTC': now(), 'sourceRevision': REVISION, 'storage': volume, 'pins': pins,
                'swiftVersion': subprocess.check_output(['swift', '--version'], text=True).strip(),
                'macOS': subprocess.check_output(['sw_vers'], text=True).strip(),
                'architecture': subprocess.check_output(['uname', '-m'], text=True).strip(),
                'scope': 'Unbound constructor storage only; no match/tick; no original execution'}
    write_json(root / 'inputs.json', manifest)
    command = ['swift', 'build', '--package-path', str(package), '--scratch-path', str(root / 'swift-build'),
               '--cache-path', str(root / 'cache'), '--config-path', str(root / 'config'),
               '--security-path', str(root / 'security'), '--manifest-cache', 'local',
               '-c', 'release', '--product', 'NTSDNativeBridge', '-j', '4']
    job = run_owned(command, package, root / 'build-job', 300, size_root=root)
    if job['exitCode'] != 0 or job.get('terminationReason'):
        raise SystemExit('Build did not pass; inspect retained job before another run')
    write_json(root / 'package-verification.json', verify_package(root))
    library = root / 'swift-build/release/libNTSDNativeBridge.dylib'
    assert library.is_file()
    artifact = {'library': str(library.resolve()), 'sha256': sha(library), 'bytes': library.stat().st_size,
                'file': subprocess.check_output(['file', str(library)], text=True).strip(),
                'dependencies': subprocess.check_output(['otool', '-L', str(library)], text=True),
                'exports': subprocess.check_output(['nm', '-gU', str(library)], text=True),
                'totalBuildBytes': directory_size(root), 'inputManifestSHA256': sha(root / 'inputs.json')}
    write_json(root / 'artifact.json', artifact)
    print(json.dumps({k:v for k,v in artifact.items() if k not in ('exports','dependencies')}), flush=True)


if __name__ == '__main__':
    main()
