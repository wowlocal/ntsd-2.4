#!/usr/bin/env python3
"""Publish only after whole native commands and preparation joins pass.

All previous fixtures remain byte-for-byte unchanged. The new three lossless
fixtures retain full source storage, masks, inputs, events, undefined-read
observations and actual installer metadata. This is not a library-enabled
initialized application or Windows runtime comparison.
"""
import argparse,base64,json,os,subprocess,zlib
from import_ntsd import ROOT
from verify_lib_stage_commands import NAMES,digest,verify

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package-path',default='native');p.add_argument('--scratch-path',default='build/lib-stage-commands-swift');p.add_argument('--skip-build',action='store_true');a=p.parse_args()
    checked=verify();fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
    command=['swift','test','--package-path',str(ROOT/a.package_path),'--scratch-path',str(ROOT/a.scratch_path),'-c','release','-Xswiftc','-enable-testing','--filter','OriginalLibStageCommandsTests|OriginalLibMatchPreparationTests|OriginalPostDrawCommandsTests|OriginalMatchPreparationTests']
    if a.skip_build:command.append('--skip-build')
    subprocess.run(command,env=dict(os.environ,NTSD_LIB_STAGE_COMMANDS_DIRECTORY=str(ROOT/'build/original'),NTSD_LIB_MATCH_PREPARATION_DIRECTORY=str(ROOT/'build/original')),check=True)
    assert all(digest((fixtures/name).read_bytes())==sha for name,sha in pins.items())
    for name in NAMES:
        raw=(ROOT/'build/original'/(name+'.json')).read_bytes();payload=raw[:-1];compressor=zlib.compressobj(9,wbits=-15);compressed=compressor.compress(payload)+compressor.flush();packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
        assert zlib.decompress(base64.b64decode(json.loads(packed)['deflate']),-15)+b'\n'==raw
        path=fixtures/('original-'+name+'.json')
        if path.name in pins:assert pins[path.name]==digest(packed)
        else:temp=path.with_suffix('.json.tmp');temp.write_bytes(packed);os.replace(temp,path)
        report=json.loads((ROOT/'build/research'/(name+'.json')).read_bytes());assert digest(raw)==report['sha256']
        report.update(checked[name],fixture=path.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),nativeCompared=True,wholeInitializedApplicationCompared=False,wholeLibraryNativeCompared=False,pristineFixturesRewritten=False,windowsVerified=False)
        (ROOT/'docs/evidence'/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n');print('Published',name,len(packed),'bytes',flush=True)
    (ROOT/'build/research/lib-stage-commands-fixture-pins.json').write_text(json.dumps({p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')},indent=2)+'\n')
    print('Preserved',len(pins),'prior fixtures',flush=True)
if __name__=='__main__':main()
