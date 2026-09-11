#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Retained installed-library character roster, teams and readiness across calls.
Pinned NTSD/lib/VC80/DAT/BMP/DIBs; controlled Unicorn2.1.4/CW023f. Build declared
catalog operand views from raw original resources, then execute actual41bc90
prologue and declared4229cc tail/429730/422ab8ret4 for each input step. Keep all
prior World/400Actor/resources/DC/stack bytes and masks between calls. Memory,
read/store/helper traces recover live Object binding and output order. Earlier
tick/acquisition/outer loop and own initialized library catalog remain open.
No private expected input, damaged pointer/protection structure, source fault
continuation or Windows/device/full-game claim. LIB_CHARACTER_ROSTER_PLAN.md.
"""
import argparse,datetime,hashlib,json,os,re,struct,traceback
from pathlib import Path
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
from oracle_fresh_character_menu import FreshCharacterMenu,specs as fresh_specs
from oracle_lib_menu_continuation import SP,TAIL_SP,LIB,BM,TARGET,STACK,WORLD,GLOBAL,REGISTERS,EXE_SHA256,DLL_SHA256,digest,STOP
from import_ntsd import DEFAULT_SOURCE,ROOT
from verify_character_roster_inputs import decode,text_read

CATALOG,OBJECTS,PORTRAITS=0x60000020,0x68000020,0x72000020
COUNT_OFFSET=0x4d82380

def roster_inputs():
 files={str(p.relative_to(DEFAULT_SOURCE)).replace('/','\\').lower():p for p in DEFAULT_SOURCE.rglob('*') if p.is_file()};pins={}
 def raw(name):
  p=files[name.lower()];value=p.read_bytes();pins[str(p.relative_to(DEFAULT_SOURCE))]=dict(bytes=len(value),sha256=digest(value));return value
 index=raw('data\\data.txt');section=text_read(index).split(b'<object>',1)[1].split(b'<object_end>',1)[0]
 entries=re.findall(rb'id:\s*([+-]?\d+)\s+type:\s*([+-]?\d+)\s+file:\s*([^\s]+)',section);assert len(entries)==137
 result=[]
 for ordinal,(object_id,kind,path) in enumerate(entries):
  path=path.decode('latin1');decoded=decode(raw(path),path)
  header=decoded.split(b'<bmp_begin>',1)[1].split(b'<bmp_end>',1)[0] if b'<bmp_begin>' in decoded else b''
  tokens=re.findall(rb'[^ \t\r\n\v\f]+',header);names=[tokens[i+1] for i,t in enumerate(tokens[:-1]) if t==b'name:'];heads=[tokens[i+1] for i,t in enumerate(tokens[:-1]) if t==b'head:']
  tail=bytearray(b'\xa5'*60);mask=bytearray(60)
  for name in [b'none']+names:
   assert len(name)<60 and b'\0' not in name;tail[:len(name)+1]=name+b'\0';mask[:len(name)+1]=b'\1'*(len(name)+1)
  portrait=None
  if heads:
   head=heads[-1].decode('latin1');bmp=raw(head);assert bmp[:2]==b'BM';width,height=struct.unpack_from('<ii',bmp,18);assert width>0 and height>0
   portrait=dict(path=head,width=width,height=height,address=PORTRAITS+ordinal*0x2000,surface=0x24000000)
  if int(kind)==0:assert portrait is not None
  result.append(dict(ordinal=ordinal,id=int(object_id),type=int(kind),path=path,address=OBJECTS+ordinal*0x40000,nameTail=tail.hex(),nameMask=mask.hex(),portrait=portrait))
 assert len(pins)==180
 # The accepted audit supplies immutable source-file pins, not field values or
 # reference pointer addresses. All operand values above came from raw files.
 audit=json.loads((ROOT/'build/research/character-roster-input-audit.json').read_bytes());assert pins==audit['sourceFiles']
 return dict(entries=result,sourceFiles=pins,registryAddress=CATALOG,countOffset=COUNT_OFFSET)

def sequence(control):
 first=next(s for s in fresh_specs() if s['label']=='initialize-mode-0'+('-control' if control else ''))
 first['label']='initial'+('-control' if control else '');first['globals'][0x458428]=0
 out=[first]
 def frame(label,changes=()):out.append(dict(label=label+('-control' if control else ''),control=control,chain=True,buttons=[list(x) for x in changes]))
 def edge(label,seats,button,held=False):
  frame(label+'-press',[(s,button,1) for s in seats])
  if held:frame(label+'-held')
  frame(label+'-release',[(s,button,0) for s in seats])
 frame('release-initial')
 edge('join',(0,1),0xd1,True);edge('first-eligible',(0,1),0xd0,True)
 for i in range(4):edge('sasuke-right-'+str(i),(1,),0xd0)
 edge('naruto-random',(0,),0xcd);edge('random-left-last',(0,),0xcf)
 edge('last-right-random',(0,),0xd0);edge('random-right-naruto',(0,),0xd0)
 edge('confirm-character',(0,1),0xd1,True)
 frame('teams-press',[(0,0xd0,1),(1,0xcf,1)]);frame('teams-held');frame('teams-release',[(0,0xd0,0),(1,0xcf,0)])
 edge('ready',(0,1),0xd1,True);edge('countdown-jump',(1,),0xd2)
 assert len(out)==35
 return out

class Roster(FreshCharacterMenu):
 def __init__(self,control,inputs):
  super().__init__(control);self.roster=inputs
  for p,n in ((CATALOG&~0xffff,0x4d90000),(OBJECTS&~0xffff,0x2250000),(PORTRAITS&~0xffff,0x60000)):
   assert all(p+n<=a or p>b for a,b,_ in self.uc.mem_regions()),(hex(p),n)
   self.uc.mem_map(p,n);self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=p,end=p+n-1)
  self.add_region(CATALOG,b'\xa5'*(137*4),False);self.add_region(CATALOG+COUNT_OFFSET,b'\xa5'*4,False)
  self.write(CATALOG,struct.pack('<137I',*[x['address'] for x in inputs['entries']]));self.write(CATALOG+COUNT_OFFSET,struct.pack('<I',137));self.write(WORLD+0x7d4,struct.pack('<I',CATALOG))
  for item in inputs['entries']:
   p=item['address'];self.add_region(p+0x6f4,b'\xa5'*12,False);self.write(p+0x6f4,struct.pack('<ii',item['id'],item['type']))
   tail=bytes.fromhex(item['nameTail']);mask=bytes.fromhex(item['nameMask']);self.add_region(p+0x25324,tail,False);self.regions[p+0x25324]['mask']=bytearray(mask)
   if item['portrait']:
    pic=item['portrait'];self.write(p+0x6fc,struct.pack('<I',pic['address']));self.add_region(pic['address'],b'\xa5'*0x1f50,False)
    self.write(pic['address'],struct.pack('<Iii',pic['surface'],pic['width'],pic['height']))
  for p in self.actors:self.write(p+0x368,struct.pack('<I',OBJECTS))
 def next_step(self,spec):
  assert self.end=='returned' and not self.pending and not self.graphics.helpers and not self.music.music_pending
  self.running=False;self.spec=spec;stimulus=[]
  for seat,off,value in spec['buttons']:
   assert seat in (0,1) and off in (0xcd,0xcf,0xd0,0xd1,0xd2) and value in (0,1)
   p=self.actors[seat]+off;self.write(p,bytes([value]));stimulus.append(dict(address=p,bytes=bytes([value]).hex()))
  # Only externally supplied ordinary call-frame words; retain all other stack
  # storage and masks from the previous real return. No full stack reset.
  abi=[]
  for p,v in ((SP,STOP),(SP+4,TARGET),(TAIL_SP+0x68,TARGET)):
   self.write(p,struct.pack('<I',v));abi.append(dict(address=p,bytes=struct.pack('<I',v).hex()))
  for r,v in zip(REGISTERS,self.saved):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_ESP,SP);assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f
  self.events=[];self.writes=[];self.reads=[];self.api_reads=[];self.helpers=[];self.pending=[];self.pcs={};self.clip=None;self.bitmap_active=None;self.fill_before=None;self.end=None;self.scans={};self.points=[];self.screenSP=None;self.character_sp=None
  self.startup_done=False;g=self.graphics;g.events=[];g.returns_resource=[];g.checkpoints=[];self.music.music_calls=[]
  before=self.snapshot();self.running=True;self.prologue=True
  try:
   self.uc.emu_start(0x41bc90,0,count=1000);self.prologue=False;assert self.uc.reg_read(UC_X86_REG_ESP)==TAIL_SP
   self.point('declaredTail');self.uc.reg_write(UC_X86_REG_EBX,WORLD)
   self.uc.emu_start(0x4229cc,0,count=2_000_000);assert self.end=='returned'
  except Exception as e:
   f=self.capture_path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),error=repr(e),errorText=str(e),traceback=traceback.format_exc(),pc=hex(self.uc.reg_read(UC_X86_REG_EIP)),spec=spec,before=before,after=self.snapshot(),events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.running=False
  assert not g.helpers and not self.music.music_pending
  startup=dict(spec=dict(label=spec['label'],ramp=self.control,reverse=self.control,kind='retained'),before=dict(globals=next(x['storage']['bytes'] for x in before if x['address']==GLOBAL),cw=0x23f,sp=SP),after=self.startup_after,allocations=g.allocations_resource,checkpoints=g.checkpoints,records=g.records(),events=g.events,helpers=g.returns_resource,images=dict(g.images),surfaces=dict(g.surfaces),dcs=dict(g.dcs),end='ready',musicBoundary=self.music_boundary,musicAllocations=self.music_records(),musicInput=self.music.music_input,musicCalls=self.music.music_calls)
  return dict(spec=spec,before=before,after=self.snapshot(),stimulus=stimulus,callerABI=abi,events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,end=self.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),cw=self.uc.reg_read(UC_X86_REG_FPCW),scans=self.scans,points=self.points,actorAddresses=self.actors,screenSP=self.screenSP,characterSP=self.character_sp,output=self.output,saved=self.saved,startup=startup)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();manifest=[s for control in (False,True) for s in sequence(control)]
 if a.manifest_only:a.output.write_text(json.dumps(manifest,indent=2)+'\n');print('Finite calls',len(manifest));raise SystemExit(0)
 inputs=roster_inputs();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={}
 for control in (False,True):
  vm=Roster(control,inputs);vm.capture_path=a.output
  for index,spec in enumerate(sequence(control)):
   if a.limit is not None and len(cases)>=a.limit:break
   c=vm.probe(spec) if index==0 else vm.next_step(spec)
   # Freeze metadata values too: subsequent calls retain emulator storage,
   # never mutate the already completed atomic cases in this document.
   c=json.loads(json.dumps(c));number=len(cases);temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets),separators=(',',':'))+'\n');os.replace(temp,part);cases.append(c);installations.append(vm.installation)
   for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
   for k,v in vm.graphics.assets.items():assert k not in assets or assets[k]==v;assets[k]=v
   print('completed',number,spec['label'],[vm.u32(0x451248+i*4) for i in range(2)],[vm.u32(0x451288+i*4) for i in range(2)],len(c['events']),flush=True)
  if a.limit is not None and len(cases)>=a.limit:break
  assert [vm.u32(0x451248+i*4) for i in range(2)]==[17,21] and [vm.u32(0x451288+i*4) for i in range(2)]==[3,3]
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,installations=installations,assets=assets,roster=inputs,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
