#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own adinfo reader -> actual cache writer -> fresh own reader composition.

Pinned EXE/VC80 in two controlled Unicorn instances. Between-call global ABI is
explicit: transfer the first execution's own state, never an expected fixture.
Writer _write accepted prefixes supply next reader bytes. APIs are controlled;
no actual game-file write, external network, WinMain or Windows execution claim.
Ordinary short/error writes test menu cache retention, without memory corruption.
"""
import argparse,json,os,struct
from pathlib import Path
from oracle_menu_info_reading import MenuInfoReading,specs,GLOBAL,SIZE
from oracle_menu_info_writing import MenuInfoWriting
from oracle_crt import DLL_SHA256
from oracle_bitmap_drawing import digest
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_HOOK_CODE


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);a=p.parse_args();path=Path(a.output);assert not path.exists();parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir(parents=True)
 source=Path(__file__).read_bytes();path.with_name(path.stem+'-source.py').write_bytes(source)
 reader=MenuInfoReading();writer=MenuInfoWriting();pcs={}
 def trace(u,pc,n,data):
  if writer.active and pc not in writer.boundaries and pc not in (0x30000040,0x7814e3f1,0x7814e83f,0x7814e74a,0x78132db2):pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex()
 writer.uc.hook_add(UC_HOOK_CODE,trace)
 selected=[s for s in specs() if s['label'].removesuffix('-a5').removesuffix('-ramp') in ['original','dont-update','date','number-1-x','number-2--1','number-1--2147483648','number-2-2147483647','retained--2147483648-2147483647']]
 cases=[]
 for i,s in enumerate(selected):
  first=reader.step(s);assert first['result']==1 and first['unknown'] is None
  own=bytes(reader.uc.mem_read(GLOBAL,SIZE));writer.uc.mem_write(GLOBAL,own)
  index,period=[struct.unpack('<i',reader.uc.mem_read(p,4))[0] for p in (0x44d784,0x44d788)];date=reader.cstr(0x4527b0)
  mode=['full','error','short'][i%3];pcs.clear()
  written=writer.step(s['label']+'-write',date=date,index=index,period=period,capacity=7,write_mode=mode,fail_at=1 if mode!='full' else -1)
  emitted=b''.join(bytes(e['strings'][0])[:e['result']] for e in written['events'] if e['kind']=='writeFile' and e['result']<0x80000000)
  before_second=bytes(writer.uc.mem_read(GLOBAL,SIZE));next_spec=dict(s,label=s['label']+'-read-own',input=list(emitted),chunk=7,readFailAt=-1,close=-1)
  second=reader.step(next_spec,own_globals=before_second)
  assert second['unknown'] is None
  c=dict(label=s['label'],first=first,writer=written,writerInstructions=pcs.copy(),emitted=list(emitted),second=second);cases.append(c)
  blobs={**reader.blobs,**writer.blobs};part=parts/f'{i+1:04d}.json';temp=part.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,blobs=blobs),separators=(',',':'))+'\n');os.replace(temp,part)
  print(i+1,s['label'],mode,len(emitted),second['result'],flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,producerSHA256=digest(source),dependencies={n:digest((ROOT/'tools'/n).read_bytes()) for n in ['oracle_menu_info_reading.py','oracle_menu_info_writing.py','oracle_crt.py','oracle_bitmap_drawing.py','inspect_original.py','import_ntsd.py']},cases=cases,blobs={**reader.blobs,**writer.blobs},readerInstructions=reader.all_pcs)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path);print('complete',len(cases),len(raw),digest(raw),flush=True)
if __name__=='__main__':main()
