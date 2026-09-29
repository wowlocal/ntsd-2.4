#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute the original WndProc 43b3d0 for its quit path: WM_DESTROY (43b4ba:
4019b0 sound release, 401d30 music release, 43d2a0 replay buffers, then
PostQuitMessage(0) unless 458434), and the DefWindowProcA messages WM_CLOSE,
WM_NCDESTROY and WM_SYSCOMMAND (SC_KEYMENU answered 1 at 43b519). The
accepted window-input harness (oracle_window_input.py, same pinned EXE/lib,
Unicorn 2.1.4, installer parent, declared COM/free/DefWindowProcA results)
runs each call; PostQuitMessage is an added recorded boundary. A new corpus;
the accepted window-input corpus is unchanged. APPLICATION_WINDOW_CLOSE_PLAN.md C1.
"""
import argparse, json
import oracle_window_input as harness
from oracle_window_input import WindowInput, ROOT, EXE_SHA256, LIB_SHA256, digest
from unicorn.x86_const import UC_X86_REG_ESP

harness.MESSAGES |= {2, 0x10, 0x82, 0x112}


class WindowClose(WindowInput):
    def code(self, u, pc, size, data):
        if self.capturing and pc in self.boundaries and self.boundaries[pc][1] == 'PostQuitMessage':
            code = self.u32(u.reg_read(UC_X86_REG_ESP) + 4)
            # PostQuitMessage is void: the recorded result is 0, never read.
            self.calls.append(dict(kind='postQuit', arguments=[code], strings=[], result=0))
            self.actions.append(dict(kind='request', event=self.calls[-1]))
            self.ret(0, 4); return
        return super().code(u, pc, size, data)


def specifications():
    for method in (0, 1, -1):
        for cat, builtin in ((0, 0), (1, 0), (2, 2), (400, 80)):
            for music in (True, False):
                for recreate in (0, 1):
                    yield dict(label='destroy', message=2, methodResult=method, shutdown=True, sounds=[cat, builtin],
                               music=music, stimulus=[[0x458434, recreate]])
    for replays in ([0, 0], [64, 0], [0, 128], [64, 128]):
        yield dict(label='destroy-replays', message=2, shutdown=True, music=False, replays=replays)
    yield dict(label='destroy-released', message=2)
    for message, wparams in ((0x10, [0]), (0x82, [0]), (0x112, [0xf100, 0xf060, 0xf020, 0xf120, 0])):
        for w in wparams:
            for result in (0, 1, -1):
                yield dict(label='default-procedure', message=message, key=w, lParam=0x12345678, defaultResult=result)


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--output', required=True); a = p.parse_args()
    path = ROOT / a.output; assert not path.exists()
    vm = WindowClose(); cases = []
    for spec in specifications():
        cases.append(vm.call(spec, len(cases)))
        print('case', len(cases) - 1, spec['label'], hex(spec['message']), [e['kind'] for e in cases[-1]['events']], flush=True)
    doc = dict(scope=__doc__, exeSHA256=EXE_SHA256, libSHA256=LIB_SHA256, parent=vm.parent, cases=cases, blobs=vm.blobs,
               limited=False, nativeCompared=False, windowsVerified=False)
    raw = (json.dumps(doc, sort_keys=True, separators=(',', ':')) + '\n').encode(); path.write_bytes(raw)
    report = dict(scope=__doc__, corpus=str(path.relative_to(ROOT)), sha256=digest(raw), bytes=len(raw), cases=len(cases),
                  events=sum(len(c['events']) for c in cases), postQuit=sum(e['kind'] == 'postQuit' for c in cases for e in c['events']),
                  nativeComparison='pending')
    (ROOT / 'docs/evidence/window-close.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ('corpus', 'sha256', 'bytes', 'cases', 'events', 'postQuit')}))


if __name__ == '__main__':
    main()
