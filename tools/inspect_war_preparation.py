#!/usr/bin/env python3
"""Static preservation study of War Start43a21f..43a76d.
Read the previously saved llvm-objdump listing and immutable NTSD EXE/lib.dll.
Verify PE instruction bytes, calls, literal filename formats and x87 constants
to scope Actor/arena/replay preparation after the existing BEFORE43a21f stop.
No original execution, process memory, device/network API, pointer/protection
modification, source recapture or Native-equivalence claim. This does not
resolve the unavailable574-case setup corpus or its open dynamic comparison.
"""
import argparse,datetime,hashlib,json,struct
from pathlib import Path
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE

LISTING_SHA='763a29121956e3eabf5f2109a58145ca456f5021047cdd7c3ccf12750e0a04d2'
LIB_SHA='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
sha=lambda b:hashlib.sha256(b).hexdigest()

def inspect(listing,output):
 assert not output.exists()
 saved=listing.read_bytes();assert sha(saved)==LISTING_SHA
 document=json.loads(saved);assert document['staticOnly'] and not document['originalExecuted']
 raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();dll=(DEFAULT_SOURCE/'lib.dll').read_bytes()
 assert sha(raw)==document['exeSHA256']==EXE_SHA256 and sha(dll)==document['libSHA256']==LIB_SHA
 pe=PE(raw)
 def read(address,count):
  offset=pe.offset(address-pe.base);return raw[offset:offset+count]
 all_rows={r['address']:r for r in document['instructions']}
 rows=[r for r in document['instructions'] if 0x43a21f<=r['address']<0x43a76e]
 cursor=0x43a21f
 for row in rows:
  b=bytes.fromhex(row['bytes']);assert row['address']==cursor and read(cursor,len(b))==b
  cursor+=len(b)
 assert cursor==0x43a76e and len(rows)==330
 literals={}
 for address in [0x449d90,0x4499d8]:
  backing=read(address,256);end=backing.index(0);value=backing[:end+1]
  literals[hex(address)]=dict(bytes=value.hex(),sha256=sha(value),text=value[:-1].decode('ascii'))
 numbers={}
 for address in [0x4499c0,0x4499c8,0x4499d0,0x447928]:
  value=read(address,8);numbers[hex(address)]=dict(bytes=value.hex(),binary64=struct.unpack('<d',value)[0])
 producer_addresses=[0x438b7b,0x438b82,0x438b90,0x438b9b,0x438ba6,0x438e77]
 producers=[all_rows[a] for a in producer_addresses]
 for row in producers:
  b=bytes.fromhex(row['bytes']);assert read(row['address'],len(b))==b
 calls=[r for r in rows if r['instruction'].startswith('call')]
 ranges=[('prefix',0x43a21f,0x43a2b6),('arena',0x43a2b6,0x43a305),
         ('team_pass',0x43a305,0x43a3b1),('arena_ownership',0x43a3b1,0x43a42d),
         ('participants',0x43a42d,0x43a70c),('input_music_recording',0x43a70c,0x43a76e)]
 report=dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
  exeSHA256=EXE_SHA256,libSHA256=LIB_SHA,listing=dict(path=str(listing),sha256=LISTING_SHA),
  range=[0x43a21f,0x43a76e],instructionStarts=len(rows),byteCount=cursor-0x43a21f,
  contiguousBytesSHA256=sha(read(0x43a21f,cursor-0x43a21f)),instructions=rows,calls=calls,
  regions=[dict(name=n,start=a,end=b,starts=sum(a<=r['address']<b for r in rows)) for n,a,b in ranges],
  producerInstructions=producers,literals=literals,numbers=numbers,
  staticOnly=True,originalExecuted=False,sourceSetupAudited=False,nativeCompared=False)
 with output.open('x') as f:json.dump(report,f,indent=2);f.write('\n')
 return {k:report[k] for k in ['instructionStarts','byteCount','contiguousBytesSHA256','literals','numbers','staticOnly']}

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--listing',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 a=p.parse_args();print(inspect(a.listing,a.output))
