#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Original HUD callee with the paused caller's preserved command flags.

Execute pinned NTSD2.4 EXE41ae60..41b12d/ret4 on Unicorn2.1.4 at CW027f,
with declared400-slot World/Actor/Object/bitmap inputs and COM responses.
Read/write/register observations distinguish the callee from421a15's command
resets and prove its ignored argument. Paused caller EDI1 and ESI=argument
are retained; EBP remains a controlled saved-register sentinel.
Full pool/masks/globals and ordered bitmap/clip/rectangle requests compare to
the native shared HUD. No whole paused caller, initialized pause, device,
pixels, source DLL or Windows execution claim.
"""
import itertools
import json
import struct
from collections import Counter
from oracle_world_hud import WorldHUD, probes, case, IDS, HEADERS, RESOURCES, HELPERS, RESULTS
from oracle_world_control import WORLD, BODY_SP, HEADER, REGS, d, digest
from oracle_world_drawing import BITMAP, TARGET, FILL_TARGET
from oracle_state import ROOT, STOP, EXE_SHA256
from unicorn.x86_const import UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_ESI, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG


class PausedHUD(WorldHUD):
    def execute(self):
        self.clip = None; self.bitmap = None; self.blit_count = 0
        self.uc.mem_write(BODY_SP-0x4000, b'\xa5'*0x4800)
        argument = self.item.get('argument', 0x12345678)
        self.uc.mem_write(BODY_SP-8, struct.pack('<II', STOP, argument))
        self.uc.mem_write(BODY_SP+0x68, struct.pack('<I', argument))
        self.uc.reg_write(UC_X86_REG_ESP, BODY_SP-8)
        self.uc.reg_write(UC_X86_REG_ECX, WORLD)
        self.uc.reg_write(UC_X86_REG_EDI, 1)
        self.uc.reg_write(UC_X86_REG_ESI, argument)
        self.uc.reg_write(UC_X86_REG_FPCW, 0x27f)
        self.uc.reg_write(UC_X86_REG_FPSW, 0)
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xffff)
        self.uc.emu_start(0x41ae60, STOP, count=1_000_000)
        # The terminal address is not an executed instruction or code hook.
        assert self.uc.reg_read(UC_X86_REG_EIP) == STOP and len(self.pending) == 1
        call = self.pending.pop()
        assert call['entry'] == 0x41ae60 and BODY_SP == call['sp']+8
        assert call['saved'] == [self.uc.reg_read(r) for r in REGS]
        self.helpers += 1
        assert self.clip is None and self.bitmap is None
        self.finished = True
        assert self.uc.reg_read(UC_X86_REG_ESP) == BODY_SP
        assert [self.uc.reg_read(r) for r in REGS] == [WORLD, 0x22334455, argument, 1]
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x27f and self.uc.reg_read(UC_X86_REG_FPSW) == 0
        assert self.uc.reg_read(UC_X86_REG_FPTAG) == 0xffff
        assert self.u32(BODY_SP-4) == self.u32(BODY_SP+0x68) == argument
        assert not self.argument_accesses, self.argument_accesses

    def code(self, uc, pc, size, data):
        if not getattr(self, 'running', False): return
        sp = uc.reg_read(UC_X86_REG_ESP)
        if pc == 0x41ae60:
            assert self.u32(sp) == STOP and self.u32(sp+4) == self.item.get('argument', 0x12345678)
            self.instructions.add(pc)
            self.pending.append(dict(entry=pc, sp=sp, pop=HELPERS[pc], returnPC=STOP, saved=[uc.reg_read(r) for r in REGS]))
            return  # Observe entry; Unicorn executes the original instruction.
        return super().code(uc, pc, size, data)


def main():
    vm = PausedHUD(); cases = []
    inputs = list(probes())
    for first, second in itertools.product((-2147483648, -1, 0, 1, 2, 2147483647), repeat=2):
        inputs.append(case('preserved-commands', (first, second), active=[[0, 1], [1, 1]],
            actors=[[0, [d(0x364, 1)]], [1, [d(0x364, 4)]]], globals=[d(0x450bb8, first), d(0x450bc0, second)]))
    for index, item in enumerate(inputs):
        cases.append(vm.probe(item, index))
        if (index+1) % 250 == 0: print('PAUSED HUD', index+1, flush=True)
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, ids=IDS, header=HEADER, headerPatches=HEADERS,
        cases=cases, instructions=sorted(vm.instructions), fpcw=0x27f, bitmapBase=BITMAP,
        drawTarget=TARGET, fillTarget=FILL_TARGET, resources=RESOURCES, methodResults=RESULTS,
        calleeOnly=True, entry=0x41ae60, returnPC=STOP, callerEDI=1, callerESIEqualsArgument=True)
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode()
    path = ROOT/'build/original/paused-hud.json'; path.write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=path.name, sha256=digest(raw), bytes=len(raw),
        cases=len(cases), groups=dict(Counter(c['group'] for c in cases)), helpers=sum(c['helpers'] for c in cases),
        instructions=len(vm.instructions), events=sum(len(c['events']) for c in cases), blits=sum(c['blits'] for c in cases),
        calleeOnly=True, fpcw=0x27f, callerEDI=1, callerESIEqualsArgument=True, nativeCompared=False, windowsVerified=False)
    (ROOT/'build/research/paused-hud.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__': main()
