#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Finish the controlled War success matrix with two fresh Random chains.
Pinned NTSD EXE/lib/VC80/original resources, Unicorn2.1.4/CW023f/C locale and
normal declared APIs. Retain234 completed fixed-arena calls bytewise; execute
only22 calls from two fresh401-constructor parents. Account for actual music
stream1 before arena stream123; no RNG result hook or after-state import.
Memory/stack/ownership traces recover arena/participant/recording order, at
synthetic allocation/device boundaries separate from Windows/host behavior.
Preserve capture2's245 complete returns, including the normal arena9 return
that failed the old input expectation. Never resume or restart that process.
No source memory fault/protection change/safeguard retry or Native/full-game
claim. LIB_WAR_PREPARATION_MATRIX_RANDOM_INPUTS.md defines the finite correction.
"""
import argparse,base64,copy,datetime,hashlib,json,os,shutil,struct,zlib
from pathlib import Path
from oracle_lib_war_preparation_matrix import WarPreparationMatrix,specifications as previous_specifications
from oracle_lib_war_preparation import tournament_inputs,arena_inputs,catalog_input,CATALOG_FILE,CATALOG_SHA
from oracle_lib_war_preparation import ROOT,EXE_SHA256,DLL_SHA256,WORLD,BM,TARGET,LIB,STACK,SP,TAIL_SP


def specifications():
 specs=previous_specifications()
 for number in [244,255]:
  s=specs[number];seed=0xffffffff if s['control'] else 17;table=[]
  for _ in range(3000):
   seed=(seed*0x343fd+0x269ec3)&0xffffffff;table.append(((seed>>16)&0x7fff)%255+1)
  desired=14 if s['control'] else 0
  # Whole Start first calls the music-choice helper(stream1), then arena123.
  index=next(i for i in range(3000) if (table[(i+2)%3000]+2)%15==desired)
  s['matrixInputs']['words'][0x450bcc]=index
  s['randomMusicInput']=dict(index=index,counter=0,range=8,result=(table[(index+1)%3000]+1)%8)
  s['randomArenaInput']=dict(index=(index+1)%3000,counter=1,range=15,result=desired)
 return specs


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--manifest-only',action='store_true');a=p.parse_args()
 assert not a.output.exists();specs=specifications()
 if a.manifest_only:a.output.write_text(json.dumps(specs,indent=2)+'\n');print('Finite calls',len(specs),'fresh22/retained234');return
 base=ROOT/'build/research/lib-war-preparation';review_path=base/'war-preparation-matrix-capture2-review.json';review=json.loads(review_path.read_text())
 assert review['originalCallsCompleted']==245 and review['job']['status']=='terminal'
 inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input()
 parts=a.output.with_suffix('.parts');parts.mkdir();blobs={};installations=[];assets={};parents=[];paths=[]
 counts=dict(calls=0,parentsReproduced=0,capture1CallsReproduced=0,capture2RetainedCalls=0,capture2PrefixReproduced=0,freshOriginalCalls=0,preparations=0,participants=0,cpu=0,human=0)
 canonical=lambda x:json.dumps(x,separators=(',',':')).encode()
 def blob(k):
  x=blobs[k];raw=zlib.decompress(base64.b64decode(x['deflate']),-15)
  assert len(raw)==x['count'] and hashlib.sha256(raw).hexdigest()==k;return raw
 for number,s in enumerate(specs):
  assert shutil.disk_usage(parts).free>6*1024**3,'researchStorageLimit: preserve6GiB reserve'
  part=parts/f'{number:04d}.json';temp=part.with_suffix('.tmp')
  if number<234:
   old=(base/'war-preparation-matrix-capture2.parts'/part.name).resolve();pin=review['parts'][str(old)];raw=old.read_bytes()
   assert len(raw)==pin['bytes'] and hashlib.sha256(raw).hexdigest()==pin['sha256'];item=json.loads(raw)
   assert canonical(item['case']['spec'])==canonical(s)
   temp.write_bytes(raw);os.replace(temp,part);counts['capture2RetainedCalls']+=1
  else:
   if not s.get('chain'):
    vm=WarPreparationMatrix(s['control'],inputs,arenas,catalog);vm.capture_path=a.output
    parent=dict(firstCase=number,constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs)
   c=vm.next_step(s) if s.get('chain') else vm.probe(s)
   assert c['end']=='returned';counts['freshOriginalCalls']+=1
   item=dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,parents=[parent])
   with temp.open('w') as f:json.dump(item,f,separators=(',',':'));f.write('\n')
   os.replace(temp,part)
   if number<244:
    old=(base/'war-preparation-matrix-capture2.parts'/part.name).resolve();pin=review['parts'][str(old)];raw=old.read_bytes()
    assert len(raw)==pin['bytes'] and hashlib.sha256(raw).hexdigest()==pin['sha256'] and part.read_bytes()==raw
    counts['capture2PrefixReproduced']+=1
  paths.append(part);c=item['case'];assert c['end']=='returned';counts['calls']+=1
  installations.append(copy.deepcopy(item['installation']))
  if not s.get('chain'):parents+=copy.deepcopy(item['parents'])
  assert item['parents']==parents[-1:]
  for k,v in item['blobs'].items():assert k not in blobs or blobs[k]==v;blobs[k]=v
  for k,v in item['assets'].items():assert k not in assets or assets[k]==v;assets[k]=v
  if number<25:
   assert part.read_bytes()==(base/'war-preparation-matrix-capture1.parts'/part.name).read_bytes();counts['capture1CallsReproduced']+=1
  first=parents[-1]['firstCase']
  if number-first<2:
   old_number=(11 if s['control'] else 0)+number-first
   old=json.loads((base/'war-preparation-bound-capture1.parts'/f'{old_number:04d}.json').read_bytes())
   old['parents'][0]['firstCase']=first
   assert canonical(c)==canonical(old['case']) and canonical(item['parents'])==canonical(old['parents'])
   counts['parentsReproduced']+=1
  if s.get('expectedPreparation'):
   records={r['address']:r['storage'] for r in c['after']};g=blob(records[0x44d000]['bytes']);w=blob(records[WORLD]['bytes'])
   assert struct.unpack_from('<i',g,0x44d024-0x44d000)[0]==s['arenaExpectation']
   draws=[h for h in c['helpers'] if h.get('stream') in (0x125,0x127)];active=[]
   for seat in range(8):
    status=struct.unpack_from('<i',g,0x451288+seat*4-0x44d000)[0]
    if status>0:cpu=status>10;active.append(seat+10 if cpu else seat);counts['cpu' if cpu else 'human']+=1
   assert len(draws)==len(active) and [i for i,v in enumerate(w[4:404]) if v]==sorted(active)
   for key,stream in [('randomMusicInput',1),('randomArenaInput',0x123)]:
    if key in s:
     h=next(h for h in c['helpers'] if h.get('stream')==stream)
     for field,value in s[key].items():assert h[field]==value,(number,stream,field,h[field],value)
   counts['preparations']+=1;counts['participants']+=len(active)
  if number%25==0 or number>=234:print('retained' if number<234 else 'completed',number,s['label'],flush=True)
 assert counts==dict(calls=256,parentsReproduced=40,capture1CallsReproduced=25,capture2RetainedCalls=234,capture2PrefixReproduced=10,freshOriginalCalls=22,preparations=56,participants=340,cpu=168,human=172)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,
  catalogDependency=dict(path=str(CATALOG_FILE.relative_to(ROOT)),sha256=CATALOG_SHA,bitmapAddresses=[v['address'] for v in catalog['bitmaps']],checksum=catalog['checksum']),
  parents=parents,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,counts=counts,
  retainedSource=dict(reviewPath=str(review_path),reviewSHA256=hashlib.sha256(review_path.read_bytes()).hexdigest(),retainedCalls=234,prefixReproductions=10),nativeCompared=False,windowsVerified=False)
 temp=a.output.with_suffix('.tmp')
 with temp.open('w') as f:
  f.write('{"cases":[')
  for i,part in enumerate(paths):
   if i:f.write(',')
   item=json.loads(part.read_bytes());json.dump(item['case'],f,separators=(',',':'))
  f.write(']')
  for key,value in d.items():f.write(','+json.dumps(key)+':');json.dump(value,f,separators=(',',':'))
  f.write('}\n')
 os.replace(temp,a.output);h=hashlib.sha256()
 with a.output.open('rb') as f:
  for raw in iter(lambda:f.read(8*1024*1024),b''):h.update(raw)
 print(dict(counts=counts,bytes=a.output.stat().st_size,sha256=h.hexdigest()),flush=True)

if __name__=='__main__':main()
