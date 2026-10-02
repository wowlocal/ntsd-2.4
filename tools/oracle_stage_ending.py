#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole 437220, the Stage ENDING screen (menu 300), with the real 431c70.

Declared inputs: the EXE's own .data, the ENDING bitmap wrapper with the
static frame rectangles (424b45..424c98, OriginalFrontMenuRectangles), eight
seat Actors with their key bytes, and the screen's counters. 43f010 (bitmap
draw) and 415160 (fill) are recorded as calls with their arguments and return
0; memset (4450a0) is performed. Compared by OriginalStageEndingTests. No
DirectDraw, raster or application claim.
"""
import argparse
import itertools
import json
import struct
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256
from inspect_original import PE
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_EIP
import hashlib

STACK, ACTORS, BITMAP, STOP = 0x10000000, 0x23000000, 0x24000000, 0x30000000
GLOBAL, GLOBAL_END, WORLD, WORLD_SIZE = 0x44D000, 0x458440, 0x458B00, 0x7D8
ACTOR_SIZE, BITMAP_SIZE, TARGET = 0x420, 0x1F50, 0x26006000
FRAMES = [[0, 0, 402, 66], [0, 67, 402, 91], [0, 159, 402, 156], [0, 316, 419, 169], [0, 486, 419, 65], [403, 53, 15, 13]]
COUNTERS = (0x451B20, 0x451B24, 0x451B28, 0x451B2C)
RESET_RANGES = ((0x4513A4, 0x4513C0), (0x451320, 0x451340), (0x455378, 0x455378 + 300))


class Ending:
    def __init__(self):
        exe = (DEFAULT_SOURCE / "NTSD 2.4.exe").read_bytes()
        assert hashlib.sha256(exe).hexdigest() == EXE_SHA256
        self.sections = [s for s in PE(exe).sections if s["name"] != ".rsrc"]
        self.exe = exe

    def fresh(self):
        uc = Uc(UC_ARCH_X86, UC_MODE_32)
        uc.mem_map(0x400000, 0x100000)
        for s in self.sections:
            uc.mem_write(0x400000 + s["rva"], self.exe[s["fileOffset"]:s["fileOffset"] + s["fileSize"]])
        for start, size in [(STACK, 0x10000), (ACTORS, 0x3000), (BITMAP, 0x2000), (STOP, 0x1000)]:
            uc.mem_map(start, size)
        return uc

    def run(self, case):
        uc = self.fresh(); u32 = lambda a: struct.unpack("<I", uc.mem_read(a, 4))[0]
        put = lambda a, v: uc.mem_write(a, struct.pack("<I", v & 0xFFFFFFFF))
        for i, (x, y, w, h) in enumerate(FRAMES):
            for field, value in zip((0x10, 0x7E0, 0xFB0, 0x1780), (x, y, w, h)): put(BITMAP + field + 4 * i, value)
        put(BITMAP + 0x0C, len(FRAMES)); put(0x451190, BITMAP); put(0x455608, 0x26007000)
        # 431c70's targets and the seat Actors start as 0xA5, the port's unknown
        # backing, so every reset write is visible in the comparison.
        for start, end in RESET_RANGES: uc.mem_write(start, b"\xa5" * (end - start))
        uc.mem_write(ACTORS, b"\xa5" * (8 * ACTOR_SIZE))
        for address, value in case["globals"].items(): put(int(address, 16), value)
        for slot in range(8):
            put(WORLD + 0x194 + 4 * slot, ACTORS + slot * ACTOR_SIZE)
            d1, ca = case["keys"][slot]
            uc.mem_write(ACTORS + slot * ACTOR_SIZE + 0xD1, bytes([d1])); uc.mem_write(ACTORS + slot * ACTOR_SIZE + 0xCA, bytes([ca]))
        before = dict(globals=bytes(uc.mem_read(GLOBAL, GLOBAL_END - GLOBAL)), world=bytes(uc.mem_read(WORLD, WORLD_SIZE)),
                      actors=bytes(uc.mem_read(ACTORS, 8 * ACTOR_SIZE)), bitmap=bytes(uc.mem_read(BITMAP, BITMAP_SIZE)))
        events = []
        def ret(pop):
            sp = uc.reg_read(UC_X86_REG_ESP); uc.reg_write(UC_X86_REG_EAX, 0)
            uc.reg_write(UC_X86_REG_EIP, u32(sp)); uc.reg_write(UC_X86_REG_ESP, sp + 4 + pop)
        def code(uc_, address, size, data):
            sp = uc.reg_read(UC_X86_REG_ESP); arg = lambda i: u32(sp + 4 + 4 * i)
            if address == STOP: uc.emu_stop()
            elif address == 0x43F010:
                events.append(dict(kind="draw", this=uc.reg_read(UC_X86_REG_ECX), arguments=[arg(i) for i in range(6)])); ret(0x18)
            elif address == 0x415160:
                events.append(dict(kind="fill", arguments=[arg(i) for i in range(5)])); ret(0)
            elif address == 0x431C70:
                events.append(dict(kind="resetInput", this=uc.reg_read(UC_X86_REG_ECX)))
            elif address == 0x4450A0:
                dst, value, count = arg(0), arg(1), arg(2); uc.mem_write(dst, bytes([value & 0xFF]) * count)
                sp_ = uc.reg_read(UC_X86_REG_ESP); uc.reg_write(UC_X86_REG_EAX, dst); uc.reg_write(UC_X86_REG_EIP, u32(sp_)); uc.reg_write(UC_X86_REG_ESP, sp_ + 4)
        uc.hook_add(UC_HOOK_CODE, code)
        sp = STACK + 0xF000
        for value in (0, 0x44D020, TARGET, STOP): sp -= 4; put(sp, value)
        uc.reg_write(UC_X86_REG_ESP, sp); uc.reg_write(UC_X86_REG_ECX, WORLD)
        uc.emu_start(0x437220, STOP, count=200000)
        assert uc.reg_read(UC_X86_REG_ESP) == STACK + 0xF000, "callee cleanup"
        after = dict(globals=bytes(uc.mem_read(GLOBAL, GLOBAL_END - GLOBAL)), world=bytes(uc.mem_read(WORLD, WORLD_SIZE)),
                     actors=bytes(uc.mem_read(ACTORS, 8 * ACTOR_SIZE)), bitmap=bytes(uc.mem_read(BITMAP, BITMAP_SIZE)))
        def diff(name, base):
            a, b = before[name], after[name]
            return [[base + i, b[i]] for i in range(len(a)) if a[i] != b[i]]
        assert not diff("world", WORLD) and not diff("bitmap", BITMAP)
        return dict(label=case["label"], globals=case["globals"], keys=case["keys"], events=events,
                    globalWrites=diff("globals", GLOBAL), actorWrites=[[(a - ACTORS) // ACTOR_SIZE, (a - ACTORS) % ACTOR_SIZE, v] for a, v in diff("actors", ACTORS)])


def cases():
    none = [[0, 0]] * 8
    keyed = {"none": none, "slot0": [[1, 0]] + [[0, 0]] * 7, "slot0held": [[1, 1]] + [[0, 0]] * 7,
             "slot7": [[0, 0]] * 7 + [[1, 0]], "slot3held5": [[0, 0]] * 3 + [[1, 1], [0, 0], [1, 0], [0, 0], [0, 0]],
             "ca-only": [[0, 1]] * 8}
    out = []
    for level, page, opened, closed, blink in itertools.product((-1, 0, 1, 2, 3), (0, 1, 2, 3, 4, 5), (0, 12, 13), (0, 1, 12), (4, 9)):
        out.append(dict(label=f"level{level}-page{page}-open{opened}-close{closed}-blink{blink}-none",
                        globals={"0x450c30": level, "0x451b28": page, "0x451b24": opened, "0x451b20": closed, "0x451b2c": blink, "0x44d020": 300, "0x457580": 1},
                        keys=none))
    for name, keys in keyed.items():
        for closed, blink in itertools.product((0, 5, -1), (3, 8)):
            out.append(dict(label=f"keys-{name}-close{closed}-blink{blink}",
                            globals={"0x450c30": 0, "0x451b28": 3, "0x451b24": 13, "0x451b20": closed, "0x451b2c": blink, "0x44d020": 300, "0x457580": 1},
                            keys=keys))
    for opened, closed in ((14, 0), (-3, 0), (13, 13), (13, 14), (13, -5)):
        out.append(dict(label=f"edge-open{opened}-close{closed}",
                        globals={"0x450c30": 2, "0x451b28": 4, "0x451b24": opened, "0x451b20": closed, "0x451b2c": -1, "0x44d020": 300, "0x457580": 1},
                        keys=keyed["slot0"]))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("output")
    args = parser.parse_args()
    ending = Ending(); results = [ending.run(c) for c in cases()]
    json.dump(dict(exeSHA256=EXE_SHA256, function="437220", frames=FRAMES, target=TARGET, fillTarget=0x26007000, bitmap=BITMAP,
                   resetRanges=[list(r) for r in RESET_RANGES], actorFill=0xA5,
                   world=WORLD, actorSize=ACTOR_SIZE, cases=results), open(args.output, "w"), indent=0)
    print(len(results), "cases", sum(len(r["events"]) for r in results), "events")


if __name__ == "__main__":
    main()
