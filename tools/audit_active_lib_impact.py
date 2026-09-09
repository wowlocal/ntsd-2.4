#!/usr/bin/env python3
"""Locate bundled game-library patches in immutable pristine active controls.

The preserved NTSD2.4 EXE, bundled lib.dll installation fixture and both
48-call Unicorn2.1.4 active fixtures are the references. Decode pristine EXE
instruction bytes with local llvm-objdump and intersect their complete byte
intervals with the actual installer's13 copy ranges. This identifies affected
game stages for the next native fidelity studies, including patches inside
multi-byte instructions. It does not execute EXE/DLL code, modify any source
artifact, infer DLL outcomes or count dynamic instruction invocations. Stage
stops are excluded from the stage inventory; the broad address inventory
remains explicitly distinct. Missing overlap does not establish irrelevance.
"""
import base64
import hashlib
import json
import re
import subprocess
import zlib
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, read_bytes
from inspect_original import PE

FIXTURES = ROOT/'native/Tests/NTSDCoreTests/Fixtures'
PINS = {
    'lib-initialization': '3697e7d6c40c78fd1ae026f658c28654a4ed825bde24c087df7ad51242f0584c',
    'active-gameplay': '3b074ff960538fde6e13b1b65bda4f833b22bbc9cafcef990de12f71aaed511c',
    'active-gameplay-control': 'd3abb578f36ac74716fa6e71eb12091c6f0eed5adb02f1b59a550275c73fc0b3',
}
LIB_SHA256 = '28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
digest = lambda data: hashlib.sha256(data).hexdigest()


def fixture(name):
    path = FIXTURES/('original-'+name+'.json')
    packed = path.read_bytes()
    assert digest(packed) == PINS[name], name
    wrapper = json.loads(packed)
    raw = zlib.decompress(base64.b64decode(wrapper['deflate']), -15)
    assert len(raw) == wrapper['count'] and digest(raw) == wrapper['sha256']
    report = json.loads((ROOT/'docs/evidence'/(name+'.json')).read_bytes())
    assert digest(raw+b'\n') == report['sha256'] and len(raw)+1 == report['bytes']
    return json.loads(raw), dict(fixture=path.name, fixtureSHA256=digest(packed),
                                rawSHA256=report['sha256'], rawBytes=report['bytes'])


def audit():
    exe_path = DEFAULT_SOURCE/'NTSD 2.4.exe'
    raw = read_bytes(exe_path)
    assert digest(raw) == EXE_SHA256
    assert digest(read_bytes(DEFAULT_SOURCE/'lib.dll')) == LIB_SHA256
    pe = PE(raw)
    source, install_identity = fixture('lib-initialization')
    assert source['exeSHA256'] == EXE_SHA256 and source['libSHA256'] == LIB_SHA256
    patches = source['cases'][0]['patches']
    assert len(patches) == 13 and sum(p['count'] for p in patches) == 62
    attaches = [c for c in source['cases'] if c['patches']]
    assert len(attaches) == 4
    for case in attaches:
        assert [(p['address'],p['before'],p['after']) for p in case['patches']] == [
            (p['address'],p['before'],p['after']) for p in patches]
    for p in patches:
        offset = pe.offset(p['address']-pe.base)
        assert raw[offset:offset+p['count']].hex() == p['before']
        assert len(bytes.fromhex(p['after'])) == p['count']

    command = ['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',str(exe_path)]
    assembly = subprocess.check_output(command, text=True)
    instructions = {}
    for line in assembly.splitlines():
        m = re.match(r'\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(\S.*)', line)
        if not m:
            continue
        address = int(m[1],16)
        if not any(address < p['address']+p['count'] and address+15 > p['address'] for p in patches):
            continue
        code = bytes.fromhex(m[2])
        offset = pe.offset(address-pe.base)
        assert raw[offset:offset+len(code)] == code
        instructions[address] = dict(address=address, end=address+len(code),
                                     bytes=code.hex(), instruction=m[3].strip())

    controls = []
    for name in ('active-gameplay','active-gameplay-control'):
        control, identity = fixture(name)
        assert control['exeSHA256'] == EXE_SHA256 and len(control['cases']) == 48
        rows = []
        for p in patches:
            start,end = p['address'],p['address']+p['count']
            overlapping = {pc:ins for pc,ins in instructions.items() if pc < end and ins['end'] > start}
            assert overlapping, hex(start)
            observed = set()
            cases = []
            stages = {}
            excluded_stops = []
            for c in control['cases']:
                # An observed head must be decoded if its maximum possible
                # instruction interval reaches this patch. Do not silently
                # omit an unknown or misaligned decoder address.
                candidates = {pc for pc in c['observedOriginalAddressPCs'] if pc < end and pc+15 > start}
                assert candidates <= instructions.keys(), (name,c['index'],hex(start),candidates-instructions.keys())
                matched = set(overlapping) & set(c['observedOriginalAddressPCs'])
                if matched:
                    cases.append(dict(index=c['index'], pristineInstructionHeads=sorted(matched)))
                    observed.update(matched)
                for section in c['stages']+[c['output']]:
                    inventory = set(section['instructions'])
                    stop = section['end']['pc']
                    if stop in overlapping and stop in inventory:
                        excluded_stops.append(dict(index=c['index'],stage=section['label'],pc=stop))
                    inventory.discard(stop)
                    matched_stage = set(overlapping) & inventory
                    if matched_stage:
                        stages.setdefault(section['label'],[]).append(dict(index=c['index'], pristineInstructionHeads=sorted(matched_stage)))
            installed = bytes.fromhex(p['after'])
            destination = start+5+int.from_bytes(installed[1:],'little',signed=True) if len(installed)==5 and installed[0]==0xe9 else None
            rows.append(dict(patchAddress=start,patchBytes=p['count'],originalBytes=p['before'],
                installedBytes=p['after'],dllDestination=destination,
                overlappingPristineInstructions=[overlapping[pc] for pc in sorted(overlapping)],
                observedPristineInstructionHeads=sorted(observed),broadInventoryCaseCount=len(cases),
                broadInventoryCases=cases,stageInventoryCases=stages,excludedStageStops=excluded_stops))
        controls.append(dict(name=name,identity=identity,completeCalls=48,
            overlappingPatchSites=sum(bool(r['broadInventoryCases']) for r in rows),patches=rows))
    return dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,
        installationIdentity=install_identity,installationAttachControls=4,
        decoderCommand=command[:-1]+['<pinned NTSD 2.4.exe>'],disassemblySHA256=digest(assembly.encode()),
        controls=controls,sourceArtifactsModified=False,newGameExecution=False,
        dllGameplayCompared=False,nativeCompared=False,windowsVerified=False,
        limitation='Intersections concern instruction bytes in pristine control inventories, not execution counts or DLL branch outcomes. No overlap does not make a hook irrelevant to other inputs or prior initialization.')


if __name__ == '__main__':
    result = audit()
    path = ROOT/'docs/evidence/active-lib-impact.json'
    path.write_text(json.dumps(result,indent=2)+'\n')
    for control in result['controls']:
        print(control['name'],control['overlappingPatchSites'],'of13 patch sites overlap')
        for p in control['patches']:
            print(hex(p['patchAddress']),p['broadInventoryCaseCount'],
                  {label:len(cases) for label,cases in p['stageInventoryCases'].items()})
