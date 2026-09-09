#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole original text catalog with explicit53-bit game/scanner CPUs.

All137 Objects,17 backgrounds and25 stages use real loader/CRT instructions.
The established standalone scanf boundary remains separate from the EXE CPU;
both now explicitly select CW027f. Every original %lf call also executes in
fresh persistent unwritten and explicit64-bit scanner controls. File/allocator/
device/thread boundaries remain supplied. No Windows or whole-match claim.
"""
import base64
import json
import zlib
from collections import Counter
from import_ntsd import ROOT, EXE_SHA256
from oracle_crt import CRT, DLL_SHA256
from oracle_loaded_catalog import LoadedCatalog, FRAME_KINDS
from oracle_bitmap_drawing import digest
from unicorn.x86_const import UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG, UC_X86_REG_ESP


def context(uc, cw):
    uc.reg_write(UC_X86_REG_FPCW, cw)
    uc.reg_write(UC_X86_REG_FPSW, 0)
    uc.reg_write(UC_X86_REG_FPTAG, 0xffff)


class Scanner:
    def __init__(self, owner, scanner):
        self.owner, self.scanner, self.uc = owner, scanner, scanner.uc
        self.unwritten, self.extended = CRT(), CRT()
        assert self.unwritten.uc.reg_read(UC_X86_REG_FPCW) == 0
        context(self.uc, 0x27f)
        context(self.extended.uc, 0x37f)
        self.formats, self.numeric, self.sources = Counter(), [], {}

    def scan(self, data, fmt):
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x27f
        result = self.scanner.scan(data, fmt)
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x27f
        assert (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7 == 0
        assert self.uc.reg_read(UC_X86_REG_FPTAG) == 0xffff
        self.formats[fmt.decode()] += 1
        if fmt == b'%lf':
            vm = self.owner
            sp = vm.uc.reg_read(UC_X86_REG_ESP)
            handle = vm.handles[vm.u32(sp + 4)]
            assert handle['data'][handle['pos']:] == data and vm.pending is not None
            source = digest(handle['data'])
            if source not in self.sources:
                raw = handle['data']
                self.sources[source] = dict(count=len(raw), deflate=base64.b64encode(zlib.compress(raw, 9, wbits=-15)).decode())
            control = self.unwritten.scan(data, fmt)
            extended = self.extended.scan(data, fmt)
            assert self.unwritten.uc.reg_read(UC_X86_REG_FPCW) == 0
            assert self.extended.uc.reg_read(UC_X86_REG_FPCW) == 0x37f
            assert all(result['outputs'][i] == '' for i in range(1, 8))
            self.numeric.append(dict(index=len(self.numeric), kind=vm.pending['kind'], path=vm.pending['path'],
                source=source, offset=handle['pos'], caller=vm.u32(sp), destination=vm.u32(sp + 12),
                result=result, unwritten=control, precision64=extended))
        if sum(self.formats.values()) % 100000 == 0:
            print('CATALOG53', sum(self.formats.values()), 'scans', len(self.numeric), 'numeric', flush=True)
        return result


def main():
    previous = json.loads((ROOT / 'docs/evidence/loaded-catalog.json').read_bytes())['corpora'][0]
    previous_raw = (ROOT / 'build/original' / previous['corpus']).read_bytes()
    assert digest(previous_raw) == previous['corpusSHA256']
    assert digest((ROOT / 'native/Tests/NTSDCoreTests/Fixtures' / previous['fixture']).read_bytes()) == previous['fixtureSHA256']
    historical = dict(corpus=previous['corpus'], corpusSHA256=previous['corpusSHA256'],
                      fixture=previous['fixture'], sha256=previous['fixtureSHA256'])
    vm = LoadedCatalog()
    context(vm.uc, 0x27f)
    scanner = Scanner(vm, vm.crt)
    assert scanner.uc is not vm.uc
    vm.crt = scanner
    doc = vm.run()
    assert vm.uc.reg_read(UC_X86_REG_FPCW) == scanner.uc.reg_read(UC_X86_REG_FPCW) == 0x27f
    assert len(doc['objectAddresses']) == 137 and len(doc['children']) == 155
    raw = (json.dumps(doc, separators=(',', ':')) + '\n').encode()
    path = ROOT / 'build/original/loaded-catalog53-full.json'
    path.write_bytes(raw)
    old = json.loads(previous_raw)
    changed = [key for key in sorted(set(doc) | set(old)) if doc.get(key) != old.get(key)]
    audit = dict(gameControlWord=0x27f, scannerControlWord=0x27f, scannerSharesGameCPU=False,
        formats=dict(scanner.formats), numericCases=len(scanner.numeric), historical=historical,
        changedHistoricalFields=changed, fullCorpus=path.name, fullSHA256=digest(raw), fullBytes=len(raw))
    # The full original capture remains intact on disk. The native transport
    # retains all loaded records/blobs and mirror events, as in the historical
    # catalog study; scanf results have their own complete comparison below.
    compact = {k: v for k, v in doc.items() if k not in ('scans', 'readsBeforeWrites', 'events')}
    compact['events'] = [e for e in doc['events'] if e['kind'] == 'mirror-blit']
    compact.update(scope=__doc__, precision=audit)
    numeric = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, precision=audit,
        cases=scanner.numeric, blobs=scanner.sources)
    for name, value in [('loaded-catalog53', compact), ('dat-numeric53', numeric)]:
        raw = (json.dumps(value, separators=(',', ':')) + '\n').encode()
        path = ROOT / 'build/original' / (name + '.json')
        path.write_bytes(raw)
        report = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, corpus=path.name,
            sha256=digest(raw), bytes=len(raw), precision=audit, nativeCompared=False, windowsVerified=False)
        if name == 'loaded-catalog53':
            report.update(objects=137, backgrounds=17, stages=len(doc['stageIDs']), phases=len(doc['phaseIDs']),
                frames=sum(c.get('frameOccurrences', 0) for c in doc['children']), bitmaps=len(doc['bitmaps']),
                allocations=sum(a['caller'] in FRAME_KINDS for a in doc['allocations']), checksum=doc['checksum'])
        else:
            report.update(cases=len(scanner.numeric), sourceFiles=len(scanner.sources),
                kinds=dict(Counter(c['kind'] for c in scanner.numeric)),
                changedFromUnwritten=sum(c['result'] != c['unwritten'] for c in scanner.numeric),
                changedFrom64=sum(c['result'] != c['precision64'] for c in scanner.numeric))
        (ROOT / 'build/research' / path.name).write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
