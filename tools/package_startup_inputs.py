#!/usr/bin/env python3
"""Extract the pinned NTSD startup data package; no original code is executed.

Only PE data/zero-fill and 36 DIB resources plus seven original files are copied.
No trace, expected after-state, synthetic reply, EXE or DLL enters the package.
"""
import argparse
import hashlib
import json
from pathlib import Path
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE, ROOT, EXE_SHA256, read_bytes

BITMAPS = ['CS2','CS3','CS4','CS5','CS6','ENDING','FRAME','LF2_CURSOR'] + ['MENU_BACK'+str(i) for i in range(1,14)] + ['MENU_CLIP'] + ['MENU_CLIP'+str(i) for i in range(2,8)] + ['MENU_WAIT','SLOGAN'] + ['WORDS'+str(i) for i in range(6)]
FILES = ['data/adinfo.txt','data/control.txt'] + ['data/m_'+n+'.wav' for n in ['join','ok','cancel','pass','end']]

def digest(data): return hashlib.sha256(data).hexdigest()

def payloads(source):
    exe = read_bytes(source/'NTSD 2.4.exe')
    if digest(exe) != EXE_SHA256: raise ValueError('Unexpected reference EXE')
    pe = PE(exe);start = 0x44d000;count = 0xc3a8
    data = bytearray(count);mask = bytearray(count);spans = []
    for section in pe.sections:
        address = pe.base+section['rva'];extent = max(section['virtualSize'],section['fileSize'])
        first,last = max(start,address),min(start+count,address+extent)
        if first >= last: continue
        if section['name'] != '.data': raise ValueError('Initial region outside declared .data')
        for i in range(first,last):
            offset = i-address
            if mask[i-start]: raise ValueError('Overlapping PE sections')
            data[i-start] = exe[section['fileOffset']+offset] if offset < section['fileSize'] else 0
            mask[i-start] = 1
        spans.append(dict(section=section,address=first,count=last-first))
    if not all(mask): raise ValueError('Initial region has unknown provenance')
    output = {'initial.bin':bytes(data),'initial.mask':bytes(mask)}
    resources = {tuple(r['path']):r for r in pe.resources()}
    origins = {}
    for name in sorted(BITMAPS):
        r = resources[(2,name,1028)];path = 'bitmaps/'+name+'.dib'
        output[path] = exe[r['fileOffset']:r['fileOffset']+r['size']]
        origins[path] = dict(resourcePath=r['path'],rva=r['rva'],fileOffset=r['fileOffset'],count=r['size'])
    for name in FILES: output[name] = read_bytes(source/name)
    if (source/'data/ad0.txt').exists(): raise ValueError('Declared optional ad0 file is no longer absent')
    manifest = dict(version=1,exeSHA256=EXE_SHA256,globalAddress=start,globalCount=count,
        absentFiles=['data/ad0.txt'],controlProjection='baseline CRLF to LF only',
        entries=[dict(path=k,count=len(v),sha256=digest(v)) for k,v in sorted(output.items())],
        provenance=dict(globalSpans=spans,embedded=origins,originalFiles=sorted(FILES)))
    output['manifest.json'] = (json.dumps(manifest,sort_keys=True,indent=2)+'\n').encode()
    assert len(output)==46
    return output

def package(output,source=DEFAULT_SOURCE):
    expected = payloads(Path(source));output = Path(output)
    if output.exists():
        actual = {p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file()}
        if actual != set(expected): raise ValueError('Existing package has a different file set: '+str(output))
        for name,data in expected.items():
            p = output/name
            if p.is_symlink() or p.read_bytes()!=data: raise ValueError('Existing package differs: '+str(p))
    else:
        output.mkdir(parents=True)
        for name,data in expected.items():
            p = output/name;p.parent.mkdir(parents=True,exist_ok=True)
            with p.open('xb') as f:f.write(data)
    return dict(files=len(expected),bytes=sum(map(len,expected.values())),manifestSHA256=digest(expected['manifest.json']))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,default=DEFAULT_SOURCE)
    p.add_argument('--output',type=Path,default=ROOT/'native/Sources/NTSDCore/Resources/OriginalStartup')
    a=p.parse_args();print(json.dumps(package(a.output,a.source)))
