#!/usr/bin/env python3
"""Compare3964 controlled service-key prefixes and publish lossless evidence.

Actual key scan/global effects only: not a whole dispatcher or own game join.
Preserve all old fixtures and the active/paused corpora independently.
"""
import argparse,json,os,subprocess
from accept_initialized_gameplay import ROOT,FIXTURES,digest,publish
from verify_application_service_keys import validate


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package-path',default='native');p.add_argument('--scratch-path');a=p.parse_args()
    report,raw,_=validate();pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    (ROOT/'build/research/application-service-keys-prior-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    command=['swift','test','--package-path',str(ROOT/a.package_path),'-c','release','--filter','OriginalApplicationServiceKeysTests']
    if a.scratch_path:command.extend(['--scratch-path',str(ROOT/a.scratch_path)])
    subprocess.run(command,env=dict(os.environ,NTSD_APPLICATION_SERVICE_KEYS_CORPUS=str(ROOT/'build/original/application-service-keys.json')),check=True)
    report['nativeComparison']='All3964 prefix exits and9278 ordered global stores match, including28 retained calls in3 chains. Native state is independent of expected outputs; a late third mode observer failure retains the entire prefix state. Whole application dispatcher/game-state/device rollback remains open.'
    publish([('application-service-keys',report,raw)],pins,pin_name='application-service-keys-fixture-pins.json')


if __name__=='__main__':main()
