#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute original445a31/CRT before the own World/menu/loading/gameplay chain.

One retained CPU executes the real initializer and subsequent game instructions.
Initial CW037f, outer caller ABI, CRT PTD and device/thread/FILE boundaries are
declared. This is not the full PE startup or an actual Windows thread capture.
All historical whole-state comparisons remain active and must reproduce before
accepting the new initialized continuation. No old expected state seeds gameplay.
"""
import argparse
import json
import re
import subprocess
from collections import Counter

from oracle_crt import DLL_SHA256, prepare
from import_ntsd import DEFAULT_SOURCE
from oracle_gameplay_impulses import GameplayImpulses
from oracle_gameplay_entry import ROOT, EXE_SHA256, digest, capture_startup
from oracle_menu_loading import EarlyMenus
from oracle_settings_loading import SettingsLoading
from oracle_front_menu_resources import REGISTERS, GLOBAL, GLOBAL_SIZE
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDX,
    UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_EFLAGS, UC_X86_REG_FPCW, UC_X86_REG_FPSW)

CHECKPOINTS = {0x419e40, 0x4246b0, 0x427089, 0x42709b, 0x41bc90, 0x4122f0,
    0x41c581, 0x429e5a, 0x42cf8a, 0x42d6ed, 0x41e339, 0x41e634, 0x41eed1,
    0x41eef0, 0x41f0dd, 0x41f400, 0x41f484, 0x41f496, 0x41f4ac, 0x41f550}


class InitializedEarlyMenus(EarlyMenus):
    last_instance = None

    def __init__(self, control=False):
        type(self).last_instance = self
        self.initialization_active = False
        self.initialization_instructions = set()
        self.fpu_checkpoints = []
        self.fpu_transitions = []
        self.fpu_pending = {}
        self.fpu_operations = {}
        super().__init__(control)

    def attach_crt(self):
        if not hasattr(self, 'crt'):
            SettingsLoading.attach_crt(self)

    def observe_fpu(self, uc, pc, size, data):
        cw, sw = uc.reg_read(UC_X86_REG_FPCW), uc.reg_read(UC_X86_REG_FPSW)
        if pc in self.fpu_pending:
            item = self.fpu_pending.pop(pc)
            item.update(after=cw, fpswAfter=sw)
            self.fpu_transitions.append(item)
        if pc in self.fpu_operations:
            expected, operation = self.fpu_operations[pc]
            assert bytes(uc.mem_read(pc, size)) == expected and pc + size not in self.fpu_pending
            self.fpu_pending[pc + size] = dict(pc=pc, operation=operation, before=cw, fpswBefore=sw)
        if pc in CHECKPOINTS:
            assert cw == self.expected_fpcw, (hex(pc), hex(cw))
            self.fpu_checkpoints.append(dict(pc=pc, sp=uc.reg_read(UC_X86_REG_ESP), fpcw=cw, fpsw=sw))

    def before_world_constructor(self):
        self.attach_crt()
        assert next(i for i in self.pe.imports() if i['name'] == '_controlfp_s')['iatVA'] == '0x004470f0'
        # Disassembly identifies candidate state-changing instructions. Verify
        # their bytes against the mapped pinned images before installing hooks.
        pattern = re.compile(r'^([0-9a-f]+):\s+((?:[0-9a-f]{2}\s+)+)\s*(fninit|finit|fldcw|fldenv|frstor|fxrstor|xrstor|fnsave|fsave|fnstenv|fstenv)\b', re.M)
        hooks = set(CHECKPOINTS)
        for path, sha in ((DEFAULT_SOURCE / 'NTSD 2.4.exe', EXE_SHA256), (prepare(), DLL_SHA256)):
            assert digest(path.read_bytes()) == sha
            assembly = subprocess.check_output(['xcrun', 'llvm-objdump', '--disassemble', '--x86-asm-syntax=intel', str(path)], text=True)
            for match in pattern.finditer(assembly):
                pc, raw, operation = int(match[1], 16), bytes.fromhex(match[2]), match[3]
                assert bytes(self.uc.mem_read(pc, len(raw))) == raw
                self.fpu_operations[pc] = (raw, operation)
                hooks.update((pc, pc + len(raw)))
        assert len(self.fpu_operations) > 40 and 0x7814b118 in self.fpu_operations
        for pc in sorted(hooks):
            self.uc.hook_add(UC_HOOK_CODE, self.observe_fpu, begin=pc, end=pc)
        self.put(0x4470f0, 0x7814a7e9)
        registers = [*REGISTERS, UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDX,
                     UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_EFLAGS]
        saved = [self.uc.reg_read(r) for r in registers]
        globals_before = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        self.uc.reg_write(UC_X86_REG_FPCW, 0x37f)
        self.uc.reg_write(UC_X86_REG_FPSW, 0)
        self.put(STACK + 0x6000, STOP)
        self.uc.reg_write(UC_X86_REG_ESP, STACK + 0x6000)
        self.initialization_active = True
        try:
            self.uc.emu_start(0x445a31, STOP, count=10000)
            assert self.uc.reg_read(UC_X86_REG_EIP) == STOP
            assert self.uc.reg_read(UC_X86_REG_ESP) == STACK + 0x6004
            assert self.uc.reg_read(UC_X86_REG_EAX) == 0
        finally:
            self.initialization_active = False
        self.expected_fpcw = self.uc.reg_read(UC_X86_REG_FPCW)
        assert self.expected_fpcw == 0x23f and not self.fpu_pending
        assert bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE)) == globals_before
        self.fpu_initialization = dict(entry=0x445a31, entrySP=STACK + 0x6000,
            returnPC=STOP, returnSP=STACK + 0x6004, before=0x37f, after=self.expected_fpcw,
            result=0, instructions=sorted(self.initialization_instructions))
        # The separate World caller supplies its own integer ABI. Keep the
        # initialized FPU and actual DLL/stack writes on this same CPU.
        for r, value in zip(registers, saved):
            self.uc.reg_write(r, value)
        print('INITIALIZED FPU 037f -> 023f;', len(self.initialization_instructions), 'original instructions', flush=True)

    def code(self, uc, pc, size, data):
        if self.initialization_active:
            assert pc == STOP or 0x445a31 <= pc <= 0x445a59 or pc == 0x445b16 or 0x78130000 <= pc < 0x78230000, hex(pc)
            self.initialization_instructions.add(pc)
            return
        super().code(uc, pc, size, data)

    def audit(self):
        return dict(initialization=getattr(self, 'fpu_initialization', None),
            checkpoints=self.fpu_checkpoints, transitions=self.fpu_transitions,
            watchedInstructions=[dict(pc=pc, bytes=raw.hex(), operation=op)
                                 for pc, (raw, op) in sorted(self.fpu_operations.items())])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--control', action='store_true')
    args = p.parse_args()
    suffix = '-control' if args.control else ''
    name = 'initialized-gameplay' + suffix
    try:
        doc = capture_startup(args.control, vm_type=GameplayImpulses, early_type=InitializedEarlyMenus,
            after=lambda vm, parent: vm.capture_screen(parent, after_first=lambda vm, first:
                vm.capture_return(first, after_cycle=lambda vm, cycle: vm.capture_character(cycle))))
    except Exception:
        early = InitializedEarlyMenus.last_instance
        if early is not None:
            (ROOT / 'build/research' / (name + '-failed-audit.json')).write_text(json.dumps(early.audit(), indent=2) + '\n')
        raise
    early = InitializedEarlyMenus.last_instance
    assert not early.fpu_pending and doc['cases'][0]['end']['pc'] == 0x41f550
    doc.update(scope=__doc__,fpu=early.audit())
    raw = (json.dumps(doc, separators=(',', ':')) + '\n').encode()
    path = ROOT / 'build/original' / (name + '.json')
    path.write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__,
        corpus=path.name, sha256=digest(raw), bytes=len(raw), parent=doc['parent'],
        fpcw=early.expected_fpcw, initializationInstructions=len(early.initialization_instructions),
        checkpoints=len(early.fpu_checkpoints), transitions=len(early.fpu_transitions),
        transitionKinds=dict(Counter(f"{x['pc']:x}:{x['before']:04x}->{x['after']:04x}" for x in early.fpu_transitions)),
        nativeCompared=False, windowsVerified=False, end=doc['cases'][0]['end'])
    (ROOT / 'build/research' / path.name).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
