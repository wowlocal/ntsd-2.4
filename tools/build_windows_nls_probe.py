#!/usr/bin/env python3
"""Build the bounded Windows NLS research collector; never execute a PE.

Uses local clang/lld, no Windows SDK/CRT or downloaded code. Inspect actual PE
imports, relocatable/non-executable-data flags and architecture, then pin every
kit file. See docs/research/WINDOWS_REFERENCE_PLAN.md. Build-only evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parent.parent
IMPORTS = {
    'CreateFileW': 28, 'WriteFile': 20, 'FlushFileBuffers': 4, 'CloseHandle': 4,
    'ExitProcess': 4, 'GetLastError': 0, 'SetLastError': 4, 'GetStringTypeW': 16,
    'GetCPInfo': 8, 'MultiByteToWideChar': 24, 'WideCharToMultiByte': 32,
    'LCMapStringW': 24, 'GetACP': 0, 'GetOEMCP': 0, 'GetThreadLocale': 0,
    'GetSystemDefaultLCID': 0, 'GetUserDefaultLCID': 0, 'GetModuleHandleW': 4,
    'GetProcAddress': 8, 'GetModuleFileNameW': 12, 'GetCurrentProcess': 0,
    'GetVersionExW': 4,
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect_pe(path, machine):
    b = path.read_bytes()
    def u16(o): return struct.unpack_from('<H', b, o)[0]
    def u32(o): return struct.unpack_from('<I', b, o)[0]
    def string(o): return b[o:b.index(b'\0', o)].decode('ascii')
    assert b[:2] == b'MZ'
    pe = u32(0x3c)
    assert b[pe:pe + 4] == b'PE\0\0' and u16(pe + 4) == machine
    assert u32(pe + 8) == 0, 'Non-deterministic PE timestamp'
    opt = pe + 24
    size = 4 if machine == 0x14c else 8
    assert u16(opt) == (0x10b if size == 4 else 0x20b)
    assert u16(opt + 68) == 3, 'Console collector required'
    flags = u16(opt + 70)
    assert flags & 0x140 == 0x140, 'ASLR/NX must be retained'
    sections = []
    for i in range(u16(pe + 6)):
        o = opt + u16(pe + 20) + i * 40
        n, va, rawsize, raw = (u32(o + x) for x in (8, 12, 16, 20))
        characteristics = u32(o + 36)
        assert characteristics & 0xa0000000 != 0xa0000000, 'Writable code section'
        sections.append(dict(name=b[o:o + 8].rstrip(b'\0').decode(), rva=va,
                             virtualSize=n, rawSize=rawsize, rawOffset=raw,
                             characteristics=characteristics))
    def offset(va):
        for s in sections:
            if s['rva'] <= va < s['rva'] + s['rawSize']:
                return s['rawOffset'] + va - s['rva']
        raise ValueError(('RVA outside file-backed section', va))
    directories = opt + (96 if size == 4 else 112)
    assert not u16(pe + 22) & 1, 'Relocations must not be marked stripped'
    # ARM64 uses image-relative code/data references and can need no base
    # relocations. x86 absolute references in this collector do require them.
    has_relocations = bool(u32(directories + 5 * 8))
    assert machine == 0xaa64 or has_relocations
    imports = []
    descriptor = offset(u32(directories + 8))
    while any(b[descriptor:descriptor + 20]):
        dll = string(offset(u32(descriptor + 12)))
        cursor = offset(u32(descriptor))
        while True:
            thunk = int.from_bytes(b[cursor:cursor + size], 'little')
            if not thunk: break
            assert not thunk >> (size * 8 - 1), 'Unexpected ordinal import'
            imports.append(dict(dll=dll, name=string(offset(thunk) + 2)))
            cursor += size
        descriptor += 20
    assert {i['dll'].lower() for i in imports} == {'kernel32.dll'}
    assert sorted(i['name'] for i in imports) == sorted(IMPORTS)
    return dict(machine=machine, pointerBits=size * 8, entryRVA=u32(opt + 16),
                dllCharacteristics=flags, imports=imports, sections=sections,
                hasBaseRelocations=has_relocations,
                bytes=len(b), sha256=sha(path), windowsExecuted=False)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--clang', default=shutil.which('clang'))
    p.add_argument('--lld-link', default=shutil.which('lld-link'))
    a = p.parse_args()
    assert a.clang and a.lld_link, 'Local clang and lld-link required'
    out = a.output.absolute()
    assert not out.exists(), 'Refusing to replace previous build'
    out.mkdir(parents=True)
    kit = out / 'kit'; kit.mkdir()
    for name in ('probe_windows_nls.c', 'run_windows_nls_probe.ps1',
                 'verify_windows_nls_capture.py', 'build_windows_nls_probe.py'):
        shutil.copyfile(ROOT / 'tools' / name, kit / name)
    shutil.copyfile(ROOT / 'docs/research/WINDOWS_REFERENCE_PLAN.md', kit / 'WINDOWS_REFERENCE_PLAN.md')
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
        exe = kit / ('probe-windows-nls-' + arch + '.exe')
        run([a.lld_link, '/lib', '/machine:' + arch, '/def:' + str(definition), '/out:' + str(lib)])
        run([a.clang, '-target', target, '-std=c11', '-O1', '-ffreestanding',
             '-Wall', '-Wextra', '-Werror', '-c', str(kit / 'probe_windows_nls.c'), '-o', str(obj)])
        run([a.lld_link, '/machine:' + arch, '/entry:entry', '/subsystem:console',
             '/nodefaultlib', '/dynamicbase', '/nxcompat', '/timestamp:0',
             '/out:' + str(exe), str(obj), str(lib)])
        binaries[arch] = inspect_pe(exe, machine)
    files = {f.name: dict(bytes=f.stat().st_size, sha256=sha(f))
             for f in sorted(kit.iterdir()) if f.is_file()}
    manifest = dict(schema='ntsd-windows-nls-build-v1', windowsExecuted=False,
                    nativeCompared=False, files=files, binaries=binaries)
    (kit / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    metadata = dict(commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    commands=commands, tools={name: dict(path=path, sha256=sha(Path(path)),
                    version=subprocess.check_output([path, '--version'], text=True).strip())
                    for name, path in (('clang', a.clang), ('lld-link', a.lld_link))},
                    manifestSHA256=sha(kit / 'manifest.json'), windowsExecuted=False)
    (out / 'build.json').write_text(json.dumps(metadata, indent=2, sort_keys=True) + '\n')
    print(json.dumps(dict(output=str(out), manifestSHA256=sha(kit / 'manifest.json'),
                         binaries={k: dict(bytes=v['bytes'], sha256=v['sha256'])
                                   for k, v in binaries.items()}, windowsExecuted=False), indent=2))


if __name__ == '__main__':
    main()
