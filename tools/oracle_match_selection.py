#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own ready Naruto/Sasuke -> countdown -> zero CPUs -> District -> Start.
Fresh complete CHARACTER_SCREEN and its parents execute before the continuation
on the same CPU, stack, World, loaded catalog, resources and RNG. Only acquired
keyboard bytes and the inherited platform/caller boundary are supplied. Stop
BEFORE42cf8a match prelude; native comparison and Windows output remain open.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256,PTD
from oracle_character_screen import CharacterScreen
from oracle_menu_startup import capture as capture_startup
from oracle_front_menu_resources import WORLD,REGISTERS
from oracle_initial_loading import transport
from oracle_bitmap_drawing import digest
from oracle_catalog_sounds import pack
from oracle_state import STOP
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_ESP

class MatchSelection(CharacterScreen):
 def start_prefix(self,pc,sp):
  super().start_prefix(pc,sp)
  self.early.prefix_fill_arguments=None
  if getattr(self,'selection_enabled',False) and pc==0x415160:
   ret=self.u32(sp);x=self.uc.reg_read(UC_X86_REG_ESI)
   if ret in (0x42B8F4,0x42B908,0x42B91C,0x42B933):
    assert 280<=x<=490 and (x-280)%30==0
    rect={0x42B8F4:[x,283,21,1],0x42B908:[x,283,1,21],0x42B91C:[x,303,21,1],0x42B933:[x+20,283,1,21]}[ret]
    self.early.prefix_fill_arguments=rect+[0xFFFFFF]
 def character_code(self,uc,pc,size,data):
  if self.character_running and getattr(self,'selection_enabled',False):
   if pc in (0x42B296,0x42B964,0x42CB86,0x42CF6C,0x42CF8A,0x42D706,0x42D789,0x42E0B6):
    self.character_checkpoints.append(self.character_checkpoint(pc))
   if pc in self.character_stops:assert self.selection_format is None and self.selection_random is None
  super().character_code(uc,pc,size,data)
 def character_extra_code(self,uc,pc,size,data):
  if not getattr(self,'selection_enabled',False):return False
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  if self.selection_random and pc==self.selection_random['returnPC']:
   r=self.selection_random;self.selection_random=None
   assert sp==r['sp']+4
   self.emit('random',[r['stream'],r['range'],uc.reg_read(UC_X86_REG_EAX),r['index'],r['counter'],self.u32(0x450BCC),self.u32(0x450C34)])
  if self.selection_format and pc==self.selection_format['returnPC']:
   f=self.selection_format;self.selection_format=None;assert sp==f['sp']+4
   raw=self.cstr(f['destination']);assert len(raw)==uc.reg_read(UC_X86_REG_EAX)
   self.emit('format',[len(raw)],[f['format'],raw])
  if pc in (0x402130,0x417170):
   self.character_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=0,saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc==0x402130:
   self.emit('musicConfiguration',[arg(i) for i in range(4)])
  if pc==0x417170:
   assert self.selection_random is None
   stream,limit=arg(0),arg(1)
   assert (stream==0xD7 and self.u32(sp)==0x42B704) or (stream==1 and self.u32(sp)==0x40232D)
   if stream==0xD7:
    assert 0<limit<=len(self.object_addresses)
    self.emit('candidates',[uc.reg_read(UC_X86_REG_EBP)//4,*struct.unpack('<'+'I'*limit,uc.mem_read(sp+0x50,limit*4))])
   self.selection_random=dict(sp=sp,returnPC=self.u32(sp),stream=stream,range=limit,index=self.u32(0x450BCC),counter=self.u32(0x450C34))
  if pc==0x7817775D:
   fmt=self.cstr(arg(1));assert fmt in (b'%d',b'Music: %s')
   assert self.selection_format is None
   self.selection_format=dict(sp=sp,returnPC=self.u32(sp),destination=arg(0),format=fmt)
  if pc==0x78132DB2:self.ret(PTD);return True
  return any(a<=pc<=b for a,b in [(0x42B296,0x42CF89),(0x42D706,0x42E0D2),(0x402130,0x4025A5),
   (0x417170,0x4171BC),(0x78130000,0x7822FFFF),(STOP+0x6000,STOP+0x7FFF)])
 def capture_character(self,parent):
  old=super().capture_character(parent)
  suffix='-control' if self.control else ''
  report=json.loads((ROOT/'docs/evidence'/f'character-screen{suffix}.json').read_bytes())
  raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
  assert json.loads(raw)==json.loads(json.dumps(old))
  print('Entire pinned CHARACTER_SCREEN reproduced; continuing own match selection',flush=True)
  self.selection_enabled=True;self.selection_format=None;self.selection_random=None
  self.character_stops={0x42E0D2:'returned',0x42CF8A:'matchPrelude',0x438B40:'warStage'}
  cases=[]
  def document():return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
   parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),worldAddress=WORLD,
   actorAddresses=[a['address'] for a in self.pool],objectAddresses=self.object_addresses,cases=cases),{**self.early.blobs,**self.blobs})
  def frame(label,changes=(),start=False):
   before=self.control_snapshot();writes=self.acquire(changes)
   cycle=self.cycle_step(label+' cycle',selection=True)
   screen=self.character_step(label)
   assert screen['continuation']==('matchPrelude' if start else 'returned')
   returned=None
   if not start:
    self.bind_output();returned=self.return_step(label+' return',inherited=True,entry_pc=0x42E0D2)
   cases.append(dict(label=label,before=before,acquired=writes,cycle=cycle,screen=screen,returned=returned))
   (ROOT/'build/research'/f'match-selection-partial{suffix}.json').write_text(json.dumps(document(),separators=(',',':'))+'\n')
   print('SELECTION',label,'stage',self.u32(0x4512C8),'timer',self.u32(0x44D078),'CPU',self.u32(0x44D070),
    'option',self.u32(0x44D06C),'arena',self.u32(0x44D024),'RNG',self.u32(0x450BCC),self.u32(0x450C34),flush=True)
  def edge(label,button):
   for name,pressed,stimulus in [('press-acquired',True,True),('press-applied',True,False),('release-acquired',False,True),('release-applied',False,False)]:
    frame(label+' '+name,[(0,button,pressed)] if stimulus else ())
  assert self.u32(0x44D078)==147 and self.u32(0x4512C8)==0
  for i in range(5):edge(f'accelerate-countdown-{i}',5)
  assert self.u32(0x4512C8)==1 and self.u32(0x44D070)==0
  edge('confirm-zero-computers',4)
  assert self.u32(0x4512C8)==3 and self.u32(0x44D06C)==2
  edge('select-arena-option',1)
  assert self.u32(0x44D06C)==3
  edge('arena-random-to-none',4);assert self.u32(0x44D024)==99
  edge('arena-none-to-District',4);assert self.u32(0x44D024)==0
  for i in range(3):edge(f'select-start-option-{i}',0)
  assert self.u32(0x44D06C)==0
  frame('start-press-acquired',[(0,4,True)])
  frame('start-press-applied',start=True)
  assert [self.u32(0x451248+4*i) for i in range(2)]==[17,21]
  assert [self.u32(0x451288+4*i) for i in range(2)]==[3,3]
  assert self.u32(0x44D024)==0 and self.u32(0x44D028)==0
  return document()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
  fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pending=[]
  for suffix in ('','-control'):
   report=json.loads((ROOT/'build/research'/f'match-selection{suffix}.json').read_bytes())
   raw=(ROOT/'build/original'/report['corpus']).read_bytes()
   assert digest(raw)==report['sha256'] and len(raw)==report['bytes'];doc=json.loads(raw)
   assert len(doc['cases'])==50 and sum(c['returned'] is not None for c in doc['cases'])==49
   assert all(c['cycle'] is not None and not c['cycle']['stimulus'] for c in doc['cases'])
   assert doc['cases'][-1]['screen']['continuation']=='matchPrelude'
   refs=[];previous=doc
   for name in ('character-screen','menu-cycle','menu-return','mode-screen','menu-startup'):
    r=json.loads((ROOT/'docs/evidence'/f'{name}{suffix}.json').read_bytes());ref=dict(fixture=r['fixture'],sha256=r['fixtureSHA256'])
    assert previous['parent']==ref;refs.append(ref);previous=r
   refs.extend(r['parents'][key] for key in ('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds'))
   parents=[]
   for ref in refs:
    path=fixtures/ref['fixture'];assert digest(path.read_bytes())==ref['sha256'];parents.append(str(path))
   packed=pack(doc).encode();temporary=ROOT/'build/original'/f'match-selection{suffix}-check.json';temporary.write_bytes(packed)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--match-selection',str(temporary),*parents],capture_output=True,text=True)
   print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=fixtures/('original-'+report['corpus'])
   report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),parent=doc['parent'],
    returns=49,screenEvents=sum(len(c['screen']['events']) for c in doc['cases']),screenHelpers=sum(len(c['screen']['helpers']) for c in doc['cases']),
    screenCheckpoints=sum(len(c['screen']['checkpoints']) for c in doc['cases']),
    randomCalls=sum(e['kind']=='random' for c in doc['cases'] for e in c['screen']['events']),
    formats=sum(e['kind']=='format' for c in doc['cases'] for e in c['screen']['events']))
   pending.append((ROOT/'docs/evidence'/f'match-selection{suffix}.json',report,fixture,packed))
  for path,report,fixture,packed in pending:fixture.write_bytes(packed);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=capture_startup(a.control,vm_type=MatchSelection,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode()
 path=ROOT/'build/original'/f'match-selection{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(doc['cases']),nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
