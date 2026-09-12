#!/usr/bin/env python3
"""Fuse the pinned native LÖVE bundle and verified local game into a standalone app."""
from pathlib import Path
import argparse,hashlib,json,plistlib,shutil,subprocess,zipfile,datetime
ROOT=Path(__file__).resolve().parents[2];BUILD=ROOT/'build/l2df-prototype';GAME=BUILD/'game'
p=argparse.ArgumentParser();p.add_argument('--name',default='NTSD L2DF Prototype.app');a=p.parse_args()
assert Path(a.name).name==a.name and a.name.endswith('.app')
assert BUILD.is_symlink() and BUILD.resolve().is_relative_to(Path('/Volumes/X5/ntsd-2.4-research'))
APP=BUILD/a.name
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not APP.exists(),'Preserve existing app; use a new output name for a new package.'
assert sha(BUILD/'runtime/love.app/Contents/MacOS/love')=='0daa04d49e671e7d3649e54935a91e8dcbf0769bef8d1c3503c025842b680da2'
subprocess.run(['ditto',str(BUILD/'runtime/love.app'),str(APP)],check=True)
pl=APP/'Contents/Info.plist';info=plistlib.loads(pl.read_bytes());info.update(CFBundleIdentifier='local.ntsd.l2df-prototype',CFBundleName='NTSD L2DF Prototype',CFBundleDisplayName='NTSD L2DF Prototype');pl.write_bytes(plistlib.dumps(info))
love=APP/'Contents/Resources/NTSD.love'
files=[p for p in sorted(GAME.rglob('*')) if p.is_file()]
with zipfile.ZipFile(love,'w',zipfile.ZIP_DEFLATED) as archive:
 for p in files:archive.write(p,p.relative_to(GAME))
with zipfile.ZipFile(love) as archive:
 assert archive.testzip() is None
 for p in files:assert archive.read(str(p.relative_to(GAME)))==p.read_bytes()
shutil.copy2(BUILD/'resource-manifest.json',APP/'Contents/Resources/resource-manifest.json')
# Symlinks supplied by LÖVE may alias bundled Framework versions, never external content.
links=[]
for p in APP.rglob('*'):
 if p.is_symlink():assert p.resolve().is_relative_to(APP.resolve()),p;links.append(str(p.relative_to(APP)))
result={'createdAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'app':str(APP.resolve()),'loveBundleVersion':info['CFBundleShortVersionString'],'gameFiles':len(files),'gameBytes':sum(p.stat().st_size for p in files),'zipSHA256':sha(love),'executableSHA256':sha(APP/'Contents/MacOS/love'),'allZIPMembersCompared':True,'externalSymlinks':False,'internalFrameworkSymlinks':links,'signature':'Original downloaded LÖVE runtime unsigned; prototype not notarized','files':[{'path':str(p.relative_to(APP)),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(APP.rglob('*')) if p.is_file() and not p.is_symlink()]}
(BUILD/('package-manifest.json' if a.name=='NTSD L2DF Prototype.app' else a.name+'.manifest.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ['files','internalFrameworkSymlinks']}))
