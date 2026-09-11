#!/usr/bin/env python3
"""Read-only provenance audit for the original character menu's137 catalog inputs.
Pinned NTSD distribution, immutable full original4122f0/Object catalog corpus,
and its declared Unicorn/VC80 text/image boundaries. Derive registry ID/type,
DAT decoded bytes, name/head tokens and portrait BMP dimensions from raw files;
compare original bytes/masks and reconstruct the full portrait wrapper. No new
EXE/DLL execution, expected input to Native, memory/protection mutation, source
fault continuation or Windows/device/app claim. CHARACTER_ROSTER_INPUT_PLAN.
"""
from pathlib import Path
import argparse,base64,hashlib,json,re,struct,zlib,datetime
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256,ROOT
from inspect_original import PE

KEY=b'SiuHungIsAGoodBearBecauseHeIsVeryGood'
SPACE=b' \t\r\n\v\f'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def text_read(raw):return raw.split(b'\x1a',1)[0].replace(b'\r\n',b'\n')
def decode(raw,path):
 value=text_read(raw)
 if path[-3:].lower()!='dat':return value
 assert len(value)>=123
 plain=bytes((v-KEY[(i+123)%len(KEY)])&255 for i,v in enumerate(value[123:]))
 return text_read(plain.replace(b'\n',b'\r\n'))
