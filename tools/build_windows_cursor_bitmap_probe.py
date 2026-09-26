#!/usr/bin/env python3
"""Build the finite LF2_CURSOR Windows API observer; never execute a PE."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from build_windows_nls_probe import inspect_pe

ROOT = Path(__file__).resolve().parent.parent
IMPORTS = {
    'CreateFileW': 28, 'WriteFile': 20, 'FlushFileBuffers': 4, 'CloseHandle': 4,
    'ExitProcess': 4, 'GetLastError': 0, 'SetLastError': 4, 'LoadLibraryExW': 12,
    'FreeLibrary': 4, 'GetModuleHandleW': 4, 'GetProcAddress': 8,
    'GetModuleFileNameW': 12, 'GetCurrentProcess': 0, 'FindResourceA': 12,
    'LoadResource': 8, 'LockResource': 4, 'SizeofResource': 8,
    'GetACP': 0, 'GetOEMCP': 0,
}
EXE_SHA = '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
RESOURCE_SHA = '9382aac33a46878e4d94f1aea332fbd06a1508a21ee38b46be5149b9bbff39b8'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--clang', default=shutil.which('clang'))
    p.add_argument('--lld-link', default=shutil.which('lld-link'))
    a = p.parse_args()
    assert a.clang and a.lld_link
    out = a.output.absolute()
    assert not out.exists(), 'Refusing to overwrite a previous build'
    out.mkdir(parents=True); kit = out / 'kit'; kit.mkdir()
    for name in ('probe_windows_cursor_bitmap.c', 'build_windows_cursor_bitmap_probe.py',
                 'build_windows_nls_probe.py', 'run_windows_cursor_bitmap_probe.ps1',
                 'verify_windows_cursor_bitmap_capture.py'):
        shutil.copyfile(ROOT / 'tools' / name, kit / name)
    shutil.copyfile(ROOT / 'docs/research/WINDOWS_CURSOR_BITMAP_PROBE_PLAN.md',
                    kit / 'WINDOWS_CURSOR_BITMAP_PROBE_PLAN.md')
    commands, binaries = [], {}
    def run(args):
        commands.append(args)
        r = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if r.stdout: print(r.stdout, end='')
        assert r.returncode == 0, (args, r.returncode)
    for arch, target, machine in (('x86', 'i686-pc-windows-msvc', 0x14c),
                                  ('arm64', 'aarch64-pc-windows-msvc', 0xaa64)):
        work = out / arch; work.mkdir()
        definition = work / 'kernel32.def'
        names = ['_%s@%d==%s' % (n, count, n) if arch == 'x86' else n
                 for n, count in sorted(IMPORTS.items())]
        definition.write_text('LIBRARY KERNEL32.dll\nEXPORTS\n' + '\n'.join(names) + '\n')
        lib = work / 'kernel32.lib'; obj = work / 'probe.obj'
        exe = kit / ('probe-windows-cursor-bitmap-' + arch + '.exe')
        run([a.lld_link, '/lib', '/machine:' + arch, '/def:' + str(definition), '/out:' + str(lib)])
        run([a.clang, '-target', target, '-std=c11', '-O1', '-ffreestanding',
             '-Wall', '-Wextra', '-Werror', '-c', str(kit / 'probe_windows_cursor_bitmap.c'), '-o', str(obj)])
        run([a.lld_link, '/machine:' + arch, '/entry:entry', '/subsystem:console',
             '/nodefaultlib', '/dynamicbase', '/nxcompat', '/timestamp:0',
             '/out:' + str(exe), str(obj), str(lib)])
        binaries[arch] = inspect_pe(exe, machine, IMPORTS)
    manifest = dict(schema='ntsd-windows-cursor-bitmap-build-v1', windowsExecuted=False,
                    gameExecuted=False, nativeCompared=False, referenceEXESHA256=EXE_SHA,
                    resourceName='LF2_CURSOR', resourceSHA256=RESOURCE_SHA,
                    files={f.name: dict(bytes=f.stat().st_size, sha256=sha(f))
                           for f in sorted(kit.iterdir()) if f.is_file()}, binaries=binaries)
    (kit / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    metadata = dict(commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    commands=commands, tools={n: dict(path=p, sha256=sha(Path(p)),
                    version=subprocess.check_output([p, '--version'], text=True).strip())
                    for n, p in (('clang', a.clang), ('lld-link', a.lld_link))},
                    manifestSHA256=sha(kit / 'manifest.json'), windowsExecuted=False)
    (out / 'build.json').write_text(json.dumps(metadata, indent=2, sort_keys=True) + '\n')
    print(json.dumps(dict(output=str(out), manifestSHA256=metadata['manifestSHA256'],
                         binaries={k: dict(bytes=v['bytes'], sha256=v['sha256'])
                                   for k, v in binaries.items()}, windowsExecuted=False), indent=2))


if __name__ == '__main__':
    main()
