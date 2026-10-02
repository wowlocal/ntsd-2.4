#!/usr/bin/env python3
"""Extend the retained network-menu observer for the original selector-4 screen.

Pinned NTSD EXE/lib.dll/VC80 in the existing Unicorn environment. The old
producer stays unchanged. Only its declared unsupported selector-4 observation
boundary is extended; no guest instruction, branch, register or output is
patched. Retain the whole actual caller, renderer/library helpers and tail.
Host/API replies are controlled inputs, not real Windows/TCP observations.
"""
import argparse
import json
import os
from pathlib import Path

from oracle_network_menu import NetworkMenu, ROOT, WORLD, PRODUCER_SHA256 as PARENT_SHA256
from oracle_front_menu_loop import FrontMenuLoop
from oracle_bitmap_drawing import digest
from oracle_front_menu_resources import GLOBAL, GLOBAL_SIZE
from unicorn.x86_const import UC_X86_REG_EIP, UC_X86_REG_ESP


class NetworkReady(NetworkMenu):
    def network_write(self, uc, access, address, size, value, data):
        super().network_write(uc, access, address, size, value, data)
        if self.network_active and 0x428808 <= uc.reg_read(UC_X86_REG_EIP) < 0x4289c4:
            if GLOBAL <= address < address+size <= GLOBAL+GLOBAL_SIZE or WORLD <= address < address+size <= WORLD+0x7d8:
                self.body_event('write',[address,size,value & ((1 << (size*8))-1)])

    def body_code_allowed(self, pc):
        return super().body_code_allowed(pc) or self.network_active and 0x428808 <= pc < 0x4289c4

    def code(self, uc, pc, size, data):
        if self.network_active and pc == 0x428808:
            # The old observer rejects every selector beyond 3 at this PC.
            # Observe the actual cmp eax,4 and let the CPU choose its branch.
            self.body_range = (0x427ca7, 0x4289c4)
            self.network_pcs[pc] = bytes(uc.mem_read(pc, size)).hex()
            FrontMenuLoop.code(self, uc, pc, size, data)
            return
        if self.network_active and pc == 0x4289c4:
            raise AssertionError('Outside the declared selector-4 continuation')
        super().code(uc, pc, size, data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--control', action='store_true')
    args = parser.parse_args()
    path = ROOT / args.output
    assert not path.exists()
    parts = path.with_suffix('.parts')
    parts.mkdir(exist_ok=False)
    entries, known = [], set()

    def checkpoint(value):
        additions = {k:v for k,v in vm.blobs.items() if k not in known}
        known.update(additions)
        raw = (json.dumps(dict(value=value,blobs=additions),separators=(',',':'))+'\n').encode()
        name = f'{len(entries):04d}.json'
        temp = parts/(name+'.tmp')
        temp.write_bytes(raw)
        os.replace(temp,parts/name)
        entries.append(dict(path=name,sha256=digest(raw),bytes=len(raw)))
        temp = parts/'index.tmp'
        temp.write_text(json.dumps(entries,indent=2)+'\n')
        os.replace(temp,parts/'index.json')

    vm = NetworkReady(args.control)
    doc = vm.parent_capture()
    doc.update(producerSHA256=digest(Path(__file__).read_bytes()),parentProducerSHA256=PARENT_SHA256)
    checkpoint(doc)
    calls = []
    # A real peer's 44 name bytes are padded with underscores. The retained
    # producer's generic ASCII-0 reply lacks those terminators; using that
    # malformed result for another connection causes overlapping string copies.
    replies = [dict(bytes=list(b'u can connect\0')),
               dict(bytes=list(b'11110000'+b'0'*24+b'_'*44+b'\0')),
               dict(bytes=list(bytes((i*7+3)&255 for i in range(3001))))]

    def run(label, writes=(), **options):
        if label in ('client-connect','client-reconnect'):
            options['network'] = dict(receives=replies)
        before = vm.loop_step(label,writes)
        call = dict(loop=before)
        if before['continuation'] == 'otherSelector':
            try:
                call['network'] = vm.network_step(label,**options)
            except Exception as error:
                checkpoint(dict(failure=dict(label=label,error=repr(error),
                    pc=hex(vm.uc.reg_read(UC_X86_REG_EIP)),sp=hex(vm.uc.reg_read(UC_X86_REG_ESP)),
                    bodyEnd=vm.body_end,pending=vm.body_pending,format=vm.format_pending,
                    lastEvents=vm.body_events[-8:],requests=vm.network_requests),loop=before))
                print(json.dumps(entries[-1]),flush=True)
                raise
            call['tail'] = vm.finish_network(label)
        calls.append(call)
        checkpoint(call)
        print(json.dumps(dict(call=len(calls),label=label,continuation=before['continuation'])),flush=True)

    mouse = lambda x,y,h: [(0x4546f0,x),(0x453cdc,y),(0x457580,h)]
    run('next-natural-frame')
    run('open-network',mouse(300,252,1))
    # Retained UI sequence establishes owned hostname/settings/bitmap state,
    # including a completed connection abandoned through the original menu.
    for label,writes in [
        ('choice-idle',mouse(0,0,0)),('choose-client',mouse(300,310,1)),
        ('client-idle',mouse(0,0,0)),('client-type',[(0x455378+65,b'\x64')]),
        ('client-enter',[(0x455385,b'\x64')]),('client-connect',[]),
        ('controlled-host-choice',mouse(300,280,1)+[(0x44d064,1)]),
        ('server-idle',mouse(0,0,0)),('server-dots',[(0x4511d4,3)]),
        ('server-back',mouse(400,370,1)),('choice-release',mouse(0,0,0)),
        ('choice-cancel',mouse(400,345,1))]:
        run(label,writes)
    run('main-after-network-cancel',mouse(0,0,0))
    # Controlled reconnect uses its own retained typed hostname and client
    # output. No selector-4 after-state is installed for the following call.
    run('client-reconnect',mouse(0,0,0)+[(0x44d064,3),(0x4511b0,1),(0x455378,bytes(300))])
    run('client-ready-own-output')
    assert vm.u32(WORLD) == 1
    # Finite timer/button controls at whole-caller starts. Reset World only as
    # an explicit input between cases, retaining each actual owned resource.
    def state(x=0,y=0,held=0,previous=0):
        return [(WORLD,0),(0x44d064,4),(0x4546f0,x),(0x453cdc,y),
                (0x457580,held),(0x44d060,previous),(0x4511cc,0),
                (0x4511d0,100),(0x4511f0,4)]
    for flags in (0,1,4,0x80000104):
        for elapsed in (0,150,151):
            run(f'ready-flags-{flags}-{elapsed}',state()+[(0x4511f0,flags)],timers=[100+elapsed]*6)
    for phase in (-2147483648,-1,0,1,13,14,2147483647):
        run(f'ready-phase-{phase}',state()+[(0x4511cc,phase)],timers=[251]*6)
    run('ready-timer-wrap',state()+[(0x4511d0,0xffffff80),(0x4511cc,13)],timers=[23]*6)
    for i,(x,y) in enumerate([(322,373),(321,373),(472,373),(473,373),(400,361),(400,360),(400,386),(400,387),(400,373)]):
        run(f'ready-back-{i}',state(x,y,1))
    for held,previous in [(0,0),(2,0),(1,1)]:
        run(f'ready-held-{held}-{previous}',state(400,373,held,previous))
    run('ready-world-one')
    run('ready-loading-entry')
    assert calls[-1]['loop']['continuation'] == 'loading'
    doc.update(calls=calls,sources=list(vm.background_sources.values()),blobs=vm.blobs,
               suite='client-ready',checkpointParts=entries)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode()
    assert len(raw)<128_000_000
    temp=path.with_suffix('.tmp')
    temp.write_bytes(raw)
    os.replace(temp,path)
    print(json.dumps(dict(path=str(path),bytes=len(raw),sha256=digest(raw),calls=len(calls))),flush=True)


if __name__ == '__main__':
    main()
