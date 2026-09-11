#!/usr/bin/env python3
"""Independently replay immutable character-menu source writes/read masks.
This verifier executes no EXE/DLL. Recover resource/globals/stack snapshots,
per-helper API masks and the last producer of reused copy dimensions from the
declared controlled NTSD/VC80/Unicorn capture. Unknown initial bytes remain
unknown; source-only operand cases are not native matches. See both character
menu surface study plans. No corpus/expected/native input is modified.
"""
import argparse,base64,collections,hashlib,json,time,zlib
from pathlib import Path

def verify(path):
 raw=path.read_bytes();d=json.loads(raw);decoded={}
 for key,b in d['blobs'].items():
  value=zlib.decompress(base64.b64decode(b['deflate']),wbits=-15)
  assert len(value)==b['count'] and hashlib.sha256(value).hexdigest()==key==b['sha256']
  decoded[key]=value
 counts=collections.Counter();cases=[];pcs={}
 for c in d['cases']:
  blocks=[]
  def block(p,raw,known,kind):
   r=dict(address=p,bytes=bytearray(raw),mask=bytearray(known),last=[None]*len(raw),kind=kind);blocks.append(r);return r
  stack=block(d['fullStackAddress'],decoded[c['before']['fullStack']],decoded[c['before']['fullKnownStack']],'stack')
  glob=block(0x44d000,decoded[c['before']['globals']],b'\1'*len(decoded[c['before']['globals']]),'globals')
  bitmaps={r['address']:block(r['address'],decoded[r['initial']],bytes(r['count']),'bitmap') for r in c['records']}
  def owner(p,n):return next((r for r in blocks if r['address']<=p<p+n<=r['address']+len(r['bytes'])),None)
  def equal(r,bkey,mkey=None):
   assert bytes(r['bytes'])==decoded[bkey],(c['spec']['label'],r['kind'],'bytes',bkey)
   if mkey:assert bytes(r['mask'])==decoded[mkey],(c['spec']['label'],r['kind'],'mask',mkey)
  def snapshot(s,records):
   equal(stack,s['fullStack'],s['fullKnownStack']);equal(glob,s['globals'])
   offset=d['stackAddress']-d['fullStackAddress'];end=offset+d['stackCount']
   assert bytes(stack['bytes'][offset:end])==decoded[s['stack']] and bytes(stack['mask'][offset:end])==decoded[s['knownStack']]
   for r in records:
    equal(bitmaps[r['address']],r['bytes'],r['mask']);assert r['guards']==['96'*16,'69'*16]
    counts['recordSnapshots']+=1;counts['recordSnapshotBytes']+=r['count']
   counts['snapshots']+=1
  writes=c['writes'];reads=c['reads'];checks=c['checkpoints'];events=c['events'];ri=ci=ei=0
  origins=[];unknown=[]
  for index in range(len(writes)+1):
   while ri<len(reads) and reads[ri]['storeCount']==index:
    q=reads[ri];p,n=q['address'],q['count'];r=owner(p,n);assert r is not None
    off=p-r['address'];assert r['bytes'][off:off+n].hex()==q['bytes'] and list(r['mask'][off:off+n])==q['known'],q
    if not all(q['known']):unknown.append(q)
    if q['pc'] in (0x40147e,0x40148a):
     last=r['last'][off:off+n];origin=dict(read=ri,pc=hex(q['pc']),address=hex(p),bytes=q['bytes'],writers=last)
     for wi in set(last):
      if wi is None:assert not any(q['known'])
      else:
       w=writes[wi];event=events[w['eventIndex']-1]
       assert w['pc'] is None and event['request']['kind']=='description',('Dimension producer',w,event)
       assert len(bytes.fromhex(w['bytes']))==108
       origin.update(eventIndex=w['eventIndex']-1,requestKey=event['key'],surface=event['request']['words'][0])
     origins.append(origin)
    ri+=1;counts['reads']+=1;counts['readBytes']+=n
   while ci<len(checks) and checks[ci]['storeCount']==index:
    q=checks[ci];assert q['readCount']==ri;snapshot(q['snapshot'],q['records']);ci+=1
   while ei<len(events) and events[ei]['storeCount']==index:
    e=events[ei];q=e.get('request',{})
    if 'globals' in e:equal(glob,e['globals']);counts['eventGlobals']+=1
    if 'bytes' in q:
     kind=q['kind'];h=next(h for h in c['helpers'] if h['kind']==('loader' if kind=='createSurface' or kind=='getObject' and e['returnPC']==0x43ed6b else 'copy') and h['eventStart']<=ei<h['eventEnd'])
     offset=0x84 if kind=='createSurface' or kind=='getObject' and h['kind']=='copy' else 24 if kind=='getObject' else 0x6c
     p=h['sp']-offset;n=len(q['bytes']);r=owner(p,n);assert r is not None
     assert list(r['bytes'][p-r['address']:p-r['address']+n])==q['bytes'],(c['spec']['label'],e['key'],'private bytes')
     mask=bytearray(n)
     for w in writes[h['firstStore']:index]:
      lo=max(p,w['address']);hi=min(p+n,w['address']+len(bytes.fromhex(w['bytes'])))
      if lo<hi:mask[lo-p:hi-p]=b'\1'*(hi-lo)
     assert [bool(x) for x in mask]==q['defined'],(c['spec']['label'],e['key'],'helper-entry mask')
     counts['requestStructures']+=1;counts['requestStructureBytes']+=n
    ei+=1
   if index==len(writes):break
   w=writes[index];p=w['address'];b=bytes.fromhex(w['bytes']);r=owner(p,len(b))
   assert r is not None,('Unclassified write',c['spec']['label'],w)
   off=p-r['address'];r['bytes'][off:off+len(b)]=b;r['mask'][off:off+len(b)]=b'\1'*len(b);r['last'][off:off+len(b)]=[index]*len(b)
   counts['writes']+=1;counts['writeBytes']+=len(b)
  assert (ri,ci,ei)==(len(reads),len(checks),len(events))
  snapshot(c['after'],c['records'])
  for h in c['helpers']:
   assert h['returnSP']==h['sp']+4+h['pop']
   if h['kind']=='constructor':assert h['result']==h['wrapper']
   counts['helperReturns']+=1
  assert c['before']['cw']==c['after']['cw']==0 # Captured default, no FPU/device claim.
  for pc,code in c['instructions'].items():
   assert pc not in pcs or pcs[pc]==code;pcs[pc]=code
  if unknown:assert c['spec']['label'] in ('object-first-zero','first-description-unavailable') and len(unknown)==2
  cases.append(dict(label=c['spec']['label'],end=c['end'],unknownReads=unknown,copyDimensionOrigins=origins))
 counts['cases']=len(cases);counts['blobs']=len(decoded);counts['blobBytes']=sum(map(len,decoded.values()))
 counts['originalEXEPCs']=sum(int(pc,16)<0x78000000 for pc in pcs);counts['originalCRTPCs']=sum(int(pc,16)>=0x78000000 for pc in pcs)
 return dict(scope=__doc__,input=str(path),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),counts=dict(counts),cases=cases,nativeCompared=False,windowsVerified=False)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 assert not a.output.exists();started=time.monotonic();d=verify(a.input);d['elapsedSeconds']=round(time.monotonic()-started,3)
 a.output.write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(dict(counts=d['counts'],elapsedSeconds=d['elapsedSeconds']),indent=2))
