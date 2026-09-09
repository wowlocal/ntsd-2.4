#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continue the initialized own first tick through the complete post-draw loop.

Fresh original startup/menu/loading/selection/launch/gameplay on one CPU and
stack. No new gameplay inputs or state replacement. Actual41f550..4214cf and
helpers; stops before4214d5. Supplied outer/platform boundaries remain explicit.
"""
import argparse
import copy
import json
from oracle_gameplay_impulses import GameplayImpulses
import oracle_initialized_gameplay as initialized
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, REGISTERS, digest, capture_startup, transport
from oracle_loaded_catalog import FRAME_KINDS
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_ESI,
                              UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

SCRATCH = [0x44, 0x50, 0x5c, 0x60, 0x6c, 0x70]
HELPERS = {0x4061d0: (0, 0), 0x40d960: (2, 8), 0x417170: (2, 0),
           0x416fb0: (2, 0), 0x417090: (2, 0), 0x4450d0: (0, 0)}


class GameplayLifecycle(GameplayImpulses):
    def lifecycle_active(self):
        return getattr(self, 'gameplay_running', False) and self.gameplay_label == 'post-draw-lifecycle'

    def imported(self, uc, pc, size, data):
        if not self.lifecycle_active():
            return super().imported(uc, pc, size, data)

    def checkpoint(self, uc, pc, size, data):
        if not self.lifecycle_active():
            return super().checkpoint(uc, pc, size, data)

    def scratch_access(self, uc, access, address, size, value, data):
        if not self.lifecycle_active():
            return
        pc = uc.reg_read(UC_X86_REG_EIP)
        self.lifecycle_scratch_accesses.append(dict(pc=pc, offset=address-self.body_sp,
                                                    size=size, write=access == UC_MEM_WRITE))

    def gameplay_code(self, uc, pc, size, data):
        if not self.lifecycle_active():
            return super().gameplay_code(uc, pc, size, data)
        self.gameplay_instructions.add(pc)
        sp = uc.reg_read(UC_X86_REG_ESP)
        while self.gameplay_pending and pc == self.gameplay_pending[-1]['returnPC']:
            h = self.gameplay_pending.pop()
            assert sp == h['entrySP']+4+h['pop'] and h['saved'] == [uc.reg_read(r) for r in REGISTERS], h
            h.update(returnSP=sp, result=uc.reg_read(UC_X86_REG_EAX))
            self.gameplay_helpers.append(h)
            if h['entry'] == 0x417170:
                self.lifecycle_events.append(dict(kind='random', slot=h['slot'], arguments=h['arguments']+[h['result']]))
        if pc == self.gameplay_stop:
            assert not self.gameplay_pending and uc.reg_read(UC_X86_REG_EDI) == 400
            self.gameplay_finished = True
            uc.emu_stop()
            return
        if pc in HELPERS:
            count, pop = HELPERS[pc]
            scheduler = next((h for h in reversed(self.gameplay_pending) if h['entry'] == 0x40d960), None)
            slot = scheduler['slot'] if scheduler else uc.reg_read(UC_X86_REG_EDI)
            args = [self.u32(sp+4+4*i) for i in range(count)]
            self.gameplay_pending.append(dict(entry=pc, entrySP=sp, returnPC=self.u32(sp), pop=pop,
                this=uc.reg_read(UC_X86_REG_ECX), arguments=args, slot=slot, saved=[uc.reg_read(r) for r in REGISTERS]))
            if pc in (0x416fb0, 0x417090):
                self.lifecycle_events.append(dict(kind='catalogSound' if pc == 0x416fb0 else 'builtinSound', slot=slot, arguments=args))
            elif pc == 0x4061d0:
                created = self.u32(self.body_sp+0x3c) if self.u32(sp) == 0x41f751 else uc.reg_read(UC_X86_REG_ESI)
                assert 0 <= created < 400 and self.pool[created]['address'] == uc.reg_read(UC_X86_REG_ECX)
                self.lifecycle_events.append(dict(kind='reconstruct', slot=slot, arguments=[created]))
        assert any(a <= pc <= z for a, z in [(0x41f550, 0x4214cf), (0x4061d0, 0x4064cc), (0x40d960, 0x40de20),
                   (0x416fb0, 0x4171bc), (0x4450d0, 0x44517a)]), hex(pc)

    def capture_character(self, parent):
        old = super().capture_character(parent)
        suffix = '-control' if self.control else ''
        # The historical initialized fixture adds the original FPU audit to
        # this very same gameplay parent. Compare the complete fresh record.
        old.update(scope=initialized.__doc__, fpu=copy.deepcopy(self.early.audit()))
        report = json.loads((ROOT/'docs/evidence'/('initialized-gameplay'+suffix+'.json')).read_bytes())
        raw = (ROOT/'build/original'/report['corpus']).read_bytes()
        assert digest(raw) == report['sha256'] and len(raw) == report['bytes']
        assert json.loads(raw) == json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes()) == report['fixtureSHA256']
        print('Entire pinned INITIALIZED_GAMEPLAY reproduced; continuing whole live-slot loop', flush=True)
        def heap():
            return [dict(address=a['address'], kind=FRAME_KINDS[a['caller']], storage=self.record(self.region(a['address'], a['size'])))
                    for a in self.allocations if a['caller'] in FRAME_KINDS]
        def menu():
            return [dict(address=r['address'], storage=self.record(r)) for r in self.menu_bitmaps]
        self.lifecycle_events = []
        self.lifecycle_scratch_accesses = []
        for offset in SCRATCH:
            self.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, self.scratch_access,
                             begin=self.body_sp+offset, end=self.body_sp+offset+3)
        for pc in (0x40d960, 0x41fb0b, 0x4214d5):
            self.uc.hook_add(UC_HOOK_CODE, self.early.observe_fpu, begin=pc, end=pc)
        # These checkpoints extend the existing observer's declared set only
        # after the complete historical initialization audit has reproduced.
        initialized.CHECKPOINTS.update((0x40d960, 0x41fb0b, 0x4214d5))
        scratch = [self.u32(self.body_sp+o) for o in SCRATCH]
        cw = self.uc.reg_read(UC_X86_REG_FPCW)
        sw = self.uc.reg_read(UC_X86_REG_FPSW)
        tag = self.uc.reg_read(UC_X86_REG_FPTAG)
        cpu_sse2 = self.u32(0x45971c)
        before_heap, before_menu = heap(), menu()
        section = self.gameplay_step('post-draw-lifecycle', 0x41f550, 0x4214d5)
        section['before'].update(frameHeap=before_heap, menuBitmaps=before_menu)
        section['after'].update(frameHeap=heap(), menuBitmaps=menu())
        section['lifecycle'] = dict(scratchOffsets=SCRATCH, scratchBefore=scratch,
            scratchAfter=[self.u32(self.body_sp+o) for o in SCRATCH], scratchAccesses=self.lifecycle_scratch_accesses,
            fpcw=cw, fpswBefore=sw, fpswAfter=self.uc.reg_read(UC_X86_REG_FPSW), fptagBefore=tag,
            fptagAfter=self.uc.reg_read(UC_X86_REG_FPTAG), sse2=cpu_sse2, events=self.lifecycle_events)
        assert cw == self.uc.reg_read(UC_X86_REG_FPCW) == 0x23f and not self.early.fpu_pending
        return transport(dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, control=self.control,
            parent=dict(fixture=report['fixture'], sha256=report['fixtureSHA256']), fpu=self.early.audit(),
            worldAddress=WORLD, actorAddresses=[r['address'] for r in self.pool],
            objectAddresses=self.object_addresses, cases=[section]), {**self.early.blobs, **self.blobs})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--control', action='store_true')
    args = parser.parse_args()
    suffix = '-control' if args.control else ''
    doc = capture_startup(args.control, vm_type=GameplayLifecycle, early_type=initialized.InitializedEarlyMenus,
        after=lambda vm, parent: vm.capture_screen(parent, after_first=lambda vm, first:
            vm.capture_return(first, after_cycle=lambda vm, cycle: vm.capture_character(cycle))))
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode()
    path = ROOT/'build/original'/('gameplay-lifecycle'+suffix+'.json')
    path.write_bytes(raw)
    c = doc['cases'][0]
    report = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, corpus=path.name,
        sha256=digest(raw), bytes=len(raw), parent=doc['parent'], helpers=len(c['helpers']),
        instructions=len(c['instructions']), events=len(c['lifecycle']['events']), end=c['end'],
        readsBeforeWrites=c['readsBeforeWrites'], scratchAccesses=c['lifecycle']['scratchAccesses'],
        fpcw=c['lifecycle']['fpcw'], fpuCheckpoints=len(doc['fpu']['checkpoints']),
        nativeCompared=False, windowsVerified=False)
    (ROOT/'build/research'/path.name).write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
