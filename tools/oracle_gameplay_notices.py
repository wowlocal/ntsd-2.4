#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh initialized GAMEPLAY_HUD -> whole421a2d..421cdc on same CPU/stack.
No game-state injection, no diagnostic/key flag changes. Real EXE/VC80 and
text/fill/bitmap children when selected; GDI/COM/PTD remain explicit boundaries.
Keep complete parent and own state/FPU, plus caller-local access provenance.
No app, full-tick, Windows, hardware-FPU or pixel claim.
"""
import argparse
import json
import struct
from oracle_gameplay_hud import GameplayHUD, initialized, FRAME_KINDS
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, REGISTERS, digest, capture_startup, transport
from oracle_front_screen_body import BAPI
from oracle_front_screen_prelude import PAPI
from oracle_posthud_notices import FORMAT_ADDRESSES, FORMAT_WORDS
from oracle_crt import PTD, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

START, END = 0x421a2d, 0x421cdc
HELPERS = {0x401290: (6, 0), 0x415160: (5, 0), 0x43f010: (6, 24), 0x43ef70: (6, 0)}
signed = lambda v: (v+0x80000000)%0x100000000-0x80000000


class GameplayNotices(GameplayHUD):
    def notices_active(self):
        return getattr(self, 'gameplay_running', False) and self.gameplay_label == 'post-hud-notices'

    def drawing_active(self):
        return self.notices_active() or super().drawing_active()

    def imported(self, uc, pc, size, data):
        if not self.notices_active(): return super().imported(uc, pc, size, data)

    def checkpoint(self, uc, pc, size, data):
        if not self.notices_active(): return super().checkpoint(uc, pc, size, data)

    def notices_access(self, uc, access, address, size, value, data):
        if not self.notices_active(): return
        assert self.body_sp+0x46c <= address and address+size <= self.body_sp+0x5c4
        self.notice_accesses.append(dict(pc=uc.reg_read(UC_X86_REG_EIP), offset=address-self.body_sp, size=size, write=access == UC_MEM_WRITE))
        if access == UC_MEM_WRITE:
            start = address-self.body_sp-0x46c
            self.notice_written[start:start+size] = b'\1'*size

    def gameplay_code(self, uc, pc, size, data):
        if not self.notices_active(): return super().gameplay_code(uc, pc, size, data)
        self.gameplay_instructions.add(pc)
        sp = uc.reg_read(UC_X86_REG_ESP); arg = lambda n: self.u32(sp+4+4*n)
        while self.gameplay_pending and pc == self.gameplay_pending[-1]['returnPC']:
            h = self.gameplay_pending.pop()
            assert sp == h['entrySP']+4+h['pop'] and h['saved'] == [uc.reg_read(r) for r in REGISTERS], h
            h.update(returnSP=sp, result=uc.reg_read(UC_X86_REG_EAX)); self.gameplay_helpers.append(h)
            if h['entry'] == 0x7817775d:
                count = signed(h['result']); assert 0 <= count < 1024
                raw = bytes(uc.mem_read(h['arguments'][0], count+1)); assert raw[-1] == 0
                fmt = self.cstr(h['arguments'][1])
                self.drawing_events.append(dict(kind='format', arguments=[count], strings=[list(fmt), list(raw[:-1])]))
            elif h['entry'] == 0x43f010: self.drawing_bitmap = None
        if self.drawing_clip and pc == self.drawing_clip['returnPC']:
            h = self.drawing_clip; self.drawing_clip = None
            self.drawing_event('clip', clip=dict(beforeSource=h['source'], beforeDestination=h['destination'],
                source=[signed(self.u32(p)) for p in h['src']], destination=[signed(self.u32(p)) for p in h['dst']], visible=uc.reg_read(UC_X86_REG_EAX) == 1))
        if pc == self.gameplay_stop:
            assert not self.gameplay_pending and self.drawing_clip is None and self.drawing_bitmap is None
            self.gameplay_finished = True; uc.emu_stop(); return
        if pc == 0x7817775d or pc in HELPERS:
            count, pop = (FORMAT_WORDS[FORMAT_ADDRESSES.index(arg(1))]+2, 0) if pc == 0x7817775d else HELPERS[pc]
            self.gameplay_pending.append(dict(entry=pc, entrySP=sp, returnPC=self.u32(sp), pop=pop,
                this=uc.reg_read(UC_X86_REG_ECX), arguments=[arg(i) for i in range(count)], saved=[uc.reg_read(r) for r in REGISTERS]))
            if pc == 0x7817775d: assert arg(0) == self.body_sp+0x48c
            elif pc == 0x401290:
                self.drawing_events.append(dict(kind='text', arguments=[arg(0), *[arg(i) for i in range(2, 6)]], strings=[list(self.cstr(arg(1)))]))
            elif pc == 0x415160: self.notice_fill_inputs.append(bytes(uc.mem_read(sp-100, 100)).hex())
            elif pc == 0x43f010:
                pointer = uc.reg_read(UC_X86_REG_ECX); assert pointer in self.drawing_bitmap_tokens
                self.drawing_bitmap = pointer; self.drawing_event('draw', [self.drawing_bitmap_tokens[pointer], *[arg(i) for i in range(6)]])
            elif pc == 0x43ef70:
                src = [arg(i) for i in range(4)]; dst = [uc.reg_read(UC_X86_REG_ECX), uc.reg_read(UC_X86_REG_EDI), arg(4), arg(5)]
                self.drawing_clip = dict(returnPC=self.u32(sp), src=src, dst=dst,
                    source=[signed(self.u32(p)) for p in src], destination=[signed(self.u32(p)) for p in dst])
        if pc == 0x78132db2: self.ret(PTD); return
        gdi = self.early.gdi
        if pc in gdi.presentation_imports: gdi.presentation_imported(uc, pc, size, data); return
        if pc in (BAPI+0x100, BAPI+0x110): gdi.com('getDC' if pc == BAPI+0x100 else 'releaseDC'); return
        if pc == PAPI:
            if self.u32(sp) == 0x4151bf:
                assert arg(2) == arg(3) == 0 and arg(4) == 0x1000400
                self.drawing_event('fill', fill=dict(target=arg(0), rectangle=list(struct.unpack('<4i', uc.mem_read(arg(1), 16))),
                    flags=arg(4), effects=list(uc.mem_read(arg(5), 100)), defined=[i < 4 or 0x50 <= i < 0x54 for i in range(100)]))
            else:
                assert arg(5) == 0
                self.drawing_event('blit', blit=dict(sourceSurface=arg(2), targetSurface=arg(0),
                    source=list(struct.unpack('<4i', uc.mem_read(arg(3), 16))), destination=list(struct.unpack('<4i', uc.mem_read(arg(1), 16))), flags=arg(4), effects=None))
            self.ret(0, 24); return
        assert any(a <= pc <= z for a, z in [(START, END-1), (0x401290, 0x4012fe), (0x415160, 0x4151c2),
                    (0x43ef70, 0x43f2fe), (0x78130000, 0x7822ffff), (STOP+0x6000, STOP+0x7fff)]), hex(pc)

    def capture_character(self, parent):
        old = super().capture_character(parent); suffix = '-control' if self.control else ''
        report = json.loads((ROOT/'docs/evidence'/('gameplay-hud'+suffix+'.json')).read_bytes())
        raw = (ROOT/'build/original'/report['corpus']).read_bytes()
        assert digest(raw) == report['sha256'] and len(raw) == report['bytes'] and json.loads(raw) == json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes()) == report['fixtureSHA256']
        print('Entire pinned GAMEPLAY_HUD reproduced; continuing whole post-HUD notices', flush=True)
        self.drawing_events = []; self.drawing_clip = None; self.drawing_bitmap = None
        self.notice_accesses = []; self.notice_written = bytearray(0x158); self.notice_fill_inputs = []
        self.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, self.notices_access, begin=self.body_sp+0x46c, end=self.body_sp+0x5c3)
        for pc in (START, 0x421a48, 0x421a53, 0x421a60):
            self.uc.hook_add(UC_HOOK_CODE, self.early.observe_fpu, begin=pc, end=pc)
        initialized.CHECKPOINTS.update((START, 0x421a48, 0x421a53, 0x421a60))
        notice = dict(target=self.u32(0x455608), dcResult=0, dc=0x12345678, methodResult=0,
            flags={hex(p): self.u32(p) for p in (0x450bec, 0x450c2c, 0x450c28, 0x451160)},
            localBefore=bytes(self.uc.mem_read(self.body_sp+0x46c, 0x158)).hex())
        self.early.gdi.presentation_input = notice; self.early.gdi.presentation_events = self.drawing_events
        def heap(): return [dict(address=a['address'], kind=FRAME_KINDS[a['caller']], storage=self.record(self.region(a['address'], a['size']))) for a in self.allocations if a['caller'] in FRAME_KINDS]
        def menu(): return [dict(address=r['address'], storage=self.record(r)) for r in self.menu_bitmaps]
        cw, sw, tag = [self.uc.reg_read(r) for r in (UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)]
        before_heap, before_menu = heap(), menu()
        section = self.gameplay_step('post-hud-notices', START, END)
        section['before'].update(frameHeap=before_heap, menuBitmaps=before_menu)
        section['after'].update(frameHeap=heap(), menuBitmaps=menu())
        notice.update(events=self.drawing_events, fillInputs=self.notice_fill_inputs, localAccesses=self.notice_accesses,
            localAfter=bytes(self.uc.mem_read(self.body_sp+0x46c, 0x158)).hex(), localWritten=list(self.notice_written),
            esi=self.uc.reg_read(UC_X86_REG_ESI), edi=self.uc.reg_read(UC_X86_REG_EDI), fpcw=cw,
            fpswBefore=sw, fpswAfter=self.uc.reg_read(UC_X86_REG_FPSW), fptagBefore=tag, fptagAfter=self.uc.reg_read(UC_X86_REG_FPTAG))
        section['notices'] = notice
        assert cw == self.uc.reg_read(UC_X86_REG_FPCW) == 0x23f and not self.early.fpu_pending
        return transport(dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, control=self.control,
            parent=dict(fixture=report['fixture'], sha256=report['fixtureSHA256']), fpu=self.early.audit(), worldAddress=WORLD,
            actorAddresses=[r['address'] for r in self.pool], objectAddresses=self.object_addresses, cases=[section]), {**self.early.blobs, **self.blobs})


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--control', action='store_true'); args = parser.parse_args()
    suffix = '-control' if args.control else ''
    doc = capture_startup(args.control, vm_type=GameplayNotices, early_type=initialized.InitializedEarlyMenus,
        after=lambda vm, parent: vm.capture_screen(parent, after_first=lambda vm, first:
            vm.capture_return(first, after_cycle=lambda vm, cycle: vm.capture_character(cycle))))
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode(); path = ROOT/'build/original'/('gameplay-notices'+suffix+'.json'); path.write_bytes(raw)
    c = doc['cases'][0]
    report = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, corpus=path.name, sha256=digest(raw), bytes=len(raw), parent=doc['parent'],
        helpers=len(c['helpers']), instructions=len(c['instructions']), events=len(c['notices']['events']), end=c['end'],
        readsBeforeWrites=c['readsBeforeWrites'], localAccesses=c['notices']['localAccesses'], fpcw=c['notices']['fpcw'],
        fpuCheckpoints=len(doc['fpu']['checkpoints']), nativeCompared=False, windowsVerified=False)
    (ROOT/'build/research'/path.name).write_text(json.dumps(report, indent=2)+'\n'); print(json.dumps(report, indent=2), flush=True)

if __name__ == '__main__': main()
