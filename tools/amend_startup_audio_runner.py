"""Preserve the prepared runner; publish finite three-digit indexing correction."""
import ast,datetime,difflib,json,re,shutil
from pathlib import Path
from archive_catalog53_storage import ROOT,pin,checked
from apply_startup_audio_candidate import once
T=(ROOT/'build/research/application-startup-audio-20260927').resolve()
def rec(p):return dict(path=str(p.resolve()),**pin(p))
def save(n,v):
 p=T/n;assert not p.exists();p.write_text(json.dumps(v,indent=2)+'\n')
def main():
 assert json.loads((T/'prepare1.job.json').read_text())['exitCode']==0
 assert not (T/'build1.job.json').exists() and not (T/'tests1-queue.job.json').exists()
 oldpins=json.loads((T/'runner-inputs1.json').read_text())
 for r in oldpins:checked(Path(r['path']),r)
 names=['run_application_host_gameplay_validation','run_application_host_gameplay_tests']
 changes=[]
 for name in names:
  src=T/'tools'/(name+'.py');dst=T/'tools'/(name+'2.py');assert not dst.exists();a=src.read_text()
  if name==names[0]:
   b=once(a,"index=int(phase[-2:])-1","index=int(phase.split('-',1)[1])-1").replace('runner-inputs1.json','runner-inputs2.json')
   assert a[a.index('    def identity(pid):'):]==b[b.index('    def identity(pid):'):].replace('runner-inputs2.json','runner-inputs1.json')
  else:
   b=a.replace('from run_application_host_gameplay_validation import','from run_application_host_gameplay_validation2 import').replace('/run_application_host_gameplay_validation.py','/run_application_host_gameplay_validation2.py')
   start,end='            done = re.findall(',"            job['completed'].append("
   assert a[a.index(start):a.index(end)]==b[b.index(start):b.index(end)]
  ast.parse(b);dst.write_text(b)
  changes.append(dict(source=rec(src),output=rec(dst),patch=''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile=src.name,tofile=dst.name))))
 phases=[f'test-{i:02d}' for i in range(1,106)];pattern=r'build1|test-(0[1-9]|[1-9][0-9]|10[0-5])'
 assert [int(p.split('-',1)[1])-1 for p in phases]==list(range(105))
 assert all(re.fullmatch(pattern,p) for p in ['build1']+phases)
 assert all(not re.fullmatch(pattern,p) for p in ['test-00','test-106','test-999','test-1','build2'])
 plan=ROOT/'docs/research/APPLICATION_STARTUP_AUDIO_RUNNER_AMENDMENT.md'
 for src,name in [(plan,'runner-amendment1.md'),(Path(__file__),'runner-amendment1.py')]:shutil.copy2(src,T/name)
 save('runner-amendment1.json',dict(UTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),changes=changes,guardBodyUnchanged=True,resultPredicatesUnchanged=True,phaseIndices=105,phasePositive=106,phaseNegative=5,candidateUnchanged=rec(T/'candidate1-inputs.json'),originalExecuted=False,nativeExecuted=False))
 save('runner-inputs2.json',oldpins+[rec(T/'tools'/(n+'2.py')) for n in names]+[rec(plan),rec(Path(__file__)),rec(T/'runner-amendment1.json')])
 for r in oldpins:checked(Path(r['path']),r)
 print('Runner2 published: 105 exact indices; original producers retained.')
if __name__=='__main__':main()
