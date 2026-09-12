#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47", "capstone==5.0.7"]
# ///
"""War resource-error callers with separate synthetic FS and unmapped NULL.
Pinned NTSD EXE/lib/VC80, original resources, Unicorn2.1.4/CW023f/C locale.
GDT/FS setup puts the declared four-byte exception head at7d010000; linear page0
stays unmapped. Full source instructions, records/masks/events/helpers and API
errors execute; invalid accesses only record and terminate. Compare ten whole
accepted parent calls with explicit FS-address-only relocation, never an
after-state import. Each29-case scenario has a fresh process; returned bitmap
errors may enter one declared next-Start99, never a continuation after fault.
LIB_WAR_PREPARATION_ERRORS_PLAN.md, LIB_WAR_PREPARATION_ERRORS_FS.md and the
explicit flat32-bit segment correction in LIB_WAR_PREPARATION_ERRORS_FS_STACK.md define
the boundaries. No original/host protection bypass, damaged control structure,
Windows/device/Native equivalence or full-game claim. Preserve old zero-page
captures separately; do not rerun their faulted operation in that environment.
"""
import argparse,copy,datetime,json,shutil,struct
from pathlib import Path
from unicorn import UC_HOOK_MEM_WRITE,UcError
from unicorn.x86_const import *
from oracle_war_preparation_errors import ErrorPreparation,scenarios,canonical,sha,save,BASE,NOW
from oracle_war_preparation_errors import bound_specs,tournament_inputs,arena_inputs,catalog_input,EXE_SHA256,DLL_SHA256,SP
from oracle_lib_war_preparation import REGISTERS
from probe_war_fs_stack import install_fs,FS_HEAD

class FSPreparation(ErrorPreparation):
 def __init__(self,*args):
  self.fs_ready=False;self.failed_write_hooks=[]
  super().__init__(*args)
  order=list(self.regions);head=bytes(self.uc.mem_read(0,4));mask=bytes(self.regions[0]['mask'])
  assert head==struct.pack('<I',0x12345678) and mask==b'\1'*4 and self.regions[0]['size']==4
  self.fs_environment=install_fs(self.uc);self.uc.mem_unmap(0,0x1000);del self.regions[0]
  self.add_region(FS_HEAD,head,True);self.regions={FS_HEAD if p==0 else p:self.regions[FS_HEAD if p==0 else p] for p in order}
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=FS_HEAD,end=FS_HEAD+3);self.fs_ready=True
  self.assert_fs()
 def assert_fs(self):
  assert self.uc.reg_read(UC_X86_REG_FS_BASE)==FS_HEAD and self.uc.reg_read(UC_X86_REG_FS)==0x18
  assert all(a>0 for a,_,_ in self.uc.mem_regions())
 def written(self,u,access,p,n,value,data):
  if self.fs_ready and p<0x1000:
   # Unicorn's write hook can precede an invalid-memory hook. Preserve the
   # attempt separately; it cannot define bytes in an unmapped owned region.
   self.failed_write_hooks.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,size=n,value=value,storeCount=len(self.writes),eventCount=len(self.events)))
   return
  return super().written(u,access,p,n,value,data)
 def code(self,u,pc,n,data):
  if self.fs_ready and self.running and not self.constructing and pc==0x30000000:
   self.assert_fs();assert not self.pending and self.clip is None and u.reg_read(UC_X86_REG_ESP)==SP+8 and self.u32(FS_HEAD)==0x12345678
   assert self.saved==[u.reg_read(r) for r in REGISTERS]
   self.end='returned';self.point('returned');u.emu_stop();return
  return super().code(u,pc,n,data)

