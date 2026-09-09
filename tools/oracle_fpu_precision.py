#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Audit real445a31/_controlfp_s and4196f0 under distinct x87 precisions.
Actual EXE/DLL instructions, declared initial control words and synthetic pool.
This exposes the difference from the accepted CW037f native corpus; it is not
whole Windows/CRT/device initialization or native53-bit arithmetic acceptance.
"""
import base64,json,struct,zlib
from oracle_crt import CRT,DLL_SHA256
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from oracle_world_impulses import digest
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_ECX,UC_X86_REG_FPCW,UC_X86_REG_FPSW

def main():
 report=json.loads((ROOT/'docs/evidence/world-impulses.json').read_bytes())
 raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256'] and report['nativeCompared']
 fixture=(ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes();assert digest(fixture)==report['fixtureSHA256']
 envelope=json.loads(fixture);assert zlib.decompress(base64.b64decode(envelope['deflate']),-15)==raw[:-1]
 probes=[c for c in json.loads(raw)['cases'] if c['group']=='double-rounding'];assert len(probes)==16
 crt=CRT();exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(exe)==EXE_SHA256
 pe=PE(exe);crt.uc.mem_map(0x400000,0x100000);crt.uc.mem_write(0x400000,exe[:0x400])
 for s in pe.sections:
  if s['name']!='.rsrc':crt.uc.mem_write(0x400000+s['rva'],exe[s['fileOffset']:s['fileOffset']+s['fileSize']])
 assert next(i for i in pe.imports() if i['name']=='_controlfp_s')['iatVA']=='0x004470f0'
 # Original startup's _initterm_e table includes44547e; its call445546 reaches
 # this whole helper. Outer startup/thread/OS/other CRT initializers remain S.
 initializers=list(struct.unpack('<4I',crt.uc.mem_read(0x4472d8,16)));assert 0x44547e in initializers
 crt.uc.mem_write(0x4470f0,struct.pack('<I',0x7814a7e9))
 instructions=set();crt.uc.hook_add(UC_HOOK_CODE,lambda uc,pc,size,data:instructions.add(pc))
 controls=[]
 for cw in (0,0x37f,0x27f,0xb7f):
  crt.uc.reg_write(UC_X86_REG_FPCW,cw);crt.uc.reg_write(UC_X86_REG_FPSW,0)
  result=crt.call(0x445a31,[]);after=crt.uc.reg_read(UC_X86_REG_FPCW)
  assert result==0 and after&0x300==0x200
  controls.append(dict(before=cw,after=after,result=result))
 initialization_instructions=sorted(instructions);instructions.clear()
 world,actor=0x22000020,0x70000020
 for address in (world&~0xfff,actor&~0xfff):crt.uc.mem_map(address,0x1000)
 crt.uc.mem_write(world+4,b'\x01');crt.uc.mem_write(world+0x194,struct.pack('<I',actor))
 cases=[]
 for p in probes:
  patches=dict(p['actors'][0][1]);outputs=[]
  for name,cw in [('inherited-zero',0),('startup-helper',0x37f),('explicit-53',0x27f),('historical-64',0x37f)]:
   crt.uc.mem_write(actor,bytes(0x420))
   for offset in (0x20,0x28,0x30,0x38):crt.uc.mem_write(actor+offset,bytes.fromhex(patches[offset]))
   crt.uc.reg_write(UC_X86_REG_FPCW,cw);crt.uc.reg_write(UC_X86_REG_FPSW,0)
   if name=='startup-helper':crt.call(0x445a31,[])
   actual_cw=crt.uc.reg_read(UC_X86_REG_FPCW);crt.uc.reg_write(UC_X86_REG_ECX,world)
   crt.call(0x4196f0,[])
   assert crt.uc.reg_read(UC_X86_REG_FPCW)==actual_cw and (crt.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
   values=[bytes(crt.uc.mem_read(actor+offset,8)).hex() for offset in (0x40,0x48,0x50)]
   assert bytes(crt.uc.mem_read(actor+0x20,4))==bytes(4) and bytes(crt.uc.mem_read(actor+0x28,24))==bytes(24)
   outputs.append(dict(mode=name,fpcw=actual_cw,fpsw=crt.uc.reg_read(UC_X86_REG_FPSW),values=values))
  expected=[e['bytes'] for e in p['events'][:3]]
  assert outputs[-1]['values']==expected and outputs[1]['values']==outputs[2]['values']
  cases.append(dict(label=p['label'],inputs=[[o,patches[o]] for o in (0x20,0x28,0x30,0x38)],outputs=outputs))
 differences=sum(a!=b for c in cases for a,b in zip(c['outputs'][1]['values'],c['outputs'][3]['values']));assert differences==32
 doc=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,initializers=initializers,controls=controls,
  initializationInstructions=initialization_instructions,instructions=sorted(instructions),cases=cases,
  historicalNative=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),differing53And64Stores=differences,native53Compared=False,windowsVerified=False)
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original/fpu-precision.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),
  initializers=initializers,controls=controls,initializationInstructions=len(initialization_instructions),cases=len(cases),helperExecutions=len(cases)*4,
  differing53And64Stores=differences,historicalNative=doc['historicalNative'],native53Compared=False,windowsVerified=False,
  next='Recover startup/thread/device FPU provenance and native53-bit arithmetic before expanding the full tick. Retain historical declared CW037f fixtures.')
 (ROOT/'docs/evidence/fpu-precision.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
