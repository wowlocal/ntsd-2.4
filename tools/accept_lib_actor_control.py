#!/usr/bin/env python3
"""Accept whole installed NTSD library Actor control and publish exact evidence.

The7168 controlled source returns, full storage/masks/globals and ordered
events must match Native before lossless publication. The pristine25795-call
control and both late rollback trials are retained. A verified completed raw
run may be reused only with its terminal work record, exact log hash and every
isolated source pin. This does not establish full application or Windows behavior.
"""
import argparse
import json
import os
import subprocess
from pathlib import Path
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish
from verify_lib_actor_control import validate

FILTER = 'OriginalLibActorControlTests|OriginalActorControlTests/(testWholeOriginalControlOnRawActorAndGlobals|testFailedAttackAfterRandomDrawRollsBackActorAndGlobals)'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package-path',default='native')
    parser.add_argument('--scratch-path')
    parser.add_argument('--reuse-verified-run',action='store_true')
    args = parser.parse_args()
    verified = validate()
    report,raw,doc = capture('lib-actor-control')
    assert report['cases'] == verified['cases'] == len(doc['cases']) == 7168
    if args.reuse_verified_run:
        work = json.loads((ROOT/'build/research/lib-actor-control-work.json').read_bytes())
        assert work['nativeRawExitCode'] == 0 and work['nativeRawProcessTerminal'] and work['nativeRawTests'] == 4
        log = (ROOT/work['nativeRawLog']).read_bytes()
        assert digest(log) == work['nativeRawLogSHA256']
        assert b'Executed 4 tests, with 0 failures' in log and b'7168 whole calls; 800 ordered events' in log
        pins = json.loads((ROOT/work['packagePins']).read_bytes())
        package_root = Path(work['isolatedPackage']).parent
        for name,sha in pins['files'].items():assert digest((package_root/name).read_bytes()) == sha,name
        for name in pins['ownedFiles']:assert digest((ROOT/name).read_bytes()) == pins['files'][name],name
    else:
        command = ['swift','test','--package-path',str(ROOT/args.package_path),'-c','release','--filter',FILTER]
        if args.scratch_path:command.extend(['--scratch-path',str(ROOT/args.scratch_path)])
        subprocess.run(command,env=dict(os.environ,NTSD_LIB_ACTOR_CONTROL_CORPUS=str(ROOT/'build/original/lib-actor-control.json')),check=True)
    prior = {p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old = json.loads((ROOT/'build/research/lib-runtime-fixture-pins.json').read_bytes())
    assert len(old) == 200 and all(prior[name] == sha for name,sha in old.items())
    (ROOT/'build/research/lib-actor-control-prior-pins.json').write_text(json.dumps(prior,indent=2)+'\n')
    report.update(sourceVerification=verified,priorFixturePinsUnchanged=len(prior),bundledLibInstalled=True,
        nativeComparison='Public OriginalLibActorControl matches7168 complete controlled source returns on full Actor bytes/masks, full globals hashes and800 ordered RNG/sound events; source input frames are independently constructed natively. Missing selected frame42 rolls back staged facing/frame changes and all owned state. Pristine25795 calls and prior RNG rollback also pass. Native does not execute or load DLL code.',
        sourceFPUStatusComparedToNative=False,wholeApplicationCompared=False)
    publish([('lib-actor-control',report,raw)],prior,pin_name='lib-actor-control-fixture-pins.json')


if __name__ == '__main__':main()
