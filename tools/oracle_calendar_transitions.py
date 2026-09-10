#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Close precise DST-boundary gaps in the original startup calendar corpus.
Pinned VC80/Unicorn2.1.4 and unchanged CalendarTime controlled OS/environment
adapters. Each original June baseline computes its own transition cache; derive
public timestamp inputs at the nearest seconds, then execute fresh full calls.
No expected output is injected into native, no source fixture is rewritten, no
Windows/device claim or control corruption. CALENDAR_TIME_PLAN.md.
"""
import argparse,json,os,datetime
from pathlib import Path
from oracle_calendar_time import CalendarTime,specifications
from oracle_bitmap_drawing import digest
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);a=p.parse_args();path=Path(a.output);assert not path.exists();path.with_name(path.stem+'-source.py').write_bytes(Path(__file__).read_bytes())
 parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();cases=[];blobs={};pcs={};epoch=datetime.datetime(1970,1,1)
 names=['us','old-us','south','half-dst','absolute','milliseconds','standard-bias','api-failure','env-PST8PDT','env-ABC-5:30:45XYZ','env-EST5EDT']
 for i,s in enumerate(c for c in specifications() if c['label'] in names):
  spec=dict(s,steps=[]);r=CalendarTime(spec);steps=[];boundaries=[]
  for year in [1970,2000,2006,2007,2024,2026,2100,2400,3000]:
   value=int((datetime.datetime(year,6,1)-epoch).total_seconds());spec['steps'].append(['local',value]);baseline=r.run('local',value);assert baseline['end']=='returned' and baseline['eax'];steps.append(baseline)
   c=baseline['after']['cache'];bias=baseline['after']['timezone'][0];bias=bias-2**32 if bias>=2**31 else bias
   start=int((datetime.datetime(year,1,1)-epoch).total_seconds())
   for index in [0,1]:
    assert c[index*3]==year-1900;millis=c[index*3+1]*86400000+c[index*3+2]
    edge=start+(millis+999)//1000+bias
    inputs=[edge+delta for delta in [-2,-1,0,1,2]];outputs=[]
    for value in inputs:
     spec['steps'].append(['local',value]);step=r.run('local',value);assert step['end']=='returned' and step['eax'];steps.append(step);outputs.append(r.u32(step['eax']+32))
    assert outputs==([0,0,1,1,1] if index==0 else [1,1,0,0,0]),(spec['label'],year,index,outputs)
    boundaries.append(dict(year=year,index=index,standardMilliseconds=millis,standardOffset=bias,inputSeconds=inputs,isDST=outputs))
  case=dict(spec=spec,steps=steps,boundaries=boundaries);cases.append(case);blobs.update(r.blobs);pcs.update(r.pcs)
  temp=parts/f'{i+1:04d}.tmp';temp.write_text(json.dumps(dict(case=case,blobs=r.blobs),separators=(',',':'))+'\n');os.replace(temp,temp.with_suffix('.json'));print(i+1,spec['label'],len(steps),len(boundaries),flush=True)
 d=dict(scope=__doc__,variant='transitions',producerSHA256=digest(Path(__file__).read_bytes()),dependencies={f:digest((ROOT/'tools'/f).read_bytes()) for f in ['oracle_calendar_time.py','oracle_crt.py','oracle_bitmap_drawing.py','inspect_original.py','import_ntsd.py']},exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,dataAddress=r.db,dataCount=r.ds,cases=cases,blobs=blobs,instructions=pcs)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path);print('complete',len(cases),sum(len(c['steps']) for c in cases),len(raw),digest(raw),flush=True)
if __name__=='__main__':main()
