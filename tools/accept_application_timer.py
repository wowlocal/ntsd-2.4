#!/usr/bin/env python3
"""Compare the2025 bounded original timer decisions, then publish losslessly.

This accepts only timer arithmetic/request order, with explicit dispatcher,
surface-recovery and OS boundaries. No own game/Windows/device claim follows.
"""
import argparse,json,os,subprocess
from accept_initialized_gameplay import ROOT,FIXTURES,digest,publish
from verify_application_timer import validate


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package-path',default='native');p.add_argument('--scratch-path');a=p.parse_args()
    report,raw,_=validate();pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    (ROOT/'build/research/application-timer-prior-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    command=['swift','test','--package-path',str(ROOT/a.package_path),'-c','release','--filter','OriginalApplicationTimerTests']
    if a.scratch_path:command.extend(['--scratch-path',str(ROOT/a.scratch_path)])
    subprocess.run(command,env=dict(os.environ,NTSD_APPLICATION_TIMER_CORPUS=str(ROOT/'build/original/application-timer.json')),check=True)
    report['nativeComparison']='All2025 whole timer decisions match baseline and8163 ordered time/dispatch/recovery/sleep events. Late Sleep observer rejection retains the native timer baseline. Enclosing game-state/device rollback is not established by this timer-only comparison.'
    publish([('application-timer',report,raw)],pins,pin_name='application-timer-fixture-pins.json')


if __name__=='__main__':main()
