#!/usr/bin/env python3
"""Read-only verification of own installed-library early-screen source evidence.
Recover whole panel/body order, caller-string/target provenance, full source
stack/global/library/resource bytes and masks. Pinned NTSD/lib/VC80/DIBs and
explicit COM/GDI inputs; no source execution, expected editing, Windows/device
or worker claim. Native unproduced local fields must remain unknown.
"""
import argparse,base64,hashlib,json,re,struct,subprocess,zlib
from pathlib import Path
from collections import Counter
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from verify_menu_info_reading import unpack
BASE,FULL,STACK,SSIZE,LOCAL,LSIZE,LIB=0x44d000,0xc3a8,0x1000d000,0x2400,0x1000ea74,0xc0,0x36000000

def digest(b):return hashlib.sha256(b).hexdigest()
def key(v):return digest(json.dumps(v,sort_keys=True,separators=(',',':')).encode())
def validate(path,fixture=None):
 path=Path(path);raw=path.read_bytes();d=json.loads(raw);assert len(d['cases'])==43 and len(d['frontParents'])==39
 producer=(ROOT/'tools/oracle_application_screen_body.py').read_bytes();assert producer==path.with_name(path.stem+'-source.py').read_bytes()
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(ROOT/'build/original/crt/msvcr80.dll').read_bytes();lib=(DEFAULT_SOURCE/'lib.dll').read_bytes();assert digest(exe)==d['exeSHA256']==EXE_SHA256 and digest(dll)==d['crtSHA256'] and digest(lib)==d['libSHA256'];pe,lp=PE(exe),PE(lib)
 blobs={}
 for h,v in d['blobs'].items():
  b=zlib.decompress(base64.b64decode(v['deflate']),-15);assert len(b)==v['count'] and digest(b)==h==v['sha256'];blobs[h]=b
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';_,old=unpack(fixtures/'original-application-front-screen.json');_,loading=unpack(fixtures/'original-lib-loading.json')
 for h,c in d['frontParents'].items():assert h==key(c) and c in old['cases'] and c['end']=='critical'
 assert set(d['frontParents'])=={key(c) for c in old['cases'] if c['end']=='critical'}
 for name in ('settingsParents','bitmapParents','assets'):
  for h,v in d[name].items():assert old[name][h]==v
 for h,v in old['blobs'].items():
  if h in d['blobs']:assert v==d['blobs'][h]
 resources={r['path'][1]:r for r in pe.resources() if r['path'][0]==2}
 for name,a in d['assets'].items():
  resource=resources[name];dib=exe[resource['fileOffset']:resource['fileOffset']+resource['size']]
  assert a['kind']=='embedded' and blobs[a['raw']]==dib
  assert struct.unpack_from('<i',dib,4)[0]==a['width'] and abs(struct.unpack_from('<i',dib,8)[0])==a['height']
 install=d['installation'];assert install==loading['installation'];assert len(install['instructions'])==104 and len(install['relocations'])==76
 patched=bytearray(exe)
 for p in install['patches']:
  off=pe.offset(p['address']-pe.base);assert exe[off:off+p['count']].hex()==p['before'];patched[off:off+p['count']]=bytes.fromhex(p['after'])
 mapped=bytearray(0x5000);mapped[:0x400]=lib[:0x400]
 for s in lp.sections:mapped[s['rva']:s['rva']+s['fileSize']]=lib[s['fileOffset']:s['fileOffset']+s['fileSize']]
 for r in install['relocations']:
  assert struct.unpack_from('<I',mapped,r['offset'])[0]==r['before'];assert r['after']==(r['before']+LIB-lp.base)&0xffffffff;struct.pack_into('<I',mapped,r['offset'],r['after'])
 for n,i in enumerate(lp.imports()):struct.pack_into('<I',mapped,int(i['iatVA'],16)-lp.base,0x36010000+16*n)
 for off,a,h in zip((0x3092,0x3096),install['allocations'],d['libraryAllocations']):
  struct.pack_into('<I',mapped,off,a['address']);assert blobs[h]==bytes(a['count'])
 last=install['patches'][-1];assert last['source']==LIB+0x309c;mapped[0x309c:0x309c+last['count']]=bytes.fromhex(last['after']);assert mapped==blobs[d['libraryInitial']]
 parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==43
 counts=Counter();events=Counter();pcs={};helperCounts=Counter();readPCs=Counter()
 for i,c in enumerate(d['cases']):
  part=json.loads((parts/f'{i:04d}.json').read_bytes());fc=d['frontParents'][c['parent']];sc=d['settingsParents'][fc['parent']];bp=d['bitmapParents'][sc['parent']]
  assert part['case']==c and part['frontParent']==fc and part['settingsParent']==sc and part['bitmapParent']==bp
  for h,v in part['blobs'].items():assert d['blobs'][h]==v
  for k in ['pc','sp','globals','stack','knownStack','cw','seh','registers']:assert c['before'][k]==fc['after'][k],(i,k)
  assert c['before']['library']==d['libraryInitial'] and c['before']['retainedDC']==0
  assert c['crtBefore']==fc['crtAfter']==c['crtAfter'] and not c['crtStores']
  assert c['before']['pc']==0x427127 and c['panelReturn']['pc']==0x42712c and c['after']['pc']==0x4275cb and c['end']=='alternateDispatch'
  assert c['before']['registers']==c['after']['registers'] and c['after']['cw']==0x37f and c['after']['sp']==LOCAL and c['before']['seh']==c['after']['seh']
  # Only the actual caller producer writes the retained target, through all
  # intervening own resource/settings/background instructions.
  target=bp['parents']['entry']['worldEntry']['target'];history=[]
  for stage in (bp['parents']['entry'],bp,sc,fc):
   history += [w for w in stage['stackStores'] if w['address']<LOCAL+0x24 and LOCAL+0x20<w['address']+len(bytes.fromhex(w['bytes']))]
  assert history==[dict(pc=0x4246fd,address=LOCAL+0x20,bytes=struct.pack('<I',target).hex())];counts['targetProducerAudits']+=1
  for a,h in c['instructions'].items():
   pc=int(a,16);b=bytes.fromhex(h)
   if LIB<=pc<LIB+0x5000:expected=mapped[pc-LIB:pc-LIB+len(b)]
   else:off=pe.offset(pc-pe.base);expected=patched[off:off+len(b)]
   assert b==expected,(a,h);pcs[a]=h
  assert '0x4275cb' not in c['instructions'] and '0x401290' in c['instructions']
  # These actual final starts recover EAX's selector producer even though the
  # source snapshot only stores nonvolatile registers. EDI/ESI reloads cannot
  # change EAX. Keep this instruction-derived result distinct from a register
  # snapshot; there is no additional measured EAX field in the raw corpus.
  for a,b in [('0x4275bc','a164d04400'),('0x4275c1','8b7c2420'),('0x4275c5','8b3598704400')]:assert c['instructions'][a]==b
  assert struct.unpack_from('<i',blobs[c['after']['globals']],0x64)[0]==0;counts['selectorProducerAudits']+=1
  g=bytearray(blobs[c['before']['globals']]);gm=bytearray(FULL);stack=bytearray(blobs[c['before']['stack']]);known=bytearray(blobs[c['before']['knownStack']]);lm=bytearray(LSIZE);lr=bytearray(mapped);wi=0
  def write(w):
   b=bytes.fromhex(w['bytes']);p=w['address'];n=len(b)
   if w['pc'] is not None:assert hex(w['pc']) in c['instructions'];counts['CPUStores']+=1
   else:counts['APIStores']+=1
   counts['storeBytes']+=n
   if BASE<=p<p+n<=BASE+FULL:g[p-BASE:p-BASE+n]=b;gm[p-BASE:p-BASE+n]=b'\1'*n
   elif STACK<=p<p+n<=STACK+SSIZE:
    stack[p-STACK:p-STACK+n]=b;known[p-STACK:p-STACK+n]=b'\1'*n
    if LOCAL<=p<p+n<=LOCAL+LSIZE:lm[p-LOCAL:p-LOCAL+n]=b'\1'*n
   else:
    assert p==LIB+0x306e and n==4 and w['pc']==LIB+0x12bd;lr[p-LIB:p-LIB+n]=b;counts['libraryDCStores']+=1
  def advance(n):
   nonlocal wi
   assert n>=wi
   while wi<n:write(c['writes'][wi]);wi+=1
  # Merge observations by number of completed stores. CPU write hooks see old
  # memory while their pending store is already present in the log.
  checks=[]
  for e in c['events']:
   n=e['storeCount']-(e['event']['kind'] in ('write','writeLocal'));checks.append((n,'event',e))
  for r in c['localReads']:checks.append((r['storeCount'],'read',r))
  for s in (c['before'],c['panelReturn'],c['after']):checks.append((s['storeCount'],'state',s))
  currentBitmap=None
  for n,kind,q in sorted(checks,key=lambda x:x[0]):
   advance(n)
   if kind=='state':
    assert g==blobs[q['globals']] and gm==blobs[q['mask']] and stack==blobs[q['stack']] and known==blobs[q['knownStack']]
    assert lm==blobs[q['localMask']] and stack[LOCAL-STACK:LOCAL-STACK+LSIZE]==blobs[q['local']] and lr==blobs[q['library']]
    assert struct.unpack_from('<I',lr,0x306e)[0]==q['retainedDC'];counts['stateCheckpoints']+=1
   elif kind=='read':
    a=q['address'];size=q['count'];offset=a-LOCAL;assert bytes.fromhex(q['bytes'])==stack[a-STACK:a-STACK+size]
    assert q['written']==list(lm[offset:offset+size]) and q['known']==list(known[a-STACK:a-STACK+size]);readPCs[hex(q['pc'])]+=1;assert hex(q['pc']) in c['instructions']
    if not all(q['written']):assert a==LOCAL+0x20 and size==4 and q['pc'] in (0x4274da,0x4275c1) and bytes.fromhex(q['bytes'])==struct.pack('<I',target);counts['retainedTargetReads']+=1
    else:counts['producedLocalReads']+=1;counts['producedLocalReadBytes']+=size
   else:
    assert g==blobs[q['globals']];e=q['event'];events[e['kind']]+=1
    if e['kind']=='draw':currentBitmap=next(r for r in c['records'] if r['address']==e['arguments'][0]);assert e['arguments'][6]==target
    if e['kind']=='read':
     r=e['read'];b=blobs[currentBitmap['bytes']];m=blobs[currentBitmap['mask']];assert struct.unpack_from('<I',b,r['offset'])[0]==r['value'] and bool(r['defined'])==all(m[r['offset']:r['offset']+4]);counts['undefinedBitmapReads']+=not r['defined']
    if e['kind']=='text':assert e['arguments'][0]==target
  advance(len(c['writes']));assert c['records']==fc['records'];assert not any(gm)
  assert sum(lm)==92 and lm[0x20:0x24]==bytes(4);counts['nativeOwnedLocalBytes']+=96;counts['nativeUnknownLocalBytes']+=96
  assert c['after']['retainedDC']==(0 if c['spec']['dcResult']<0 else c['spec']['dc'])
  for h in c['helpers']:
   assert h['returnSP']==h['sp']+4+h['pop'] and hex(h['entry']) in c['instructions'];helperCounts[hex(h['entry'])]+=1
  counts['helperReturns']+=len(c['helpers']);counts['wrapperRecords']+=len(c['records']);counts['fullRecordBytes']+=len(c['records'])*0x1f50;counts['fullStackBytes']+=2*SSIZE;counts['fullGlobalBytes']+=2*FULL;counts['fullLibraryBytes']+=2*len(mapped)
 coverage={}
 for name,start,end in [('caller',0x427127,0x4275cb),('panel',0x4236d0,0x4237d4)]:
  output=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',f'--start-address={hex(start)}',f'--stop-address={hex(end)}',str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True);items=[]
  for line in output.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
   if m:items.append(dict(address=hex(int(m[1],16)),bytes=bytes.fromhex(m[2]).hex(),instruction=m[3]))
  coverage[name]=dict(static=len(items),executed=sum(v['address'] in pcs for v in items),unexecuted=[v for v in items if v['address'] not in pcs])
 pins=json.load(open(ROOT/'build/research/application-screen-body-prior-pins.json'));assert len(pins)==242
 for name,h in pins.items():assert digest((fixtures/name).read_bytes())==h
 vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
 for name,m in v['files'].items():assert digest((vendor/'vendor'/name).read_bytes())==m['vendoredSHA256']
 report=dict(sourceBytes=len(raw),sourceSHA256=digest(raw),producerSHA256=digest(producer),cases=43,exactFrontParents=39,settingsParents=len(d['settingsParents']),bitmapParents=len(d['bitmapParents']),counts=dict(counts),events=dict(events),helpers=dict(helperCounts),actualEXE=sum(int(a,16)<LIB for a in pcs),actualDLL=sum(int(a,16)>=LIB for a in pcs),actualCRT=0,localReadPCs=dict(readPCs),coverage=coverage,blobs=len(blobs),assets=len(d['assets']),atomicParts=43,priorFixturesUnchanged=242,vendorFiles=10,installerOriginalPCs=104,installerRelocations=76,installerCopies=13,installerCopyBytes=62,fullOriginalStatesReconstructed=True,ownParentsRetained=True,sourceFaults=0,wholeDispatcherReturns=0,workerBodyExecuted=False,windowsVerified=False)
 if fixture:
  payload,value=unpack(fixture);assert payload+b'\n'==raw and value==d;p=Path(fixture).read_bytes();report.update(fixtureBytes=len(p),fixtureSHA256=digest(p),fullRawPackedBytesJSON=True)
 return report
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source');p.add_argument('--fixture');p.add_argument('--report');a=p.parse_args();r=validate(a.source,a.fixture)
 if a.report:Path(a.report).write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps({k:v for k,v in r.items() if k not in ('coverage','localReadPCs')},indent=2))