def verify():
 fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-loaded-catalog.json'
 pins=json.loads((ROOT/'build/research/fresh-character-menu-fixture-pins.json').read_bytes())
 packed=fixture.read_bytes();assert sha(packed)==pins[fixture.name]
 envelope=json.loads(packed);raw=zlib.decompress(base64.b64decode(envelope['deflate']),-15)
 assert len(raw)==envelope['count'] and sha(raw)==envelope['sha256'];c=json.loads(raw)
 assert c['exeSHA256']==EXE_SHA256 and c['translation']=='text' and c['bitmapFill']==0xa5 and c['surfaceAddress']==0x24000000
 exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert sha(exe)==EXE_SHA256
 pe=PE(exe);at=pe.offset(0x448870-0x400000);default_name=exe[at:at+5];assert default_name==b'none\0'
 blobs={}
 for key,value in c['blobs'].items():
  decoded=zlib.decompress(base64.b64decode(value['deflate']),-15);assert len(decoded)==value['count'] and sha(decoded)==key;blobs[key]=decoded
 def storage(item):
  x=item['storage'];initial,value,mask=(blobs[x[k]] for k in ('initial','bytes','defined'))
  assert len(initial)==len(value)==len(mask) and set(mask)<={0,1}
  assert all(m or a==b for a,b,m in zip(initial,value,mask))
  return initial,value,mask
 files={str(p.relative_to(DEFAULT_SOURCE)).replace('/','\\').lower():p for p in DEFAULT_SOURCE.rglob('*') if p.is_file()}
 source_pins={}
 def source(name):
  p=files[name.lower()];assert p.resolve().is_relative_to(DEFAULT_SOURCE.resolve())
  value=p.read_bytes();source_pins[str(p.relative_to(DEFAULT_SOURCE))]=dict(bytes=len(value),sha256=sha(value));return value
 index=source('data\\data.txt');assert blobs[c['source']]==index
 section=text_read(index).split(b'<object>',1)[1].split(b'<object_end>',1)[0]
 entries=re.findall(rb'id:\s*([+-]?\d+)\s+type:\s*([+-]?\d+)\s+file:\s*([^\s]+)',section)
 children=[x for x in c['children'] if x['kind']=='object'];assert len(entries)==len(children)==len(c['objectAddresses'])==137
 bitmap_by_address={x['address']:x for x in c['bitmaps']};assert len(bitmap_by_address)==len(c['bitmaps'])
 result=[];decoded_bytes=0;portraits={};selectable={0:[],1:[]}
 for ordinal,((raw_id,raw_type,raw_path),child) in enumerate(zip(entries,children)):
  object_id,kind,path=int(raw_id),int(raw_type),raw_path.decode('latin1')
  assert (child['index'],child['id'],child['objectType'],child['path'])==(ordinal,object_id,kind,path)
  original=source(path);assert original==blobs[child['source']]
  decoded=decode(original,path);assert decoded==blobs[child['decoded']],(ordinal,path,'full DAT decode');decoded_bytes+=len(decoded)
  initial,value,mask=storage(child);assert len(value)==0x25360
  assert value[0x6f4:0x6fc]==struct.pack('<ii',object_id,kind) and all(mask[0x6f4:0x6fc])
  header=decoded.split(b'<bmp_begin>',1)[1].split(b'<bmp_end>',1)[0] if b'<bmp_begin>' in decoded else b''
  # Original header fields consume the next whitespace-delimited token; last
  # occurrence wins. This parser produces inputs, never reads expected names.
  tokens=re.findall(rb'[^ \t\r\n\v\f]+',header);names=[tokens[i+1] for i,t in enumerate(tokens[:-1]) if t==b'name:'];heads=[tokens[i+1] for i,t in enumerate(tokens[:-1]) if t==b'head:']
  name=names[-1] if names else default_name[:-1];head=heads[-1].decode('latin1') if heads else None
  expected_tail=bytearray(b'\xa5'*60);tail_mask=bytearray(60)
  for field in [default_name[:-1]]+names:
   assert len(field)<60 and b'\0' not in field
   expected_tail[:len(field)+1]=field+b'\0';tail_mask[:len(field)+1]=b'\1'*(len(field)+1)
  assert value[0x25324:0x25360]==expected_tail and mask[0x25324:0x25360]==tail_mask,(ordinal,path,'full name tail')
  portrait=None
  if head is not None:
   assert all(mask[0x6fc:0x700]);address=struct.unpack_from('<I',value,0x6fc)[0];record=bitmap_by_address[address]
   assert record['path']==head and record['optional']==0 and child['bitmapStart']<=c['bitmaps'].index(record)<child['bitmapEnd']
   bmp=source(head);assert bmp[:2]==b'BM' and struct.unpack_from('<I',bmp,14)[0]>=40
   width,height=struct.unpack_from('<ii',bmp,18);assert width>0 and height>0
   old,actual,defined=storage(record);expected=bytearray(b'\xa5'*0x1f50);struct.pack_into('<Iii',expected,0,0x24000000,width,height)
   expected_mask=bytes([1])*12+bytes(0x1f50-12)
   assert old==b'\xa5'*0x1f50 and actual==bytes(expected) and defined==expected_mask,(ordinal,head,'whole portrait wrapper')
   portrait=dict(path=head,width=width,height=height,bitmapOrdinal=c['bitmaps'].index(record),sourceAddress=address,originalWrapperSHA256=sha(actual),maskSHA256=sha(defined),sourceBMP=sha(bmp))
   portraits[address]=portrait
  if kind==0:assert name is not None and portrait is not None,(ordinal,path,'selectable entry needs unrecovered operand')
  for unlocked in (0,1):
   # C/Swift signed division truncates toward zero; original IDs here positive.
   group=abs(object_id)//10*(-1 if object_id<0 else 1)
   if kind==0 and (group not in (3,5) or unlocked==1):selectable[unlocked].append(ordinal)
  result.append(dict(ordinal=ordinal,id=object_id,type=kind,path=path,rawDAT=sha(original),decodedDAT=sha(decoded),decodedBytes=len(decoded),name=name.decode('latin1'),nameOrigin='DAT token' if names else 'constructor default none',nameTailSHA256=sha(expected_tail),nameMaskSHA256=sha(tail_mask),portrait=portrait))
 assert selectable[0][0]==17 and result[17]['path']=='chars\\naruto.dat' and result[21]['path']=='chars\\sasuke.dat'
 return dict(scope=__doc__,verifiedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),exeSHA256=EXE_SHA256,fixture=dict(path=str(fixture.relative_to(ROOT)),packedBytes=len(packed),packedSHA256=sha(packed),rawBytes=len(raw),rawSHA256=sha(raw)),allBlobs=len(blobs),allBlobBytes=sum(map(len,blobs.values())),registryEntries=len(result),DATDecodedBytes=decoded_bytes,nameTailBytes=len(result)*60,defaultNameSource=dict(address=0x448870,bytes=default_name.hex(),stores=[0x40f03f,0x40f059]),portraitWrappers=len(portraits),portraitWrapperBytes=len(portraits)*0x1f50,selectableOrdinals=selectable,entries=result,sourceFiles=source_pins,sourceFilesCount=len(source_pins),allSelectableNamesAndPortraitsKnown=True,nativeExpectedInputsImported=False,newOriginalExecution=False,ownInitializedLibraryCatalog=False,windowsVerified=False)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists();d=verify();a.output.write_text(json.dumps(d,indent=2)+'\n');print(json.dumps({k:v for k,v in d.items() if k not in ('entries','sourceFiles')},indent=2))