def normalized_fs(case):
 result=copy.deepcopy(case);count=0;head_records=0
 def visit(value):
  nonlocal count,head_records
  if isinstance(value,dict):
   if value.get('address')==FS_HEAD:
    if 'storage' in value:head_records+=1
    else:
     pc=value.get('pc');assert pc is not None and case['instructions'][hex(pc)].startswith('64'),('non-FS relocation',value)
     assert len(bytes.fromhex(value['bytes']))<=4
     count+=1
    value['address']=0
   for v in value.values():visit(v)
  elif isinstance(value,list):
   for v in value:visit(v)
 visit(result);assert head_records>=2 and count>0
 return result,dict(fsRecordsRelocated=head_records,fsInstructionAccessesRelocated=count)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--scenario',type=int,required=True);a=p.parse_args();assert not a.output.exists()
 manifest=scenarios();assert a.scenario in range(len(manifest));scenario=manifest[a.scenario]
 inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input();vm=FSPreparation(scenario['control'],inputs,arenas,catalog)
 directory=a.output.with_suffix('.parts');directory.mkdir();vm.capture_path=directory/'prefix'
 offset=11 if scenario['control'] else 0;chain=copy.deepcopy(bound_specs()[offset:offset+11]);proof=[]
 for number,spec in enumerate(chain[:10]):
  assert shutil.disk_usage(directory).free>6*1024**3,'researchStorageLimit: preserve6GiB'
  oldpath=BASE/'war-preparation-bound-capture1.parts'/f'{offset+number:04d}.json';oldraw=oldpath.read_bytes();old=json.loads(oldraw)
  case=vm.next_step(spec) if number else vm.probe(spec);vm.assert_fs()
  comparable,relocation=normalized_fs(case)
  assert canonical(comparable)==canonical(old['case']),(number,'whole parent with declared FS relocation')
  assert canonical(vm.constructor_parent)==canonical(old['parents'][0]['constructors']),(number,'whole401 constructors')
  proof.append(dict(index=number,path=str(oldpath.resolve()),bytes=len(oldraw),sha256=sha(oldraw),caseSHA256=sha(canonical(case)),normalizedSHA256=sha(canonical(comparable)),relocation=relocation,constructorSHA256=sha(canonical(vm.constructor_parent))))
  save(directory/f'prefix-{number:02d}.json',proof[-1]);print('prefix',a.scenario,number,'FS-only relocated',flush=True)
 start=chain[-1];start.update(label='war-errors-'+scenario['label'],generation=0,resourceFailure=scenario)
 steps=[start]
 if scenario.get('release'):
  steps.append(dict(label=start['label']+'-release',control=False,chain=True,buttons=[[0,0xd1,1]],localTime=start['localTime'],generation=1,
   matrixInputs=dict(words={0x44d020:202,0x451b84:0,0x44d024:99,0x44d028:0})))
 new=[]
 for number,spec in enumerate(steps):
  vm.capture_path=directory/f'call-{number:02d}';vm.invalid_accesses=[];vm.failed_write_hooks=[]
  try:case=vm.next_step(spec)
  except UcError as error:
   if not vm.invalid_accesses:raise
   failurepath=vm.capture_path.with_suffix('.failure.json');failure=json.loads(failurepath.read_text())
   case=vm.complete_case(dict(spec=spec,before=failure['before'],after=vm.snapshot(),events=vm.events,writes=vm.writes,reads=vm.reads,apiReads=vm.api_reads,
    helpers=vm.helpers,pending=vm.pending,instructions=vm.pcs,points=vm.points,bodyMusic=vm.body_music_events,musicAfter=vm.music_records(),
    end='sourceFault',endPC=vm.uc.reg_read(UC_X86_REG_EIP),endSP=vm.uc.reg_read(UC_X86_REG_ESP),cw=vm.uc.reg_read(UC_X86_REG_FPCW),
    sourceFault=dict(error=repr(error),errorText=str(error),invalidAccesses=vm.invalid_accesses,failedWriteHooks=vm.failed_write_hooks,registers=vm.registers(),fpu=vm.fpu(),failureFile=str(failurepath)),actorAddresses=vm.actors))
  vm.assert_fs();assert case['end'] in ('returned','sourceFault')
  doc=dict(scope=__doc__,scenario=scenario,case=case,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,
   constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs,roster=inputs,arenas=arenas,
   exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,prefixProof=proof,fsEnvironment=vm.fs_environment,memoryMappings=list(vm.uc.mem_regions()))
  pin=save(directory/f'call-{number:02d}.json',doc);pin.update(end=case['end'],endPC=case['endPC'],endSP=case['endSP']);new.append(pin)
  print('newCall',a.scenario,number,case['end'],hex(case['endPC']),pin['bytes'],flush=True)
  if case['end']=='sourceFault':break
 report=dict(scope=__doc__,timeUTC=NOW(),scenarioIndex=a.scenario,scenario=scenario,prefixCalls=len(proof),prefixProof=proof,
  calls=new,fsEnvironment=vm.fs_environment,originalExecuted=True,nativeCompared=False,windowsVerified=False,fullPreparationComplete=False,fullGameComplete=False)
 save(a.output,report);print(dict(scenario=a.scenario,calls=len(new),ends=[x['end'] for x in new]),flush=True)

if __name__=='__main__':main()
