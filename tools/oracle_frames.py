#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute original frame construction and parsing, then compare native Swift.

Boundary: decoded <frame> sections only; no object header, outer loader, file IO,
rendering, or audio device. MSVCR80 fscanf is stubbed for ASCII strings and
in-range decimal Int32 conversions. Overflow is explicitly unsupported.
Original frame instructions and postprocessing run unchanged. See evidence docs.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
from pathlib import Path

from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_EIP
from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes, decode_dat
from inspect_original import PE

STRIDE, COUNT = 0x178, 400
BASE, STACK, HEAP, STUB, STOP = 0x20000000, 0x10000000, 0x21000000, 0x30000000, 0x30000f00
EXCLUDED = {0x130, 0x134, *range(0x15c, 0x174, 4)}  # pointers/name bytes, not numerical data
ASCII_SPACE = b' \t\r\n\v\f'
FRAME_RE = re.compile(r'<frame>\s+(-?\d+)\s+.*?<frame_end>', re.S)


class OutsideDomain(ValueError): pass


class OriginalFrames:
    def __init__(self, exe):
        if hashlib.sha256(exe).hexdigest() != EXE_SHA256:
            raise ValueError('Unidentified Windows EXE')
        pe = PE(exe)
        self.uc = uc = Uc(UC_ARCH_X86, UC_MODE_32)
        uc.mem_map(0x400000, 0x100000)
        for s in pe.sections:
            if s['name'] != '.rsrc':
                uc.mem_write(pe.base+s['rva'], exe[s['fileOffset']:s['fileOffset']+s['fileSize']])
        for addr, size in [(STACK, 0x10000), (BASE, 0x40000), (HEAP, 0x400000), (STUB, 0x10000)]:
            uc.mem_map(addr, size)
        uc.mem_write(BASE, b'\xa5' * 0x40000)
        self.defined = [set() for _ in range(COUNT)]
        self.alloc = HEAP
        self.stream, self.pos = b'', 0
        # Original sound-disabled branch still registers path strings, without a device.
        self.put(0x44eecc, 0)
        self.put(0x458438, 0)
        self.lookup = {}
        for item in pe.imports():
            if item['name'] in {'fscanf', 'sprintf', 'malloc'}:
                addr = STUB + 16*len(self.lookup)
                self.lookup[addr] = item['name']
                uc.mem_write(addr, b'\xc3')
                self.put(int(item['iatVA'],16), addr)
        uc.hook_add(UC_HOOK_CODE, self.imported, begin=STUB, end=STUB+0x100)
        uc.hook_add(UC_HOOK_MEM_WRITE, self.written, begin=BASE+0x7a4, end=BASE+0x7a4+STRIDE*COUNT-1)
        for n in range(COUNT):
            self.put(STACK+0xf000, STOP)
            uc.reg_write(UC_X86_REG_ESP, STACK+0xf000)
            uc.reg_write(UC_X86_REG_ECX, BASE+0x7a4+n*STRIDE)
            self.run(0x40bbf0, STOP)

    def put(self, addr, value): self.uc.mem_write(addr, struct.pack('<I', value & 0xffffffff))
    def u32(self, addr): return struct.unpack('<I', self.uc.mem_read(addr,4))[0]
    def cstr(self, addr):
        buf=bytearray()
        for i in range(4096):
            b=bytes(self.uc.mem_read(addr+i,1))
            if b == b'\0': return bytes(buf)
            buf.extend(b)
        raise OutsideDomain('Unterminated string')

    def written(self, uc, access, addr, size, value, data):
        for byte in range(addr, addr+size):
            n, off = divmod(byte-BASE-0x7a4, STRIDE)
            if 0 <= n < COUNT: self.defined[n].add(off//4*4)

    def skip_space(self):
        while self.pos < len(self.stream) and self.stream[self.pos] in ASCII_SPACE: self.pos += 1

    def imported(self, uc, address, size, data):
        name=self.lookup.get(address)
        if name is None: return
        esp=uc.reg_read(UC_X86_REG_ESP)
        args=[self.u32(esp+4+i*4) for i in range(5)]
        result=0
        if name == 'malloc':
            if not 0 < args[0] < 0x10000 or self.alloc+args[0] >= HEAP+0x400000:
                raise OutsideDomain('Allocation outside test domain')
            result=self.alloc
            self.alloc += (args[0]+15)//16*16
            uc.mem_write(result, b'\xa5'*args[0])
        elif name == 'sprintf':
            if self.cstr(args[1]) != b'%d': raise OutsideDomain('sprintf format')
            out=str(struct.unpack('<i',struct.pack('<I',args[2]))[0]).encode()
            uc.mem_write(args[0],out+b'\0'); result=len(out)
        elif name == 'fscanf':
            if args[0] != 1: raise OutsideDomain('Unexpected stream')
            fmt=self.cstr(args[1])
            if fmt not in (b'%s', b'%d', b'%d %d'): raise OutsideDomain(f'Scan format {fmt!r}')
            for index, spec in enumerate(fmt.split()):
                self.skip_space()
                if self.pos == len(self.stream):
                    raise OutsideDomain('Unexpected end of frame')
                if spec == b'%s':
                    end=self.pos
                    while end<len(self.stream) and self.stream[end] not in ASCII_SPACE: end+=1
                    val=self.stream[self.pos:end]
                    if len(val)>255: raise OutsideDomain('Oversized string')
                    uc.mem_write(args[2+index],val+b'\0'); self.pos=end
                else:
                    match=re.match(rb'[+-]?[0-9]+',self.stream[self.pos:])
                    if not match: break  # matching failure leaves destination unchanged
                    number=int(match[0])
                    if not -(2**31)<=number<2**31:
                        raise OutsideDomain('MSVCR80 decimal overflow is not yet verified')
                    self.put(args[2+index],number)
                    # Host writes aren't reported by Unicorn's emulated-write hook.
                    if BASE+0x7a4<=args[2+index]<BASE+0x7a4+COUNT*STRIDE:
                        self.written(uc,0,args[2+index],4,number,None)
                    self.pos+=len(match[0])
                result+=1
        uc.reg_write(UC_X86_REG_EAX,result)

    def run(self, start, stop):
        self.uc.emu_start(start,stop,timeout=5_000_000,count=3_000_000)
        if self.uc.reg_read(UC_X86_REG_EIP) != stop: raise OutsideDomain('Instruction/time limit')

    def apply(self, source):
        match=re.match(r'<frame>\s+([0-9]+)\s+(\S+)',source)
        if not match or not 0<=int(match[1])<COUNT: raise OutsideDomain('Frame index outside constructed table')
        if len(match[2].encode('latin-1'))>19: raise OutsideDomain('Original 20-byte name buffer')
        if any(len(x.encode('latin-1'))>255 for x in re.findall(r'\bsound:\s+(\S+)',source)):
            raise OutsideDomain('Original sound scratch buffer')
        for kind in ['bdy','itr']:
            if len(re.findall(r'\b'+kind+':',source))>5: raise OutsideDomain('More than five allocated boxes')
        n=int(match[1]); self.stream=source[len('<frame>'):].encode('latin-1'); self.pos=0
        sp=STACK+0xe000
        self.uc.mem_write(sp,b'\0'*0x600)
        self.put(sp+0x14,1)
        self.uc.mem_write(sp+0x70,b'<frame>\0')
        self.uc.reg_write(UC_X86_REG_ESP,sp)
        self.uc.reg_write(UC_X86_REG_EBP,BASE)
        scan=next(k for k,v in self.lookup.items() if v=='fscanf')
        self.uc.reg_write(UC_X86_REG_EBX,scan)
        self.run(0x4103f8,0x412277)
        self.skip_space()
        if self.pos!=len(self.stream): raise OutsideDomain('Unconsumed frame text')
        return self.snapshot(n)

    def snapshot(self,n):
        base=BASE+0x7a4+n*STRIDE
        words={str(off): (int(self.uc.mem_read(base,1)[0]) if off==0 else struct.unpack('<i',self.uc.mem_read(base+off,4))[0])
               for off in sorted(self.defined[n]-EXCLUDED)}
        arrays={}
        for name,countoff,ptroff,stride in [('interactions',0x128,0x130,80),('bodies',0x12c,0x134,40)]:
            count=self.u32(base+countoff)
            if count>5: raise OutsideDomain('Box count exceeds original allocation')
            ptr=self.u32(base+ptroff)
            arrays[name]=[list(struct.unpack('<'+'i'*(stride//4),self.uc.mem_read(ptr+i*stride,stride))) for i in range(count)]
        soundptr=self.u32(base+0x170)
        return {'number':n,'name':self.cstr(base+0x15c).decode('latin-1'), 'words':words,
                'sound':self.cstr(soundptr).decode('latin-1') if soundptr else None, **arrays}


def synthetic_cases():
    return [
      ('defaults-and-retention', ['<frame> 0 first\npic: 4 wait: 7 dvx: -3 centerx: 9\n<frame_end>',
        '<frame> 0 second\nstate: 2\n<frame_end>']),
      ('blocks-aliases-and-bounds', ['<frame> 399 edge\ncpoint: injury: 3 fronthurtact: 9 cover: 4 backhurtact: 12 throwvz: -2 cpoint_end:\nitr: x: -10 y: 4 w: 5 h: 6 catchingact: 110 111 pickingact: 200 itr_end:\nitr: x: 7 y: -8 w: 13 h: 3 caughtact: 5 6 itr_end:\nbdy: x: -2 y: 2 w: 4 h: 8 bdy_end:\nbdy: x: 6 y: -1 w: 2 h: 4 bdy_end:\n<frame_end>',
        '<frame> 399 repeat\ncpoint: x: 13 cpoint_end:\n<frame_end>']),
      ('integer-prefix-and-repeat', ['<frame> 17 numeric\npic: +12x wait: -2147483648 next: 2147483647 dvx: 3 dvx: 4 mp: nope hit_a: 9\n<frame_end>']),
      ('wrapped-bounds', ['<frame> 1 limits\nbdy: x: 2147483647 y: -2147483648 w: 2 h: -1 bdy_end:\nbdy: x: 0 y: 0 w: 1 h: 1 bdy_end:\n<frame_end>']),
      ('sounds-and-singleton-retention', ['<frame> 2 sound\nsound: data\\001.wav opoint: kind: 1 x: 20 oid: 7 opoint_end: opoint: y: -8 opoint_end:\n<frame_end>',
        '<frame> 2 repeat\nbpoint: x: 12 bpoint_end: wpoint: y: 30 weaponact: 5 wpoint_end:\n<frame_end>']),
      ('overlapping-sound-cache', ['<frame> 2 long\nsound: data\\SNDDATA_1869.wav\n<frame_end>',
        '<frame> 3 next\nsound: data\\001.wav\n<frame_end>',
        '<frame> 4 reload\nsound: data\\SNDDATA_1869.wav\n<frame_end>',
        '<frame> 5 cached\nsound: data\\001.wav\n<frame_end>'])]


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--corpus', action='store_true',help='Also compare every source frame group inside the stated test domain')
    args=ap.parse_args()
    exe=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe')
    cases=[]; excluded=[]
    for label,definitions in synthetic_cases():
        oracle=OriginalFrames(exe)
        cases.append({'label':label,'definitions':definitions,'snapshots':[oracle.apply(s) for s in definitions]})
    corpus=json.loads((ROOT/'build/imported/game.json').read_text())
    originals=[]
    for obj in corpus['objects']:
        groups={}
        for match in FRAME_RE.finditer(obj['originalText']): groups.setdefault(int(match[1]),[]).append(match[0])
        for n,definitions in groups.items():
            if args.corpus or (obj['source'] in ('chars/naruto.dat', 'chars/sasuke.dat') and
                               (n in (0,5,9,10,12,60,110,123,210,212,213,215,219) or len(definitions)>1)):
                originals.append((obj['source']+':'+str(n), definitions))
    # Reuse a VM per group batch; reconstruct target records, and reset sound cache.
    oracle=OriginalFrames(exe)
    for label,definitions in originals:
        n=int(re.match(r'<frame>\s+(-?\d+)',definitions[0])[1])
        if not 0<=n<COUNT:
            excluded.append({'label':label,'reason':'Frame index outside constructed table'});continue
        oracle.uc.mem_write(BASE+0x7a4+n*STRIDE,b'\xa5'*STRIDE)
        oracle.defined[n]=set(); oracle.put(STACK+0xf000,STOP)
        oracle.uc.reg_write(UC_X86_REG_ESP,STACK+0xf000)
        oracle.uc.reg_write(UC_X86_REG_ECX,BASE+0x7a4+n*STRIDE)
        oracle.run(0x40bbf0,STOP)
        oracle.put(0x458438,0);oracle.alloc=HEAP
        try: snapshots=[oracle.apply(s) for s in definitions]
        except OutsideDomain as error:
            excluded.append({'label':label,'reason':str(error)}); continue
        cases.append({'label':label,'definitions':definitions,'snapshots':snapshots})
    output=ROOT/'build/original/frame-oracle.json'
    output.parent.mkdir(parents=True,exist_ok=True)
    document={'exeSHA256':EXE_SHA256,'constructorVA':'0x40bbf0','entryVA':'0x4103f8','stopVA':'0x412277','cases':cases}
    output.write_text(json.dumps(document,ensure_ascii=True,separators=(',',':'))+'\n')
    if not args.corpus:
        dest=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-frames.json'
        dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(output.read_bytes())
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDFrameCheck'],check=True)
    subprocess.run([str(ROOT/'native/.build/release/NTSDFrameCheck'),str(output)],check=True)
    report={k:v for k,v in document.items() if k!='cases'}
    report.update(groups=len(cases),definitions=sum(len(c['definitions']) for c in cases),
                  fixturesSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),excluded=excluded,
                  scope='Decoded frame sections, Int32 decimal domain, sound device disabled; not complete object loading or gameplay.')
    path=ROOT/('docs/evidence/frame-corpus-oracle.json' if args.corpus else 'docs/evidence/frame-oracle.json')
    path.write_text(json.dumps(report,indent=2)+'\n')
    print(f"Compared {report['definitions']} definitions in {len(cases)} groups; {len(excluded)} groups outside verified domain.",flush=True)


if __name__=='__main__': main()
