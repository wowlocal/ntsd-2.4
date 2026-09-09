#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continue both initialized matches through the whole HUD caller to421a2d.

Same original CPU/stack, fresh startup/menu/catalog/selection and gameplay.
No new game inputs or expected state injection. Actual41ae60,43f010,43ef70,
43f310 execute; inherited COM Blt remains an explicit response boundary.
Complete parent/state/metadata events and FPU audit; no pixel/Windows claim.
"""
import argparse
import json
import struct
from oracle_gameplay_commands import GameplayCommands, initialized, FRAME_KINDS
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, REGISTERS, digest, capture_startup, transport
from oracle_front_screen_prelude import PAPI
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI,
                              UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

HELPERS = {0x41ae60: (1, 4), 0x43f010: (6, 24), 0x43ef70: (6, 0), 0x43f310: (7, 28)}
RESOURCES = [0x4511a8, 0x44faf4, 0x44f888, 0x44fcbc, 0x44fb68, 0x44faf8, 0x44fd7c]
signed = lambda value: (value+0x80000000)%0x100000000-0x80000000


class GameplayHUD(GameplayCommands):
    def hud_active(self):
        return getattr(self, 'gameplay_running', False) and self.gameplay_label == 'world-hud'

    def drawing_active(self):
        # Reuse the already-installed original bitmap metadata observer. Its
        # preceding World drawing behavior and event stream remain unchanged.
        return self.hud_active() or super().drawing_active()

    def imported(self, uc, pc, size, data):
        if not self.hud_active():
            return super().imported(uc, pc, size, data)

    def checkpoint(self, uc, pc, size, data):
        if not self.hud_active():
            return super().checkpoint(uc, pc, size, data)

    def hud_argument_access(self, uc, access, address, size, value, data):
        if self.hud_active():
            self.hud_argument_accesses.append(dict(pc=uc.reg_read(UC_X86_REG_EIP), offset=address-self.body_sp,
                                                   size=size, write=access == UC_MEM_WRITE))

    def gameplay_code(self, uc, pc, size, data):
        if not self.hud_active():
            return super().gameplay_code(uc, pc, size, data)
        self.gameplay_instructions.add(pc)
        sp = uc.reg_read(UC_X86_REG_ESP)
        arg = lambda n: self.u32(sp+4+4*n)
        while self.gameplay_pending and pc == self.gameplay_pending[-1]['returnPC']:
            h = self.gameplay_pending.pop()
            assert sp == h['entrySP']+4+h['pop'] and h['saved'] == [uc.reg_read(r) for r in REGISTERS], h
            h.update(returnSP=sp, result=uc.reg_read(UC_X86_REG_EAX)); self.gameplay_helpers.append(h)
            if h['entry'] in (0x43f010, 0x43f310):
                self.drawing_bitmap = None
        if self.drawing_clip and pc == self.drawing_clip['returnPC']:
            h = self.drawing_clip; self.drawing_clip = None
            assert uc.reg_read(UC_X86_REG_EAX) in (0, 1)
            self.drawing_event('clip', clip=dict(beforeSource=h['source'], beforeDestination=h['destination'],
                source=[signed(self.u32(p)) for p in h['src']], destination=[signed(self.u32(p)) for p in h['dst']],
                visible=uc.reg_read(UC_X86_REG_EAX) == 1))
        if pc == self.gameplay_stop:
            assert not self.gameplay_pending and self.drawing_clip is None and self.drawing_bitmap is None
            assert uc.reg_read(UC_X86_REG_EDI) == 0
            self.gameplay_finished = True; uc.emu_stop(); return
        if pc in HELPERS:
            count, pop = HELPERS[pc]
            self.gameplay_pending.append(dict(entry=pc, entrySP=sp, returnPC=self.u32(sp), pop=pop,
                this=uc.reg_read(UC_X86_REG_ECX), arguments=[arg(i) for i in range(count)], saved=[uc.reg_read(r) for r in REGISTERS]))
        if pc == 0x41ae60:
            assert self.u32(sp) == 0x421a2d and arg(0) == self.hud_argument
            assert self.u32(0x450bb8) == self.u32(0x450bc0) == 0
        elif pc in (0x43f010, 0x43f310):
            pointer = uc.reg_read(UC_X86_REG_ECX)
            assert pointer in self.drawing_bitmap_tokens
            self.drawing_bitmap = pointer
            self.drawing_event('draw' if pc == 0x43f010 else 'rectangle',
                               [self.drawing_bitmap_tokens[pointer], *[arg(i) for i in range(6 if pc == 0x43f010 else 7)]])
        elif pc == 0x43ef70:
            assert self.drawing_clip is None
            src = [arg(i) for i in range(4)]
            dst = [uc.reg_read(UC_X86_REG_ECX), uc.reg_read(UC_X86_REG_EDI), arg(4), arg(5)]
            self.drawing_clip = dict(returnPC=self.u32(sp), src=src, dst=dst,
                source=[signed(self.u32(p)) for p in src], destination=[signed(self.u32(p)) for p in dst])
        elif pc == PAPI:
            assert arg(0) == self.u32(0x455608) and arg(5) == 0
            self.drawing_event('blit', blit=dict(sourceSurface=arg(2), targetSurface=arg(0),
                source=list(struct.unpack('<4i', uc.mem_read(arg(3), 16))),
                destination=list(struct.unpack('<4i', uc.mem_read(arg(1), 16))), flags=arg(4), effects=None))
            result = self.drawing_blits%2; self.drawing_blits += 1
            self.ret(result, 24); return
        assert any(a <= pc <= z for a, z in [(0x421a15, 0x421a28), (0x41ae60, 0x41b12d), (0x43ef70, 0x43f37a)]), hex(pc)

    def capture_character(self, parent):
        old = super().capture_character(parent)
        suffix = '-control' if self.control else ''
        report = json.loads((ROOT/'docs/evidence'/('gameplay-commands'+suffix+'.json')).read_bytes())
        raw = (ROOT/'build/original'/report['corpus']).read_bytes()
        assert digest(raw) == report['sha256'] and len(raw) == report['bytes']
        assert json.loads(raw) == json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes()) == report['fixtureSHA256']
        print('Entire pinned GAMEPLAY_COMMANDS reproduced; continuing whole HUD caller', flush=True)
        self.drawing_events = []; self.drawing_clip = None; self.drawing_bitmap = None; self.drawing_blits = 0
        self.drawing_target = self.u32(0x455608)
        self.hud_argument = self.u32(self.body_sp+0x68)
        self.hud_argument_accesses = []
        for offset in (-4, 0x68):
            self.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, self.hud_argument_access,
                             begin=self.body_sp+offset, end=self.body_sp+offset+3)
        for pc in (0x421a15, 0x41ae60, 0x41ae70):
            self.uc.hook_add(UC_HOOK_CODE, self.early.observe_fpu, begin=pc, end=pc)
        initialized.CHECKPOINTS.update((0x421a15, 0x41ae60, 0x41ae70))
        drawing = dict(target=self.drawing_target, resourceSurfaces={self.u32(g): self.u32(self.u32(g)) for g in RESOURCES},
            mode=self.u32(0x451160), surfaces=[self.u32(b['address']) for b in self.bitmaps], drawResults=[0, 1], fillResult=0, fillInputs=[])
        def heap():
            return [dict(address=a['address'], kind=FRAME_KINDS[a['caller']], storage=self.record(self.region(a['address'], a['size'])))
                    for a in self.allocations if a['caller'] in FRAME_KINDS]
        def menu():
            return [dict(address=r['address'], storage=self.record(r)) for r in self.menu_bitmaps]
        cw, sw, tag = [self.uc.reg_read(r) for r in (UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)]
        before_heap, before_menu = heap(), menu()
        section = self.gameplay_step('world-hud', 0x421a15, 0x421a2d)
        section['before'].update(frameHeap=before_heap, menuBitmaps=before_menu)
        section['after'].update(frameHeap=heap(), menuBitmaps=menu())
        drawing.update(events=self.drawing_events); section['drawing'] = drawing
        section['hud'] = dict(argument=self.hud_argument, retainedAfter=self.u32(self.body_sp+0x68),
            argumentAccesses=self.hud_argument_accesses, fpcw=cw, fpswBefore=sw, fpswAfter=self.uc.reg_read(UC_X86_REG_FPSW),
            fptagBefore=tag, fptagAfter=self.uc.reg_read(UC_X86_REG_FPTAG))
        assert self.hud_argument_accesses == [dict(pc=0x421a15, offset=0x68, size=4, write=False),
                                             dict(pc=0x421a19, offset=-4, size=4, write=True)]
        assert self.u32(self.body_sp-4) == self.hud_argument == self.u32(self.body_sp+0x68)
        assert cw == self.uc.reg_read(UC_X86_REG_FPCW) == 0x23f and not self.early.fpu_pending
        return transport(dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, control=self.control,
            parent=dict(fixture=report['fixture'], sha256=report['fixtureSHA256']), fpu=self.early.audit(), worldAddress=WORLD,
            actorAddresses=[r['address'] for r in self.pool], objectAddresses=self.object_addresses, cases=[section]),
            {**self.early.blobs, **self.blobs})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--control', action='store_true'); args = parser.parse_args()
    suffix = '-control' if args.control else ''
    doc = capture_startup(args.control, vm_type=GameplayHUD, early_type=initialized.InitializedEarlyMenus,
        after=lambda vm, parent: vm.capture_screen(parent, after_first=lambda vm, first:
            vm.capture_return(first, after_cycle=lambda vm, cycle: vm.capture_character(cycle))))
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode(); path = ROOT/'build/original'/('gameplay-hud'+suffix+'.json'); path.write_bytes(raw)
    c = doc['cases'][0]
    report = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, corpus=path.name, sha256=digest(raw), bytes=len(raw),
        parent=doc['parent'], helpers=len(c['helpers']), instructions=len(c['instructions']), events=len(c['drawing']['events']), end=c['end'],
        readsBeforeWrites=c['readsBeforeWrites'], argumentAccesses=c['hud']['argumentAccesses'], fpcw=c['hud']['fpcw'],
        fpuCheckpoints=len(doc['fpu']['checkpoints']), nativeCompared=False, windowsVerified=False)
    (ROOT/'build/research'/path.name).write_text(json.dumps(report, indent=2)+'\n'); print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
