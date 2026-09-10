#!/usr/bin/env python3
"""Independently audit NTSD network-menu research captures and transport.

Pinned EXE/lib.dll/VC80 in the declared Unicorn environment; inspect immutable
instruction bytes, explicit loader patches, full blob bytes/masks, actual caller
returns and hostname/local write provenance. Platform responses remain inputs.
Unknown private caller reads are listed, never made initialized by comparison.
No Windows, native match, device or private ABI claim follows from this audit.
"""
import argparse,base64,hashlib,json,struct,zlib
from pathlib import Path
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
H=lambda b:hashlib.sha256(b).hexdigest()
GLOBAL,SIZE,WORLD,HOST,LOCAL=0x44d000,0xb440,0x22000020,0x220007f8,0x1000f014

def inflate(e):
 z=zlib.decompressobj(-15);b=z.decompress(base64.b64decode(e['deflate'],validate=True))+z.flush()
 assert z.eof and not z.unused_data and len(b)==e['count'] and H(b)==e['sha256'];return b

def mapped(pe):
 b=bytearray(pe.u32(pe.pe+24+56));n=pe.u32(pe.pe+24+60);b[:n]=pe.data[:n]
 for s in pe.sections:b[s['rva']:s['rva']+s['fileSize']]=pe.data[s['fileOffset']:s['fileOffset']+s['fileSize']]
 return b

