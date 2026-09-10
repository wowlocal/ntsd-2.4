#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Two successful WinMM setup controls for the original input-to-sound caller.

Fresh controlled43d078..43d100 and own WndProc consumers, same pinned EXE/WAVs,
Unicorn2.1.4 and declared API boundaries as INPUT_STARTUP_PLAN. Complements the
unchanged58-case ignored-error corpus with zero threshold/capture/cooperative
results. Not actual Windows capture/message delivery, devices or full WinMain.
No source fault or memory/control corruption stimulus. Development tooling only.
"""
import argparse,json,os
from pathlib import Path
from oracle_input_startup import InputStartup,specifications
from import_ntsd import ROOT,EXE_SHA256
from oracle_wave_loader import digest

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
    parts=a.output.with_suffix('.parts');assert not parts.exists();parts.mkdir(parents=True)
    producer=Path(__file__).read_bytes();a.output.with_name(a.output.stem+'-source.py').write_bytes(producer);vm=InputStartup();cases=[]
    for s in specifications():
        if s['label'] not in ['positions-False-0-0','positions-True-0-0']:continue
        s['label']='successful-'+s['label'];s['joysticks']['count']=2;s['device']['cooperativeResult']=0
        for d in s['joysticks']['devices']:
            for kind in ['position','threshold','capture','capabilities']:d[kind]['result']=0
        c=vm.run_case(s);cases.append(c);part=parts/f'{len(cases):04d}.json';tmp=part.with_suffix('.tmp')
        tmp.write_text(json.dumps(dict(case=c,blobs=vm.blobs),separators=(',',':'))+'\n');os.replace(tmp,part)
        print(s['label'],len(c['callbacks']),'own callbacks',flush=True)
    assert len(cases)==2
    d=dict(exeSHA256=EXE_SHA256,producerSHA256=digest(producer),producerFile=Path(__file__).name,scope=__doc__,
        dependencies={n:digest((ROOT/'tools'/n).read_bytes()) for n in ['oracle_input_startup.py','oracle_menu_sound_startup.py','oracle_wave_loader.py','oracle_state.py','inspect_original.py','import_ntsd.py']},
        sources=[dict(path=p,sha256=digest(raw),count=len(raw)) for p,raw in vm.source_files.items()],cases=cases,blobs=vm.blobs,
        instructions={hex(a):b for a,b in sorted(vm.all_pcs.items())})
    raw=(json.dumps(d,separators=(',',':'))+'\n').encode();tmp=a.output.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,a.output)
    print('completed',len(raw),digest(raw),flush=True)
if __name__=='__main__':main()
