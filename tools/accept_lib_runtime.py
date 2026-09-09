#!/usr/bin/env python3
"""Publish bundled-library installation evidence and compared native text.

The actual DLL installer is source-only evidence. Only its installed text
replacement is compared natively here. Other hooks and initialized application
remain open; immutable pristine-EXE fixtures are retained as separate controls.
"""
import argparse,base64,json,os,subprocess,zlib
from import_ntsd import ROOT
from verify_lib_runtime import digest,initial_images,validate_installation,validate_text,validate_static

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package-path',default='native');p.add_argument('--scratch-path',default='build/lib-runtime-swift');p.add_argument('--skip-build',action='store_true');a=p.parse_args()
    raw={name:(ROOT/'build/original'/(name+'.json')).read_bytes() for name in ('lib-initialization','lib-surface-text')};docs={k:json.loads(v) for k,v in raw.items()};templates=initial_images()
    installation=validate_installation(docs['lib-initialization'],templates);text=validate_text(docs['lib-surface-text'],templates,docs['lib-initialization'])
    static=validate_static(raw['lib-initialization'],docs['lib-initialization'])
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')};prior=ROOT/'build/research/lib-runtime-prior-pins.json'
    if prior.exists():assert all(pins[k]==v for k,v in json.loads(prior.read_bytes()).items())
    else:prior.write_text(json.dumps(pins,indent=2)+'\n')
    command=['swift','test','--package-path',str(ROOT/a.package_path),'-c','release','--scratch-path',str(ROOT/a.scratch_path),'-Xswiftc','-enable-testing','--filter','OriginalLibSurfaceTextTests']
    if a.skip_build:command.append('--skip-build')
    subprocess.run(command,env=dict(os.environ,NTSD_LIB_SURFACE_TEXT_CORPUS=str(ROOT/'build/original/lib-surface-text.json')),check=True)
    assert all(digest((fixtures/k).read_bytes())==v for k,v in pins.items())
    for name,value in raw.items():
        payload=value[:-1];c=zlib.compressobj(9,wbits=-15);compressed=c.compress(payload)+c.flush();packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
        assert zlib.decompress(compressed,-15)==payload;fixture=fixtures/('original-'+name+'.json')
        if fixture.name in pins:assert digest(packed)==pins[fixture.name]
        else:tmp=fixture.with_suffix('.json.tmp');tmp.write_bytes(packed);os.replace(tmp,fixture)
        report=json.loads((ROOT/'build/research'/(name+'.json')).read_bytes());assert report['sha256']==digest(value) and report['bytes']==len(value)
        report.update(installation if name=='lib-initialization' else text,fixture=fixture.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed),nativeCompared=name=='lib-surface-text',wholeLibraryNativeCompared=False,pristineFixturesRewritten=False)
        (ROOT/'docs/evidence'/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n');print('Published',name,len(packed),'bytes; nativeCompared',report['nativeCompared'])
    (ROOT/'docs/evidence/lib-runtime-static.json').write_bytes(static)
    (ROOT/'build/research/lib-runtime-fixture-pins.json').write_text(json.dumps({p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')},indent=2)+'\n')
    print('Preserved',len(pins),'prior fixtures')
if __name__=='__main__':main()
