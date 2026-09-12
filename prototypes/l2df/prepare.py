#!/usr/bin/env python3
"""Prepare task-local L2DF runtime from pinned upstream and original NTSD bytes.
No EXE/DLL execution. No source asset modifications. Python stdlib only.
"""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, datetime
PIN='a20a16f2e8c9e889e33b3d762c94dc49498d0f83'
EXE='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
ROOT=Path(__file__).resolve().parents[2]
KEY=b'odBearBecauseHeIsVeryGoodSiuHungIsAGo'
def sha(b):return hashlib.sha256(b).hexdigest()
def decrypt(b):return bytes((v-KEY[i%len(KEY)])%256 for i,v in enumerate(b[123:]))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--baseline',type=Path,required=True);a=ap.parse_args()
 build=ROOT/'build/l2df-prototype';assert build.is_symlink() and build.resolve().is_relative_to(Path('/Volumes/X5/ntsd-2.4-research')),'Task build must resolve to X5';src=build/'source'/('l2df-engine-'+PIN);game=build/'game';game.mkdir(exist_ok=True)
 import plistlib
 vol=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
 assert vol['VolumeUUID'].upper()=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548'
 assert shutil.disk_usage(build).free>6*1024**3
 assert sha((a.baseline/'NTSD 2.4.exe').read_bytes())==EXE
 manifest={'createdAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'candidateCommit':PIN,'baselineExeSHA256':EXE,'resources':[],'upstream':[],'objects':[]}
 # Verify every full archive file against the separately retained GitHub tree.
 tree=json.loads((Path('/Users/michael/Developer/ntsd-2.4/build/research/lf2-open-source-20260912/api/atom-tm__l2df-engine__wip-test__tree.json')).read_text())
 assert tree['sha']==PIN and not tree['truncated']
 for e in tree['tree']:
  if e['type']=='blob':
   p=src/e['path'];b=p.read_bytes();assert hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==e['sha'],p
 manifest['archiveGitBlobsVerified']=sum(e['type']=='blob' for e in tree['tree'])
 def vendor(s,d):
  d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(s,d)
  manifest['upstream'].append({'source':str(s.relative_to(src)),'target':str(d.relative_to(game)),'sha256':sha(s.read_bytes())})
 for p in sorted((src/'src').rglob('*')):
  if p.is_file():vendor(p,game/'l2df'/p.relative_to(src/'src'))
 for name in ('scripts','states','kinds'):
  for p in sorted((src/'presets/lf2/data'/name).rglob('*.lua')):vendor(p,game/'data'/name/p.relative_to(src/'presets/lf2/data'/name))
 vendor(src/'tools/lf2dat.lua',game/'tools/lf2dat.lua')
 for name in ('LICENSE','THIRD-PARTY-LICENSE'):vendor(src/name,game/'licenses'/('L2DF-'+name))
 def resource(rel,target=None):
  p=a.baseline/rel;dest=game/(target or rel)
  if not p.is_file():raise FileNotFoundError(str(p))
  b=p.read_bytes();dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
  manifest['resources'].append({'source':rel,'target':str(dest.relative_to(game)),'bytes':len(b),'sha256':sha(b)})
 resource('data/data.txt','original/data/data.txt')
 registry={int(m[0]):(int(m[1]),m[2].replace('\\','/')) for m in re.findall(r'id:\s*(\d+)\s+type:\s*(\d+)\s+file:\s*(\S+)',(a.baseline/'data/data.txt').read_text())}
 # Deliberately finite catalog. Missing Opoint IDs are diagnosed at runtime.
 ids=[2,11,203,224,440]
 assets=set()
 for oid in ids:
  typ,rel=registry[oid];resource(rel,'original/'+rel);decoded=decrypt((a.baseline/rel).read_bytes())
  # Pin the exact plaintext derivative; candidate Lua converter still consumes encrypted DAT.
  out=game/'derived'/rel;out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(decoded)
  manifest['objects'].append({'id':oid,'type':typ,'file':'original/'+rel,'decodedSHA256':sha(decoded),'frameMarkers':len(re.findall(rb'<frame>\s*\d+',decoded))})
  for match in re.findall(rb'(?:sprite|data)[\\/][^\s<>:"]+\.(?:bmp|wav)',decoded,re.I):assets.add(match.decode('ascii').replace('\\','/'))
 for n in ['001','002','006','016','017']:assets.add('data/'+n+'.wav')
 bgrel='bg/sys/District/bg.dat';resource(bgrel,'original/'+bgrel);bg=decrypt((a.baseline/bgrel).read_bytes());out=game/'derived/district.txt';out.write_bytes(bg)
 layers=[]
 for block in re.findall(rb'layer:\s*(.*?)layer_end',bg,re.S):
  path=block.split()[0].decode().replace('\\','/');assets.add(path)
  values={m[0].decode():int(m[1]) for m in re.findall(rb'(\w+):\s*(-?\d+)',block)}
  values['file']=path;layers.append(values)
 manifest['district']={'file':'original/'+bgrel,'decodedSHA256':sha(bg),'width':960,'zboundary':[450,525],'layers':layers}
 for rel in sorted(assets):resource(rel,'data/sounds/'+Path(rel).name if rel.lower().endswith('.wav') else rel)
 # Lua descriptor avoids introducing a runtime JSON dependency for the scene data.
 def lua(v):
  if isinstance(v,str):return json.dumps(v)
  if isinstance(v,dict):return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items())+'}'
  if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
  return str(v)
 (game/'catalog.lua').write_text('return '+lua({'objects':manifest['objects'],'district':manifest['district']})+'\n')
 for name in ('main.lua','conf.lua'):
  shutil.copy2(ROOT/'prototypes/l2df'/name,game/name)
 (build/'resource-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps({'game':str(game.resolve()),'resources':len(manifest['resources']),'resourceBytes':sum(x['bytes'] for x in manifest['resources']),'gitBlobsVerified':manifest['archiveGitBlobsVerified']}))
if __name__=='__main__':main()
