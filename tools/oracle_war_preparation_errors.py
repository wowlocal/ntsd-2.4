#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Ordinary resource/API/allocation errors in whole NTSD War preparation.
Pinned EXE/lib.dll/VC80 and original DAT/BMP resources run in Unicorn2.1.4,
CW023f/C locale. Each separate scenario reproduces401 constructors and ten
accepted whole parent calls, then declares only the documented platform error.
Full bytes/masks/reads/writes/stack/FPU/helper/API/lifetime traces distinguish
normal returns, partial resource owners and actual invalid-memory boundaries.
For eight returned bitmap-error cases, one declared next-Start99 studies release
of their actual owners. No continuation after a source fault, memory/control/
protection corruption, address0 mapping, bypass or Windows/device claim. All
EXE/DLL execution is research tooling. LIB_WAR_PREPARATION_ERRORS_PLAN.md freezes
29 independent scenarios/at most37 new calls; preserve every completed file,
prefix proof and failure. Never restart a live job or retry a safety refusal.
"""
import argparse,copy,datetime,hashlib,json,os,shutil,struct,traceback
from pathlib import Path
from unicorn import UC_HOOK_MEM_INVALID,UcError
from unicorn.x86_const import *
from oracle_lib_war_preparation_matrix import WarPreparationMatrix
from oracle_lib_war_preparation_bound import specifications as bound_specs
from oracle_lib_war_preparation import tournament_inputs,arena_inputs,catalog_input
from oracle_lib_war_preparation import ROOT,EXE_SHA256,DLL_SHA256,WORLD,REPLAY,SP,TAIL_SP
from oracle_lib_team_tournament_preparation import PREP_API,REPLAY_SIZE
from oracle_lib_war_setup import WarSetup

BASE=ROOT/'build/research/lib-war-preparation'
NOW=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()

def canonical(x):return json.dumps(x,separators=(',',':')).encode()
def sha(raw):return hashlib.sha256(raw).hexdigest()

def scenarios():
 out=[dict(label='normal-primary',control=False),dict(label='normal-control',control=True)]
 for kind in ('wrapperNull','imageMissing','createSurface','colorKey'):
  for layer in (0,4):out.append(dict(label=kind+'-'+str(layer),control=False,graphics=dict(kind=kind,layer=layer),release=True))
 for kind,result in [('getObject',0),('description',-1),('getDC',-1),('restore',-1),('createDC',0),('selectObject',0),('stretch',0),('releaseDC',-1),('deleteDC',0),('deleteObject',0)]:
  out.append(dict(label=kind+'-first',control=False,graphics=dict(kind=kind,layer=0,result=result)))
 out.append(dict(label='music-create',control=False,music=dict(createResult=-1,createPointer=0)))
 for i in range(4):out.append(dict(label='music-query-'+str(i),control=False,musicQuery=i))
 out += [dict(label='music-wide-null',control=False,music=dict(nullAllocation=True)),
         dict(label='music-render',control=False,music=dict(renderResult=-1)),
         dict(label='music-conversion',control=False,music=dict(conversion='none',conversionResult=0)),
         dict(label='replay-null',control=False,replayNull=True)]
 assert len(out)==29 and sum(s.get('release',False) for s in out)==8
 return out

class ErrorPreparation(WarPreparationMatrix):
 def __init__(self,*args):
  super().__init__(*args);self.invalid_accesses=[];self.error_input=None
  self.uc.hook_add(UC_HOOK_MEM_INVALID,self.invalid)
 def registers(self):
  return {name:self.uc.reg_read(reg) for name,reg in [('eax',UC_X86_REG_EAX),('ebx',UC_X86_REG_EBX),('ecx',UC_X86_REG_ECX),('edx',UC_X86_REG_EDX),('esi',UC_X86_REG_ESI),('edi',UC_X86_REG_EDI),('ebp',UC_X86_REG_EBP),('esp',UC_X86_REG_ESP),('eip',UC_X86_REG_EIP),('eflags',UC_X86_REG_EFLAGS)]}
 def invalid(self,u,access,address,size,value,data):
  self.invalid_accesses.append(dict(timeUTC=NOW(),access=access,address=address,size=size,value=value,registers=self.registers(),fpu=self.fpu()))
  return False
 def code(self,u,pc,n,data):
  active=self.running and not self.prologue and self.startup_done and not self.constructing
  if active and pc==0x43a21f:
   super().code(u,pc,n,data)
   stimulus=self.spec.get('resourceFailure',{});g=self.preparation_graphics
   applied=dict(declared=copy.deepcopy(stimulus),entryPC=pc,graphics={},music={})
   cfg=stimulus.get('graphics')
   if cfg:
    kind,layer=cfg['kind'],cfg['layer'];assert layer in (0,4)
    if kind=='wrapperNull':g.error_null_layer=g.allocation_start+layer;applied['graphics']['nullAllocationOrdinal']=g.error_null_layer
    elif kind=='imageMissing':g.rs['missing']=[g.loader_index+1+layer];applied['graphics']['missingLoaderIndices']=g.rs['missing']
    else:
     key=kind+'#'+str(g.counts[kind]+1+layer);g.rs['results']={key:cfg.get('result',-1)};applied['graphics']['results']=dict(g.rs['results'])
   self.music.music_input.update(stimulus.get('music',{}))
   if 'musicQuery' in stimulus:
    i=stimulus['musicQuery'];self.music.music_input['queryResults']=list(self.music.music_input['queryResults']);self.music.music_input['queryPointers']=list(self.music.music_input['queryPointers'])
    self.music.music_input['queryResults'][i]=-1;self.music.music_input['queryPointers'][i]=0
   applied['music']=copy.deepcopy(self.music.music_input)
   self.error_input=applied
   original_code=g.code
   def bitmap_code(uc,address,size,opaque):
    if address==0x4450ac and len(g.allocations_resource)==getattr(g,'error_null_layer',-1):
     g.finish(address);sp=uc.reg_read(UC_X86_REG_ESP);assert g.u32(sp)==0x40c08a and g.u32(sp+4)==0x1f50
     index=len(g.allocations_resource);g.allocations_resource.append(dict(address=0,backing=None))
     g.append(dict(kind='allocate',index=index,address=0,count=0x1f50,storeCount=len(self.writes)));g.ret(0);return
    return original_code(uc,address,size,opaque)
   g.code=bitmap_code
   return
  if active and self.preparing:
   sp=u.reg_read(UC_X86_REG_ESP)
   if pc==0x4450c8 and self.spec.get('resourceFailure',{}).get('music',{}).get('nullAllocation'):
    count=self.u32(sp+4);assert self.u32(sp)==0x401e36 and 0<count<0x1000
    self.music.mevent('allocate',[count],pointer=0,raw=None);self.ret(0);return
   if pc==PREP_API+16 and self.spec.get('resourceFailure',{}).get('replayNull'):
    assert self.u32(sp)==0x43d2de and [self.u32(sp+4),self.u32(sp+8)]==[1,REPLAY_SIZE]
    self.event('calloc',[0,1,REPLAY_SIZE]);self.ret(0);return
  return super().code(u,pc,n,data)
 def complete_case(self,c):
  c=WarSetup.complete_case(self,c)
  if self.preparation_seen:
   g=self.preparation_graphics
   c['preparationGraphics']=dict(events=g.events,allocations=g.allocations_resource,records=g.records(),helpers=g.returns_resource,
    images=g.images,surfaces=g.surfaces,dcs=g.dcs,wrapperLive={str(a['address']):self.live[a['address']] for a in g.allocations_resource if a['address']},
    allocationStart=g.allocation_start,constructionHistory=g.history+g.returns_resource)
   c['replayAddress']=self.u32(0x4588a8);c['resourceFailureInput']=self.error_input
  return c

def save(path,document):
 assert not path.exists();temp=path.with_suffix('.tmp');assert not temp.exists()
 with temp.open('x') as f:json.dump(document,f,separators=(',',':'));f.write('\n');f.flush();os.fsync(f.fileno())
 os.replace(temp,path)
 return dict(path=str(path),bytes=path.stat().st_size,sha256=sha(path.read_bytes()))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--scenario',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args()
 assert not a.output.exists()
 manifest=scenarios()
 if a.manifest_only:save(a.output,dict(scope=__doc__,scenarios=manifest));print('scenarios',len(manifest));return
 assert a.scenario in range(len(manifest));scenario=manifest[a.scenario]
 inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input();vm=ErrorPreparation(scenario['control'],inputs,arenas,catalog)
 directory=a.output.with_suffix('.parts');directory.mkdir();vm.capture_path=directory/'prefix'
 offset=11 if scenario['control'] else 0;chain=copy.deepcopy(bound_specs()[offset:offset+11]);proof=[]
 for number,spec in enumerate(chain[:10]):
  assert shutil.disk_usage(directory).free>6*1024**3,'researchStorageLimit: preserve6GiB'
  oldpath=BASE/'war-preparation-bound-capture1.parts'/f'{offset+number:04d}.json';oldraw=oldpath.read_bytes();old=json.loads(oldraw)
  case=vm.next_step(spec) if number else vm.probe(spec)
  assert canonical(case)==canonical(old['case']),(number,'whole accepted prefix')
  assert canonical(vm.constructor_parent)==canonical(old['parents'][0]['constructors']),(number,'whole401 constructors')
  proof.append(dict(index=number,path=str(oldpath.resolve()),bytes=len(oldraw),sha256=sha(oldraw),caseSHA256=sha(canonical(case)),constructorSHA256=sha(canonical(vm.constructor_parent))))
  save(directory/f'prefix-{number:02d}.json',proof[-1]);print('prefix',a.scenario,number,'exact',flush=True)
 start=chain[-1];start.update(label='war-errors-'+scenario['label'],generation=0,resourceFailure=scenario)
 steps=[start]
 if scenario.get('release'):
  steps.append(dict(label=start['label']+'-release',control=False,chain=True,buttons=[[0,0xd1,1]],localTime=start['localTime'],generation=1,
   matrixInputs=dict(words={0x44d020:202,0x451b84:0,0x44d024:99,0x44d028:0})))
 new=[]
 for number,spec in enumerate(steps):
  vm.capture_path=directory/f'call-{number:02d}';vm.invalid_accesses=[]
  try:case=vm.next_step(spec)
  except UcError as error:
   if not vm.invalid_accesses:raise
   failurepath=vm.capture_path.with_suffix('.failure.json');failure=json.loads(failurepath.read_text())
   case=vm.complete_case(dict(spec=spec,before=failure['before'],after=vm.snapshot(),events=vm.events,writes=vm.writes,reads=vm.reads,apiReads=vm.api_reads,
    helpers=vm.helpers,pending=vm.pending,instructions=vm.pcs,points=vm.points,bodyMusic=vm.body_music_events,musicAfter=vm.music_records(),
    end='sourceFault',endPC=vm.uc.reg_read(UC_X86_REG_EIP),endSP=vm.uc.reg_read(UC_X86_REG_ESP),cw=vm.uc.reg_read(UC_X86_REG_FPCW),
    sourceFault=dict(error=repr(error),errorText=str(error),invalidAccesses=vm.invalid_accesses,registers=vm.registers(),fpu=vm.fpu(),failureFile=str(failurepath)),actorAddresses=vm.actors))
  assert case['end'] in ('returned','sourceFault')
  doc=dict(scope=__doc__,scenario=scenario,case=case,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,
   constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs,roster=inputs,arenas=arenas,
   exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,prefixProof=proof)
  pin=save(directory/f'call-{number:02d}.json',doc);pin.update(end=case['end'],endPC=case['endPC'],endSP=case['endSP']);new.append(pin)
  print('newCall',a.scenario,number,case['end'],hex(case['endPC']),pin['bytes'],flush=True)
  if case['end']=='sourceFault':break
 report=dict(scope=__doc__,timeUTC=NOW(),scenarioIndex=a.scenario,scenario=scenario,prefixCalls=len(proof),prefixProof=proof,
  calls=new,originalExecuted=True,nativeCompared=False,windowsVerified=False,fullPreparationComplete=False,fullGameComplete=False)
 save(a.output,report);print(dict(scenario=a.scenario,calls=len(new),ends=[x['end'] for x in new]),flush=True)

if __name__=='__main__':main()
