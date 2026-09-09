#!/usr/bin/env python3
"""Compare dispatcher prerequisites natively before publishing lossless evidence.

The service-key prefix, whole clear helper and explicit static initializer are
separate from the whole dispatcher and initialized application. Preserve all
old fixtures; source EXE and callback boundaries remain research-only.
"""
import argparse
import base64
import json
import os
import subprocess
import zlib
from import_ntsd import ROOT
from verify_application_dispatch_prefix import validate,digest


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--skip-build',action='store_true')
    p.add_argument('--package-path',default='native');p.add_argument('--scratch-path',default='build/application-dispatch-swift');a=p.parse_args()
    name='application-dispatch-prefix';raw=(ROOT/'build/original'/(name+'.json')).read_bytes();doc=json.loads(raw);verified=validate(doc)
    report=json.loads((ROOT/'build/research'/(name+'.json')).read_bytes());assert report['sha256']==digest(raw) and report['bytes']==len(raw)
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
    prior=ROOT/'build/research/application-dispatch-prefix-prior-pins.json'
    if prior.exists():assert all(pins[k]==v for k,v in json.loads(prior.read_bytes()).items())
    else:prior.write_text(json.dumps(pins,indent=2)+'\n')
    command=['swift','test','--package-path',str(ROOT/a.package_path),'-c','release','--scratch-path',str(ROOT/a.scratch_path),
        '-Xswiftc','-enable-testing','--filter','OriginalApplicationDispatchPrefixTests']
    if a.skip_build:command.append('--skip-build')
    subprocess.run(command,env=dict(os.environ,NTSD_APPLICATION_DISPATCH_PREFIX_CORPUS=str(ROOT/'build/original'/(name+'.json'))),check=True)
    assert all(digest((fixtures/k).read_bytes())==v for k,v in pins.items())
    payload=raw[:-1];compressor=zlib.compressobj(9,wbits=-15);compressed=compressor.compress(payload)+compressor.flush()
    packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
    assert zlib.decompress(compressed,-15)==payload
    fixture=fixtures/('original-'+name+'.json')
    if fixture.name in pins:assert digest(packed)==pins[fixture.name]
    else:
        tmp=fixture.with_suffix('.json.tmp');tmp.write_bytes(packed);os.replace(tmp,fixture)
    report.update(verified,nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),
        nativeComparison='Full service-prefix globals/state, complete clear effects/masks and HRESULTs, and existing World constructor over recovered PE zero-fill. No full dispatcher or initialized app claim.')
    static_raw=(ROOT/'build/research/application-dispatch-static.json').read_bytes()
    (ROOT/'docs/evidence/application-dispatch-static.json').write_bytes(static_raw)
    report.update(staticAudit='application-dispatch-static.json',staticAuditSHA256=digest(static_raw))
    (ROOT/'docs/evidence'/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    current={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')};(ROOT/'build/research/application-dispatch-prefix-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n')
    print('Published',fixture.name,len(packed),'bytes; preserved',len(pins),'prior fixtures')


if __name__=='__main__':main()
