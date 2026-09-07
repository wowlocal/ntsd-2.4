#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Original x86 movement reference for one unarmed Naruto, no other objects.

Executes input sampling, control, physics, arena constraints and frame scheduler.
Only memset and audio device entry points are replaced. See docs/MOVEMENT.md.
"""
import argparse, hashlib, json, random, struct, subprocess
from oracle_frames import OriginalFrames, BASE, STACK, STOP, FRAME_RE
from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_EIP

ACTOR, WORLD, INPUT, BG = 0x22000000, 0x23000000, 0x23001000, 0x24000000
MOVEMENT_FRAMES = set(range(4)) | set(range(5,12)) | set(range(210,220))
PARAMS = {'walking_frame_rate':0, 'walking_speed':8, 'walking_speedz':16,
 'running_frame_rate':24, 'running_speed':32, 'running_speedz':40,
 'heavy_walking_speed':48, 'heavy_walking_speedz':56, 'heavy_running_speed':64, 'heavy_running_speedz':72,
 'jump_height':80, 'jump_distance':88, 'jump_distancez':96, 'dash_height':104,
 'dash_distance':112, 'dash_distancez':120, 'rowing_height':128, 'rowing_distance':136}
INTS={'phase':0,'tap':4,'ix':16,'iy':20,'iz':24,'frame':112,'previousFrame':116,'wait':136}
DOUBLES={'vx':64,'vy':72,'vz':80,'x':88,'y':96,'z':104}
BYTES={'facing':128,'jumpBuffer':191,'rightBuffer':194,'leftBuffer':195,'upBuffer':196,'downBuffer':197}

class OriginalMovement(OriginalFrames):
    def __init__(self, obj, definitions):
        super().__init__(read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe'))
        self.events=[]; self.render_frame=0; self.render_facing=0
        for address,size in [(ACTOR,0x10000),(WORLD,0x10000),(BG,0x10000)]: self.uc.mem_map(address,size)
        for va in (0x4450a0,0x416fb0,0x417090): self.uc.hook_add(UC_HOOK_CODE,self.external,begin=va,end=va)
        for section in definitions: self.apply(section)
        for key,off in PARAMS.items():
            if off in (0,24): self.put(BASE+off,int(obj['header'][key]))
            else: self.double(BASE+off,float(obj['header'][key]))
        self.put(BASE+0x6f4,2); self.put(BASE+0x6f8,0)
        self.put(WORLD+0x194,ACTOR); self.uc.mem_write(WORLD+4,b'\x01')
        self.put(WORLD+0x7d4,BG-0x4d45db0)
        for offset,val in [(0,960),(4,450),(8,525)]: self.put(BG+offset,val)
        for va in (0x44d024,0x450bb4,0x450b80,0x450bb0,0x450b74,0x450b84): self.put(va,0)
        for i in range(8): self.put(0x450b4c+i*4,-1 if i==0 else 0)
        self.reset()

    def external(self,uc,addr,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP)
        if addr==0x4450a0:
            dest,val,count=[self.u32(sp+i) for i in (4,8,12)]
            uc.mem_write(dest,bytes([val&255])*count); uc.reg_write(UC_X86_REG_EAX,dest)
        else:
            a,b=self.u32(sp+4),self.u32(sp+8)
            if addr==0x416fb0:
                # cdecl(x, index); register paths resolved independently of global cache IDs.
                paths={self.u32(BASE+0x7a4+n*0x178+0x174):self.snapshot(n)['sound'] for n in MOVEMENT_FRAMES}
                self.events.append(paths.get(b,f'frame-index:{b}'))
            else: self.events.append(f'builtin:{b}')
        uc.reg_write(UC_X86_REG_ESP,sp+4); uc.reg_write(UC_X86_REG_EIP,self.u32(sp))

    def double(self,addr,value): self.uc.mem_write(addr,struct.pack('<d',value))
    def call(self,va,this=ACTOR,args=(),stop=STOP):
        sp=STACK+0xf000
        for i,v in enumerate((STOP,*args)): self.put(sp+4*i,v)
        self.uc.reg_write(UC_X86_REG_ESP,sp); self.uc.reg_write(UC_X86_REG_ECX,this)
        self.run(va,stop)
    def reset(self,initial=None):
        self.uc.mem_write(ACTOR,b'\0'*0x420)
        self.call(0x4061d0)
        self.put(ACTOR+0x368,BASE)
        # Controlled neutral practice spawn. Not the original match/spawn RNG.
        for key,val in {'x':480.,'y':0.,'z':490.,'vx':0.,'vy':0.,'vz':0.,**(initial or {})}.items():
            if key in DOUBLES: self.double(ACTOR+DOUBLES[key],val)
            elif key in INTS: self.put(ACTOR+INTS[key],val)
            elif key in BYTES: self.uc.mem_write(ACTOR+BYTES[key],bytes([val]))
        for integer,fp in [('ix','x'),('iy','y'),('iz','z')]:
            self.put(ACTOR+INTS[integer],int(struct.unpack('<d',self.uc.mem_read(ACTOR+DOUBLES[fp],8))[0]))
        self.events=[]
        self.render_frame=self.u32(ACTOR+0x70); self.render_facing=int(self.uc.mem_read(ACTOR+0x80,1)[0])
        self.put(0x450bc4,0); self.put(0x450bc8,0)
    def state(self):
        out={key:struct.unpack('<i',self.uc.mem_read(ACTOR+off,4))[0] for key,off in INTS.items()}
        out.update({key:struct.unpack('<d',self.uc.mem_read(ACTOR+off,8))[0] for key,off in DOUBLES.items()})
        out.update({key:int(self.uc.mem_read(ACTOR+off,1)[0]) for key,off in BYTES.items()})
        out['sounds']=self.events.copy()
        out['cameraX']=self.u32(0x450bc4)
        out['cameraVelocity']=struct.unpack('<i',self.uc.mem_read(0x450bc8,4))[0]
        out['renderFrame']=self.render_frame; out['renderFacing']=self.render_facing
        return out
    def tick(self,mask):
        assert mask & ~0xf4 == 0, 'Only arrows and jump in this milestone'
        self.events=[]; self.uc.mem_write(INPUT,bytes([mask])+b'\0'*7)
        self.call(0x4198f0,WORLD,(INPUT,0,INPUT+16))
        self.call(0x413080,args=(0,0))
        self.call(0x40e490)
        # Local-player camera; normalized reader above uses the replay input slot.
        self.put(0x450b4c,1)
        self.call(0x41b5d0,WORLD,(0,0),stop=0x41bc74)
        self.put(0x450b4c,-1)
        # Main loop calls actor drawing at 0x41f4a7 before scheduler 0x41fb06.
        self.render_frame=self.u32(ACTOR+0x70); self.render_facing=int(self.uc.mem_read(ACTOR+0x80,1)[0])
        self.call(0x40d960,args=(0,0))
        return self.state()

def scenarios():
    yield 'idle',{},[0]*30
    for name,mask in [('right',16),('left',32),('up',128),('down',64),('diagonal',144),('opposing',240)]:
        yield name,{},[mask]*100+[0]*30
    for delay in range(12):
        for name,mask in [('right',16),('left',32)]:
            yield f'double-{name}-{delay}',{},[mask]+[0]*delay+[mask]*24+[mask^48]*10+[0]*10
    for name,mask in [('still',0),('right',16),('left',32),('up',128),('down',64),('diagonal',144)]:
        yield f'jump-{name}',{},[mask|4]*5+[mask]*45+[0]*10
        yield f'hold-jump-{name}',{},[mask|4]*100+[0]*50
    yield 'run-dash',{},[16,0]+[16]*10+[20]*15+[36]*15+[0]*40
    yield 'run-dash-left',{},[32,0]+[32]*10+[36]*15+[20]*15+[0]*40
    yield 'jump-taps',{},sum(([20,16]*4+[16]*20 for _ in range(3)),[])
    for name,initial,mask in [('west',{'x':1},32),('east',{'x':959},16),('north',{'z':450},128),('south',{'z':525},64)]:
        yield name,initial,[mask|4]*40+[mask]*20
    # Fixed seed is test stimulus only; no native game RNG is inferred from it.
    rng=random.Random(0x24)
    for n in range(8):
        masks=[]
        for _ in range(100): masks += [rng.choice([0,16,32,64,128,144,80,160,96,48,192,240,4,20,36,132,68,148])]*rng.randrange(1,12)
        yield f'input-sequence-{n}',{},masks

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--trace',action='store_true'); args=ap.parse_args()
    obj=next(x for x in json.loads((ROOT/'build/imported/game.json').read_text())['objects'] if x['id']==2)
    definitions=[m[0] for m in FRAME_RE.finditer(obj['originalText']) if int(m[1]) in MOVEMENT_FRAMES]
    oracle=OriginalMovement(obj,definitions)
    cases=[]
    for label,initial,inputs in scenarios():
        oracle.reset(initial)
        states=[oracle.tick(mask) for mask in inputs]
        cases.append(dict(label=label,initial=initial,inputs=inputs,states=states))
        if args.trace and label in ('jump-still','run-dash'):
            for i,state in enumerate(states): print(label,i,inputs[i],state)
    document=dict(exeSHA256=EXE_SHA256,header=obj['header'],definitions=definitions,cases=cases)
    output=ROOT/'build/original/movement-oracle.json'; output.write_text(json.dumps(document,separators=(',',':'))+'\n')
    print(f'Captured {sum(len(c["states"]) for c in cases)} ticks across {len(cases)} sequences: {output}')
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDMovementCheck'],check=True)
    subprocess.run([str(ROOT/'native/.build/release/NTSDMovementCheck'),str(output)],check=True)
    fixtures={**document,'cases':[c for c in cases if not c['label'].startswith('input-sequence-')]}
    fixture_path=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-movement.json'
    fixture_path.write_text(json.dumps(fixtures,separators=(',',':'))+'\n')
    report=dict(exeSHA256=EXE_SHA256, sequences=len(cases), ticks=sum(len(c['states']) for c in cases),
                fixtureTicks=sum(len(c['states']) for c in fixtures['cases']),
                corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
                fixtureSHA256=hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
                addresses=dict(input='0x4198f0',control='0x413080',physics='0x40e490',boundsCamera='0x41b5d0..0x41bc74',scheduler='0x40d960'),
                scope='One unarmed Naruto, arrows/jump, neutral practice spawn, no enemies/items/combat. Exact numerical comparisons, not whole-match fidelity.')
    (ROOT/'docs/evidence/movement-oracle.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__': main()
