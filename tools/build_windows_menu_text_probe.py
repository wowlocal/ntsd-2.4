#!/usr/bin/env python3
"""Build one controlled x86 DirectDraw text observer, without executing it."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from build_windows_nls_probe import inspect_pe

ROOT = Path(__file__).resolve().parent.parent
IMPORTS = {'CreateFileW': 28, 'WriteFile': 20, 'FlushFileBuffers': 4,
           'CloseHandle': 4, 'ExitProcess': 4, 'GetLastError': 0, 'SetLastError': 4,
           'LoadLibraryExW': 12, 'FreeLibrary': 4, 'GetModuleHandleW': 4,
           'GetProcAddress': 8, 'GetModuleFileNameW': 12, 'GetCurrentProcess': 0,
           'GetACP': 0, 'GetOEMCP': 0}
INPUT_SHA = '87245df0ba78b2141b84a318eb6fdc3d4aba89a82db52bab3f34f2c158ceddb7'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--first-menu', required=True, type=Path)
    a = p.parse_args()
    assert sha(a.first_menu) == INPUT_SHA
    source = json.loads(a.first_menu.read_bytes())
    lines = [x['command']['event'] for x in source['front']
             if x['command']['event']['kind'] == 'textOut']
    assert len(lines) == 3
    for i, row in enumerate(lines):
        assert row['arguments'][1:3] == [591, 491+i*20]
        assert len(row['strings']) == 1 and row['arguments'][3] == len(row['strings'][0])
        assert all(0 < x < 128 for x in row['strings'][0])
    assert not a.output.exists()
    a.output.mkdir(parents=True); kit = a.output/'kit'; kit.mkdir()
    for name in ('probe_windows_menu_text.c', 'build_windows_menu_text_probe.py',
                 'build_windows_nls_probe.py', 'run_windows_menu_text_probe.ps1',
                 'verify_windows_menu_text_capture.py'):
        shutil.copy2(ROOT/'tools'/name, kit/name)
    shutil.copy2(ROOT/'docs/research/WINDOWS_MENU_TEXT_PROBE_PLAN.md', kit/'WINDOWS_MENU_TEXT_PROBE_PLAN.md')
    shutil.copy2(a.first_menu, kit/'first-menu1.json')
    header = '/* Generated solely from pinned first-menu1.json TextOut requests. */\n'
    for i, row in enumerate(lines):
        header += 'static const char inputText%d[]={%s,0};\n' % (i, ','.join(map(str, row['strings'][0])))
    header += 'static const char *const inputText[]={inputText0,inputText1,inputText2};\n'
    for name, pos in (('X',1),('Y',2),('Length',3)):
        header += 'static const int input%s[]={%s};\n' % (name, ','.join(str(x['arguments'][pos]) for x in lines))
    (kit/'windows_menu_text_inputs.h').write_text(header)
    clang, lld = shutil.which('clang'), shutil.which('lld-link'); assert clang and lld
    definition = a.output/'kernel32.def'
    definition.write_text('LIBRARY KERNEL32.dll\nEXPORTS\n'+'\n'.join('_%s@%d==%s' % (n,c,n) for n,c in sorted(IMPORTS.items()))+'\n')
    library, obj, exe = a.output/'kernel32.lib', a.output/'probe.obj', kit/'probe-windows-menu-text-x86.exe'
    commands = [[lld,'/lib','/machine:x86','/def:'+str(definition),'/out:'+str(library)],
                [clang,'-target','i686-pc-windows-msvc','-std=c11','-O1','-ffreestanding','-Wall','-Wextra','-Werror','-c',str(kit/'probe_windows_menu_text.c'),'-o',str(obj)],
                [lld,'/machine:x86','/entry:entry','/subsystem:console','/nodefaultlib','/dynamicbase','/nxcompat','/timestamp:0','/out:'+str(exe),str(obj),str(library)]]
    for command in commands:
        r = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if r.stdout: print(r.stdout,end='')
        assert r.returncode == 0, (command,r.returncode)
    pe = inspect_pe(exe,0x14c,IMPORTS)
    manifest = dict(schema='ntsd-windows-menu-text-build-v1', WindowsExecuted=False,
                    gameExecuted=False, fullMenu=False, firstMenuSHA256=INPUT_SHA,
                    binaries={'x86':pe}, files={f.name:dict(bytes=f.stat().st_size,sha256=sha(f))
                    for f in sorted(kit.iterdir()) if f.is_file()})
    (kit/'manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
    (a.output/'build.json').write_text(json.dumps(dict(commands=commands,manifestSHA256=sha(kit/'manifest.json'),
        commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        tools={name:dict(path=path,sha256=sha(Path(path)),version=subprocess.check_output([path,'--version'],text=True))
               for name,path in [('clang',clang),('lld-link',lld)]}),indent=2)+'\n')
    print(json.dumps(dict(output=str(a.output),PE=pe['sha256'],manifestSHA256=sha(kit/'manifest.json'),WindowsExecuted=False)))


if __name__ == '__main__': main()