def audit(path,packed=None):
 raw=path.read_bytes();d=json.loads(raw);blobs={k:inflate(e) for k,e in d['blobs'].items()};assert all(H(v)==k for k,v in blobs.items())
 exe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());dll=PE((DEFAULT_SOURCE/'lib.dll').read_bytes());crt=PE((ROOT/'build/original/crt/msvcr80.dll').read_bytes())
 assert H(exe.data)==d['exeSHA256']==EXE_SHA256 and H(crt.data)==d['dllSHA256'] and H(dll.data)==d['installation']['libSHA256']
 ex=mapped(exe);lib=mapped(dll);relocs=[];cursor,length=dll.directories[5]
 while cursor<dll.directories[5][0]+length:
  page,n=struct.unpack_from('<II',lib,cursor);assert n>=8 and n%2==0
  for o in range(cursor+8,cursor+n,2):
   item=struct.unpack_from('<H',lib,o)[0];kind,at=item>>12,page+(item&4095)
   if not kind:continue
   assert kind==3;before=struct.unpack_from('<I',lib,at)[0];after=(before+0x36000000-dll.base)&0xffffffff;struct.pack_into('<I',lib,at,after);relocs.append(dict(offset=at,before=before,after=after))
  cursor+=n
 assert relocs==d['installation']['relocations'] and len(relocs)==76
 for i,item in enumerate(dll.imports()):struct.pack_into('<I',lib,int(item['iatVA'],16)-dll.base,0x36010000+16*i)
 assert len(d['installation']['patches'])==13
 for patch in d['installation']['patches']:
  o=patch['address']-exe.base;before=bytes.fromhex(patch['before']);after=bytes.fromhex(patch['after']);assert ex[o:o+len(before)]==before and len(before)==len(after)==patch['count'];ex[o:o+len(after)]=after
 images=[('EXE',exe.base,ex),('DLL',0x36000000,lib),('CRT',crt.base,mapped(crt))]
 pcs={};boundaries=set();events=Counter();network=Counter();continuations=Counter();reads=0;writes=0;local_written=0;unknown=[];helpers=0;scans=0;ui_count=0
 host=blobs[d['hostnameInitial']];mask=bytes(51);assert host==(bytes(range(51)) if d['control'] else b'\xa5'*51)
 assert blobs[d['hostname']['bytes']]==host and blobs[d['hostname']['defined']]==mask
 parts=path.with_suffix('.parts');index=json.loads((parts/'index.json').read_bytes());assert index==d['checkpointParts']
 restored=[];part_blobs={}
 for entry in index:
  b=(parts/entry['path']).read_bytes();assert H(b)==entry['sha256'] and len(b)==entry['bytes'];part=json.loads(b);restored.append(part['value'])
  for k,v in part['blobs'].items():assert k not in part_blobs and d['blobs'][k]==v;part_blobs[k]=v
 assert set(part_blobs)==set(blobs) and restored[1:]==d['calls']
 for cindex,call in enumerate(d['calls']):
  if 'network' not in call:continue
  u=call['network'];ui_count+=1;continuations[u['continuation']]+=1;helpers+=len(u['helpers'])
  assert u['entry']['pc']==0x427ca7 and u['entry']['sp']==0x1000f000 and u['entry']['registers'][:2]==[0,19]
  assert u['endPC']==(0x42873e if u['continuation']=='presentation' else 0x4287de) and u['endSP']==0x1000f000
  tail=call['tail'];assert tail['abi']['entryPC']==u['endPC'] and tail['abi']['endPC']==0x30000000 and tail['abi']['endSP']==0x1000f42c and tail['abi']['saved']==[0x11223344,0x22334455,0x33445566,0x44556677] and tail['abi']['seh']==0x12345678
  # This early-menu VM has not executed CRT floating-point startup. Its actual
  # retained control word is0, unlike the separate initialized gameplay chain.
  if 'endFPCW' in u:assert u['endFPCW']==u['entry']['fpcw']==tail['abi']['fpcw']==0
  assert u['libraryDCAfter']==tail['libraryDCBefore']
  assert blobs[u['hostnameBefore']['bytes']]==host and blobs[u['hostnameBefore']['defined']]==mask
  g=bytearray(blobs[u['before']['globals']]);w=bytearray(blobs[u['before']['world']['bytes']]);wm=bytearray(blobs[u['before']['world']['defined']]);h=bytearray(host);hm=bytearray(mask)
  for write in u['writes']:
   a=write['address'];b=bytes.fromhex(write['bytes']);writes+=len(b)
   for start,state,known in [(GLOBAL,g,None),(WORLD,w,wm),(HOST,h,hm)]:
    if start<=a<a+len(b)<=start+len(state):
     state[a-start:a-start+len(b)]=b
     if known is not None:known[a-start:a-start+len(b)]=b'\1'*len(b)
     break
   else:raise AssertionError(('unclassified write',write))
  # Earlier probes predate explicit API write traces. No CPU write overlaps
  # the supplied RNG output; applying that independent platform input is exact.
  if 'localWrites' not in u:
   for request in u['networkRequests']:
    if request['kind']=='receive' and request['arguments'][1]==3001:
     b=bytes(request['response']['bytes']);g[0x44ff90-GLOBAL:0x44ff90-GLOBAL+len(b)]=b
  assert g==blobs[u['after']['globals']],('global writes',cindex,u['label'])
  assert w==blobs[u['after']['world']['bytes']] and wm==blobs[u['after']['world']['defined']]
  assert h==blobs[u['hostnameAfter']['bytes']] and hm==blobs[u['hostnameAfter']['defined']];host,mask=bytes(h),bytes(hm)
  before=blobs[u['localBefore']];after=blobs[u['localAfter']];written=blobs[u['localWritten']]
  assert len(before)==len(after)==len(written)==0x400 and all(x in (0,1) for x in written)
  assert all(a==b for a,b,m in zip(before,after,written) if not m);local_written+=sum(written)
  if u.get('exitFrame'):
   e=u['exitFrame'];b=blobs[e['before']];a=blobs[e['after']];m=blobs[e['written']]
   assert e['frame']==e['entrySP']-0x104 and e['returnSP']==e['entrySP']+4 and len(b)==len(a)==len(m)==256
   assert all(x==y for x,y,k in zip(b,a,m) if not k)
  if 'localWrites' in u:
   actual=bytearray(before);m=bytearray(0x400)
   for write in u['localWrites']:
    o=write['address']-LOCAL;b=bytes.fromhex(write['bytes']);assert 0<=o<=o+len(b)<=0x400;actual[o:o+len(b)]=b;m[o:o+len(b)]=b'\1'*len(b)
   assert actual==after and m==written,('local write reconstruction',cindex)
   for r in u['localReads']:
    if not all(r['ownKnown']):unknown.append(dict(case=cindex,label=u['label'],**r))
  scan=[r for r in u['reads'] if r['pc']==0x428362]
  if scan:assert len(scan)==300 and [r['address'] for r in scan]==list(range(0x455378,0x455378+300));scans+=1
  reads+=len(u['reads']);events.update(e['kind'] for e in u['events']);network.update(r['kind'] for r in u['networkRequests'])
  assert [e['arguments'][0] for e in u['events'] if e['kind']=='network']==list(range(len(u['networkRequests'])))
  for instruction in u['instructions']:
   pc=instruction['address'];b=bytes.fromhex(instruction['bytes']);found=False
   if pc in (0x42873e,0x4287de,0x78132db2,0x4450ac,0x43ed10):boundaries.add(pc);continue
   for name,base,im in images:
    if base<=pc<pc+len(b)<=base+len(im):assert im[pc-base:pc-base+len(b)]==b,(name,hex(pc));pcs[pc]=name;found=True;break
   if not found:boundaries.add(pc)
 report=dict(scope=__doc__,path=str(path.relative_to(ROOT)),rawBytes=len(raw),rawSHA256=H(raw),calls=len(d['calls']),networkBodies=ui_count,continuations=dict(continuations),blobs=len(blobs),atomicParts=len(index),events=dict(events),networkRequests=dict(network),helperReturns=helpers,reads=reads,sourceWriteBytes=writes,localWrittenBytes=local_written,complete300KeyScans=scans,originalPCs=dict(Counter(pcs.values())),excludedObservedPCs=sorted(boundaries),unknownOwnLocalReads=unknown,platformAudioBindings=d.get('platformAudioBindings'),nativeCompared=False,windowsVerified=False)
 if packed:
  transport=packed.read_bytes();payload=inflate(json.loads(transport));assert payload+b'\n'==raw and json.loads(payload)==d;report.update(packedBytes=len(transport),packedSHA256=H(transport),fullPackedBytesJSONEqual=True)
 prior=json.loads((ROOT/'build/research/network-menu-prior-pins.json').read_bytes());assert len(prior)==218
 for name,sha in prior.items():assert H((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/name).read_bytes())==sha,name
 meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
 for name,entry in vendor.items():assert H((meta.parent/'vendor'/name).read_bytes())==entry['vendoredSHA256']
 report.update(priorFixtures=len(prior),vendorFiles=len(vendor));return report

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--packed');p.add_argument('--output',required=True);a=p.parse_args()
 report=audit(ROOT/a.raw,ROOT/a.packed if a.packed else None);(ROOT/a.output).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ['unknownOwnLocalReads','excludedObservedPCs','platformAudioBindings','scope']},indent=2));print('Unknown own local reads:',len(report['unknownOwnLocalReads']))
if __name__=='__main__':main()
