#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real round-control41d714 after reproduced loading/local/control/replay parents.
Executes nonpaused counters, living-team checks, round acknowledgement and the
whole restoration loop to41e339/4229cc/422a95. Paused execution stops41d73b
BEFORE rendering; gameplay/menu/epilogue are explicit continuations, not stubs.
Real402100/401a30/4061d0/431c70/43df00 run through their returns. Only declared
COM results and inherited CRT/device/loading boundaries remain supplied.
"""
import argparse
import json
import struct
import subprocess
from import_ntsd import ROOT, EXE_SHA256
from oracle_replay_tick import ReplayTick
from oracle_input_control import BUFFERS, API, signed
from oracle_initial_loading import InitialLoading, transport, WORLD, POOL
from oracle_catalog_sounds import REGISTERS, pack
from oracle_wave_loader import VTABLE, digest
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESI, UC_X86_REG_ESP

ENDS={0x41D73B:'pausedRendering',0x41E339:'gameplay',0x4229CC:'menu',0x422A95:'epilogue'}
HELPERS={0x402100:('stopMusic',0x40212B,0),0x401A30:('soundRequest',0x401A6F,1),
         0x4061D0:('reconstruct',0x4064CC,0),0x431C70:('inputReset',0x431D0D,0),0x43DF00:('restorePlayback',0x43DF93,0)}


class MatchRound(ReplayTick):
    def __init__(self,control=False,**loading_options):
        super().__init__(control,**loading_options);self.round_running=False;self.round_pending=None
        for pc in [*ENDS,*HELPERS,*[h[1] for h in HELPERS.values()],0x41DB13,0x41DD02]:
            self.uc.hook_add(UC_HOOK_CODE,self.round_hook,begin=pc,end=pc)

    def memset(self,uc,address,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP)
        if self.round_running and self.u32(sp)==0x406447:
            dst,value,count=[self.u32(sp+i) for i in (4,8,12)]
            assert self.round_pending and self.round_pending['entry']==0x4061D0
            assert dst==self.round_pending['this']+0xF0 and value==0 and count==400
            return InitialLoading.memset(self,uc,address,size,data)
        super().memset(uc,address,size,data)

    def control_helper(self,uc,address,size,data):
        if not self.round_running:super().control_helper(uc,address,size,data)

    def control_imported(self,uc,address,size,data):
        if not self.round_running:return super().control_imported(uc,address,size,data)
        method=self.control_imports[address];assert isinstance(method,tuple)
        offset,count=method;sp=uc.reg_read(UC_X86_REG_ESP)
        args=[self.u32(sp+4),offset]+[self.u32(sp+4+i*4) for i in range(1,count)]
        self.round_event('method',args,self.round_method_result);self.ret(self.round_method_result,count*4)

    def round_event(self,kind,args=(),response=None):
        self.round_events.append(dict(kind=kind,arguments=list(args),response=response))

    def round_hook(self,uc,address,size,data):
        if not self.round_running:return
        sp=uc.reg_read(UC_X86_REG_ESP)
        if address in ENDS:self.round_end=address;uc.emu_stop();return
        if address in HELPERS:
            assert self.round_pending is None
            kind,stop,count=HELPERS[address];this=uc.reg_read(UC_X86_REG_ECX)
            args=[self.u32(sp+4+i*4) for i in range(count)]
            self.round_pending=dict(entry=address,entrySP=sp,returnAddress=self.u32(sp),this=this,arguments=args,saved=[uc.reg_read(r) for r in REGISTERS])
            observed=[next(i for i,r in enumerate(self.pool) if r['address']==this)] if kind=='reconstruct' else [this,*args] if kind=='soundRequest' else []
            if kind=='inputReset':assert this==self.world_address
            self.round_event(kind,observed)
        elif address==0x41DB13:self.round_event('teams',[self.u32(self.body_sp+0x74+i*4) for i in range(40)])
        elif address==0x41DD02:self.round_event('stageScan',[uc.reg_read(UC_X86_REG_EDI)])
        else:
            c=self.round_pending;assert c and address==HELPERS[c['entry']][1] and sp==c['entrySP']
            assert [uc.reg_read(r) for r in REGISTERS]==c['saved']
            c['returnSP']=sp+4+4*HELPERS[c['entry']][2];self.round_calls.append(c);self.round_pending=None

    def round_step(self,label,s=None,paused=0,inherited=False,method_result=-2147467259):
        s=json.loads(json.dumps(s or dict(globals=[],actors=[],world=[],seats=[],bindings=[],saved=None,pointers=None,buffers=[],live=None,commands=None,playback=None)))
        for w in s['globals']:self.uc.mem_write(w['address'],bytes.fromhex(w['bytes']))
        for w in s['actors']:self.write_host(self.pool[w['slot']]['address']+w['offset'],bytes.fromhex(w['bytes']))
        for w in s['world']:self.write_host(self.world_address+w['offset'],bytes.fromhex(w['bytes']))
        for i,slot in enumerate(s['seats']):self.write_host(self.world_address+0x194+i*4,struct.pack('<I',self.pool[slot]['address']))
        for i,ordinal in enumerate(s['bindings']):self.write_host(self.pool[i]['address']+0x368,struct.pack('<I',self.object_addresses[ordinal]))
        if s['saved'] is not None:self.uc.mem_write(0x458588,bytes(s['saved']))
        if s['pointers'] is not None:self.uc.mem_write(0x4588A8,struct.pack('<II',*s['pointers']))
        for w in s['buffers']:self.uc.mem_write(BUFFERS[w['index']]+w['offset'],bytes.fromhex(w['bytes']))
        if not inherited:
            for r,v in [(UC_X86_REG_ESP,self.body_sp),(UC_X86_REG_EBX,self.world_address),(UC_X86_REG_ESI,self.u32(0x44D020))]:self.uc.reg_write(r,v)
            self.put(self.body_sp+0x38,paused);self.put(self.body_sp+0x64,0x99887766)
            self.uc.mem_write(self.body_sp+0x430,bytes([0xA5])*28)
        before=list(self.uc.mem_read(self.body_sp+0x430,28));self.round_events=[];self.round_calls=[];self.round_end=None
        self.round_method_result=method_result;self.round_running=self.control_running=True;self.phase='match-round'
        try:
            pc=0x41D714
            for _ in range(20):
                self.uc.emu_start(pc,0,count=2_000_000);pc=self.uc.reg_read(UC_X86_REG_EIP)
                if self.round_end is not None:break
            assert self.round_end in ENDS and self.round_pending is None and self.uc.reg_read(UC_X86_REG_ESP)==self.body_sp
            assert not self.reads_before_writes,sorted(self.reads_before_writes)[:8]
        except Exception:
            print('ROUND FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.round_events[-3:],flush=True);raise
        finally:self.round_running=self.control_running=False
        return dict(label=label,stimulus=s,paused=paused,inherited=inherited,methodResult=method_result,events=self.round_events,calls=self.round_calls,
                    stackBefore=before,stackAfter=list(self.uc.mem_read(self.body_sp+0x430,28)),
                    stageDefeated=None if paused else self.u32(self.body_sp+0x64),continuation=ENDS[self.round_end],endPC=self.round_end,after=self.control_snapshot())

    def capture_parent_round(self):
        parents,initial,natural=self.capture_parent_replay();suffix='-control' if self.control else ''
        r=json.loads((ROOT/'docs/evidence'/f'replay-tick{suffix}.json').read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
        assert digest(raw)==r['sha256'];old=json.loads(raw);assert parents==old['parents']
        assert transport(dict(initialContext=initial,case=natural),self.blobs)==transport(dict(initialContext=old['initialContext'],case=old['cases'][0]),old['blobs'])
        parents['replay-tick']=dict(fixture=r['fixture'],sha256=r['fixtureSHA256']);del old,raw
        for offset,count in [(0x24,1),(0x20,3)]:
            a=self.control_api+0x100+offset*4;self.put(VTABLE+offset,a);self.control_imports[a]=(offset,count)
        initial=self.control_snapshot();natural=self.round_step('natural-first-round',paused=int(self.control),inherited=True)
        print('Pinned replay parent reproduced; natural round continuation',natural['continuation'],flush=True)
        return parents,initial,natural

    def capture_round(self):
        parents,initial,natural=self.capture_parent_round();cases=[natural]

        def word(s,address,value):s['globals'].append(dict(address=address,bytes=struct.pack('<I',value&0xFFFFFFFF).hex()))
        def actor(s,slot,offset,value,byte=False):s['actors'].append(dict(slot=slot,offset=offset,bytes=struct.pack('<B' if byte else '<I',value&(255 if byte else 0xFFFFFFFF)).hex()))
        def inputs(mode=0,menu=0,timer=0,teams=2,stage=0,auto=1,slots=(0,1,399),music=False):
            values={0x451160:mode,0x44D020:menu,0x450BDC:timer,0x450BFC:0,0x450C00:17,0x450BD0:0,0x450BD4:0,0x450BD8:0,
                    0x450BF8:173,0x450BA8:stage,0x450C2C:auto,0x451B7C:0,0x44D02C:0,0x450B94:37,0x450B88:0,0x450B84:0,
                    0x458428:0,0x44F04C:self.u32(0x452948) if music else 0,0x44F044:self.u32(0x45294C) if music else 0,
                    0x45561C:self.u32(0x452950)}
            active=[0]*400
            for i in range(teams):active[i]=1
            s=dict(globals=[],actors=[],world=[dict(offset=4,bytes=bytes(active).hex())],seats=list(range(400)),bindings=[0]*400,
                   saved=None,pointers=None,buffers=[],live=None,commands=None,playback=None)
            for a,v in values.items():word(s,a,v)
            for slot in slots:
                raw=bytearray((i+slot)%256 for i in range(0x6C))
                for offset,value in [(0x2FC,501),(0x300,503),(0x308,29),(0x324,-1),(0x328,-1),(0x32C,399),(0x330,-999),(0x334,-999),(0x364,slot+1)]:
                    struct.pack_into('<I',raw,offset-0x2FC,value&0xFFFFFFFF)
                s['actors'] += [dict(slot=slot,offset=0x2FC,bytes=raw.hex()),dict(slot=slot,offset=0xCD,bytes=bytes(7).hex()),
                                dict(slot=slot,offset=0x10,bytes=struct.pack('<iii',-123,73,321).hex()),dict(slot=slot,offset=0x80,bytes='80')]
            return s

        for paused in (0,1,-1):
            for flag in (-1,0,1,2,3,2147483647):
                s=inputs();word(s,0x450BFC,flag);cases.append(self.round_step(f'pause-flag-{paused}-{flag}',s,paused=paused))
        modes=(-2147483648,-1,0,1,2,3,4,5,6,7,2147483647)
        for mode in modes:
            for menu in (0,1,10):
                for teams in (0,1,2):
                    for timer in (0,79,144,145,349,350,2147483647,-2147483648):
                        cases.append(self.round_step(f'round-{mode}-{menu}-{teams}-{timer}',inputs(mode,menu,timer,teams,music=timer==79)))
        for address in (0x450BD0,0x450BD4,0x450BD8):
            for value in (-2147483648,-13,-3,-1,0,1,2,3,11,12,2147483647):
                s=inputs();word(s,address,value);cases.append(self.round_step(f'counter-{address:x}-{value}',s))
        for gate in (-2147483648,-1,0,1,2,2147483647):
            for teams in (0,1,2):
                s=inputs(mode=4,timer=79,teams=teams);word(s,0x451B7C,gate)
                cases.append(self.round_step(f'mode4-completion-gate-{gate}-{teams}',s))
        for mode in (0,1):
            for team in (-2147483648,-1,*range(42),2147483647):
                s=inputs(mode=mode,teams=1,timer=79);actor(s,0,0x364,team);cases.append(self.round_step(f'team-{mode}-{team}',s))
            for hp in (-2147483648,-1,0,1,2147483647):
                for activity in (0,1,2,128,255):
                    s=inputs(mode=mode,teams=1);s['world'][0]['bytes']=(bytes([activity])+bytes(399)).hex();actor(s,0,0x2FC,hp)
                    cases.append(self.round_step(f'alive-{mode}-{hp}-{activity}',s))
        for ordinal in range(len(self.object_addresses)):
            s=inputs(mode=ordinal%2,teams=1,timer=79);s['bindings'][0]=ordinal
            cases.append(self.round_step(f'original-type-{ordinal}',s))
        for lane in range(10):
            s=inputs(mode=lane%2,teams=0,slots=range(400));active=bytes([1,2,128,255,0][(i+lane)%5] for i in range(400));s['world'][0]['bytes']=active.hex()
            for i in range(400):
                actor(s,i,0x364,(i+lane)%41);s['bindings'][i]=(i+lane)%len(self.object_addresses)
            if lane>=5:s['seats']=[399-i if lane%2 else 0 for i in range(400)]
            cases.append(self.round_step(f'whole-pool-lanes-aliases-{lane}',s))
        print('Round gates, counters and all source Object types captured',flush=True)
        for stage in (-2147483648,-1,0,1,2,3,2147483647):
            for teams in (0,1):
                for menu in (0,1):
                    for auto in (0,1):
                        s=inputs(mode=1,menu=menu,teams=teams,timer=79,stage=stage,auto=auto,music=True)
                        cases.append(self.round_step(f'stage-{stage}-{teams}-{menu}-{auto}',s,method_result=1 if auto else -1))
        for mask in range(256):
            s=inputs(mode=mask%6,timer=144,stage=(mask//6)%4,auto=(mask//24)%2,slots=range(8))
            for seat in range(8):
                actor(s,seat,0xD1 if seat%2 else 0xD2,1 if mask&(1<<seat) else 0,True)
            word(s,0x450B94,[-2147483648,-11,-1,0,19,2147483647][mask%6])
            cases.append(self.round_step(f'acknowledge-{mask}',s))
        for byte in (0,1,2,128,255):
            for seat in range(8):
                for offset in (0xD1,0xD2):
                    s=inputs(timer=144,slots=range(8));actor(s,seat,offset,byte,True);cases.append(self.round_step(f'ack-byte-{offset:x}-{seat}-{byte}',s))
        ids=[signed(self.u32(a+0x6F4)) for a in self.object_addresses]
        for source_id in [*ids,-1,0x7FFFFFFF]:
            s=inputs(timer=350,teams=1);actor(s,0,0x324,source_id)
            cases.append(self.round_step(f'restore-source-id-{source_id}',s))
        for enabled in (0,1,-1):
            if 50 in ids:
                s=inputs(timer=350,teams=1);s['bindings'][0]=ids.index(50);word(s,0x458428,enabled)
                actor(s,0,0x328,0);cases.append(self.round_step(f'original-id50-flag-{enabled}',s))
        for target in (0,1,7,10,399):
            for first in (ids[0],ids[1],ids[-1],-999):
                for second in (ids[0],ids[1],ids[-1],-999):
                    s=inputs(timer=350,teams=1,slots=set([0,1,target,399]))
                    word(s,0x458428,1) # Reach split restoration instead of the original ID50 branch.
                    for offset,value in [(0x328,0),(0x32C,target),(0x330,first),(0x334,second)]:actor(s,0,offset,value)
                    cases.append(self.round_step(f'split-restore-{target}-{first}-{second}',s))
        for target in (0,399):
            for value in (-2147483648,-3,-1,0,1,3,2147483647):
                s=inputs(timer=350,teams=1);word(s,0x458428,1)
                for offset,v in [(0x328,0),(0x32C,target),(0x2FC,value),(0x300,value),(0x10,value),(0x18,value)]:actor(s,0,offset,v)
                cases.append(self.round_step(f'split-signed-half-{target}-{value}',s))
        for mode in modes:
            for pointer in (0,BUFFERS[1]):
                s=inputs(mode=mode,timer=350,teams=1);word(s,0x450B88,-1);word(s,0x450B84,1);s['pointers']=[BUFFERS[0],pointer]
                saved=bytearray(0x320)
                for offset,value in [(0,b'round-description'),(0x1F8,b'round-label'),(0x260,b'round-arena')]:saved[offset:offset+len(value)+1]=value+b'\0'
                saved[0x1F4]=0x80
                for i in range(8):saved[0x2C8+i*11:0x2C8+i*11+2]=bytes([65+i,0])
                s['saved']=list(saved);s['buffers']=[dict(index=1,offset=0x630BB8,bytes=struct.pack('<ii',-17,2147483647).hex())]
                cases.append(self.round_step(f'replay-finish-{mode}-{pointer:x}',s))
        for i in range(275):
            s=inputs(timer=75,teams=1,music=True) if i==0 else None
            cases.append(self.round_step(f'consecutive-round-{i}',s))
        print('Round acknowledgement, restoration and consecutive outcome captured',flush=True)
        return transport(dict(exeSHA256=EXE_SHA256,scope=__doc__,control=self.control,parents=parents,worldAddress=self.world_address,
            objectAddresses=self.object_addresses,actorAddresses=[r['address'] for r in self.pool],bodySP=self.body_sp,bufferAddresses=BUFFERS,
            initialContext=initial,cases=cases),self.blobs)


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    pending=[]
    for suffix in ('','-control'):
        path=ROOT/'docs/evidence'/f'match-round{suffix}.json';r=json.loads(path.read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes();assert digest(raw)==r['sha256']
        doc=json.loads(raw);temp=ROOT/'build/original'/f'match-round{suffix}-check.json';temp.write_text(pack(doc));fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
        parents=[str(fixtures/doc['parents'][k]['fixture']) for k in ('replay-tick','input-control','local-input','initial-loading','initial-loading-catalog','initial-loading-sounds')]
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--match-round',str(temp),*parents],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        fixture=fixtures/('original-'+r['corpus']);data=temp.read_bytes();r.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data),parents=doc['parents'])
        pending.append((path,r,fixture,data))
    for path,r,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(r,indent=2)+'\n')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
    if a.accept:accept();return
    vm=MatchRound(a.control);d=vm.capture_round();suffix='-control' if a.control else '';path=ROOT/'build/original'/f'match-round{suffix}.json'
    path.write_text(json.dumps(d,separators=(',',':'))+'\n')
    counts={k:sum(e['kind']==k for c in d['cases'] for e in c['events']) for k in ('teams','stageScan','stopMusic','soundRequest','method','reconstruct','inputReset','restorePlayback')}
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(path.read_bytes()),cases=len(d['cases']),events=counts,
                continuations={v:sum(c['continuation']==v for c in d['cases']) for v in ENDS.values()},nativeComparison='pending')
    (ROOT/'docs/evidence'/f'match-round{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print('Captured',len(d['cases']),'match round cases',counts,flush=True)


if __name__=='__main__':main()
