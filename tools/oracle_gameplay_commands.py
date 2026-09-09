#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continue both own initialized matches through4214d5..421a15 on the same CPU.

Fresh startup/menu/loading/selection/launch and complete previous gameplay.
No command inputs, expected state injection or new platform responses. The
controlled command corpus covers branches not taken by this natural first tick.
Stops before the HUD caller; full tick and Windows execution remain open.
"""
import argparse
import json
from oracle_gameplay_lifecycle import GameplayLifecycle, initialized, FRAME_KINDS
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, REGISTERS, digest, capture_startup, transport
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI,
                              UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

HELPERS = {0x4061d0: (0, 0), 0x417170: (2, 0), 0x4450d0: (0, 0), 0x402000: (0, 0)}


class GameplayCommands(GameplayLifecycle):
    def commands_active(self):
        return getattr(self, 'gameplay_running', False) and self.gameplay_label == 'post-draw-commands'

    def imported(self, uc, pc, size, data):
        if not self.commands_active():
            return super().imported(uc, pc, size, data)

    def checkpoint(self, uc, pc, size, data):
        if not self.commands_active():
            return super().checkpoint(uc, pc, size, data)

    def commands_scratch_access(self, uc, access, address, size, value, data):
        if self.commands_active():
            self.commands_scratch_accesses.append(dict(pc=uc.reg_read(UC_X86_REG_EIP), offset=address-self.body_sp,
                                                        size=size, write=access == UC_MEM_WRITE))

    def gameplay_code(self, uc, pc, size, data):
        if not self.commands_active():
            return super().gameplay_code(uc, pc, size, data)
        self.gameplay_instructions.add(pc)
        sp = uc.reg_read(UC_X86_REG_ESP)
        while self.gameplay_pending and pc == self.gameplay_pending[-1]['returnPC']:
            h = self.gameplay_pending.pop()
            assert sp == h['entrySP']+4+h['pop'] and h['saved'] == [uc.reg_read(r) for r in REGISTERS], h
            h.update(returnSP=sp, result=uc.reg_read(UC_X86_REG_EAX))
            self.gameplay_helpers.append(h)
            if h['entry'] == 0x417170:
                self.commands_events.append(dict(kind='random', arguments=h['arguments']+[h['result']]))
        if pc == self.gameplay_stop:
            assert not self.gameplay_pending and uc.reg_read(UC_X86_REG_EDI) == 0 and self.u32(self.body_sp+0x3c) == 400
            self.gameplay_finished = True
            uc.emu_stop()
            return
        if pc in HELPERS:
            count, pop = HELPERS[pc]
            args = [self.u32(sp+4+4*i) for i in range(count)]
            self.gameplay_pending.append(dict(entry=pc, entrySP=sp, returnPC=self.u32(sp), pop=pop,
                this=uc.reg_read(UC_X86_REG_ECX), arguments=args, saved=[uc.reg_read(r) for r in REGISTERS]))
            if pc == 0x4061d0:
                slot = self.u32(self.body_sp+0x34)
                assert 0 <= slot < 400 and self.pool[slot]['address'] == uc.reg_read(UC_X86_REG_ECX)
                self.commands_events.append(dict(kind='reconstruct', arguments=[slot]))
        # No new COM response is supplied here. Unexpected device paths stop
        # at this guard and must be investigated with their actual provenance.
        assert any(a <= pc <= z for a, z in [(0x4214d5, 0x421a0f), (0x4061d0, 0x4064cc),
                   (0x417170, 0x4171bc), (0x4450d0, 0x44517a), (0x402000, 0x402011)]), hex(pc)

    def capture_character(self, parent):
        old = super().capture_character(parent)
        suffix = '-control' if self.control else ''
        report = json.loads((ROOT/'docs/evidence'/('gameplay-lifecycle'+suffix+'.json')).read_bytes())
        raw = (ROOT/'build/original'/report['corpus']).read_bytes()
        assert digest(raw) == report['sha256'] and len(raw) == report['bytes']
        assert json.loads(raw) == json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes()) == report['fixtureSHA256']
        print('Entire pinned GAMEPLAY_LIFECYCLE reproduced; continuing resource commands and cleanup', flush=True)
        def heap():
            return [dict(address=a['address'], kind=FRAME_KINDS[a['caller']], storage=self.record(self.region(a['address'], a['size'])))
                    for a in self.allocations if a['caller'] in FRAME_KINDS]
        def menu():
            return [dict(address=r['address'], storage=self.record(r)) for r in self.menu_bitmaps]
        self.commands_events = []
        self.commands_scratch_accesses = []
        self.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, self.commands_scratch_access,
                         begin=self.body_sp+0x34, end=self.body_sp+0x37)
        # The preceding stage already installed the4214d5 FPU hook. It will
        # run now that this PC is resumed rather than stopped before execution.
        self.uc.hook_add(UC_HOOK_CODE, self.early.observe_fpu, begin=0x4217b0, end=0x4217b0)
        initialized.CHECKPOINTS.add(0x4217b0)
        retained = self.u32(self.body_sp+0x34)
        cw, sw, tag = [self.uc.reg_read(r) for r in (UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)]
        cpu_sse2 = self.u32(0x45971c)
        before_heap, before_menu = heap(), menu()
        section = self.gameplay_step('post-draw-commands', 0x4214d5, 0x421a15)
        section['before'].update(frameHeap=before_heap, menuBitmaps=before_menu)
        section['after'].update(frameHeap=heap(), menuBitmaps=menu())
        section['commands'] = dict(retainedOffset=0x34, retainedBefore=retained, retainedAfter=self.u32(self.body_sp+0x34),
            scratchAccesses=self.commands_scratch_accesses, fpcw=cw, fpswBefore=sw, fpswAfter=self.uc.reg_read(UC_X86_REG_FPSW),
            fptagBefore=tag, fptagAfter=self.uc.reg_read(UC_X86_REG_FPTAG), sse2=cpu_sse2, events=self.commands_events)
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
    doc = capture_startup(args.control, vm_type=GameplayCommands, early_type=initialized.InitializedEarlyMenus,
        after=lambda vm, parent: vm.capture_screen(parent, after_first=lambda vm, first:
            vm.capture_return(first, after_cycle=lambda vm, cycle: vm.capture_character(cycle))))
    raw = (json.dumps(doc, separators=(',', ':'))+'\n').encode()
    path = ROOT/'build/original'/('gameplay-commands'+suffix+'.json')
    path.write_bytes(raw)
    c = doc['cases'][0]
    report = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=__doc__, corpus=path.name,
        sha256=digest(raw), bytes=len(raw), parent=doc['parent'], helpers=len(c['helpers']),
        instructions=len(c['instructions']), events=len(c['commands']['events']), end=c['end'],
        readsBeforeWrites=c['readsBeforeWrites'], scratchAccesses=c['commands']['scratchAccesses'],
        fpcw=c['commands']['fpcw'], fpuCheckpoints=len(doc['fpu']['checkpoints']),
        nativeCompared=False, windowsVerified=False)
    (ROOT/'build/research'/path.name).write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
