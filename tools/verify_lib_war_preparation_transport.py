#!/usr/bin/env python3
"""Independently verify bound22-call War preparation fixture transport.
Read only completed pinned NTSD EXE/lib/VC80 Unicorn2.1.4 evidence. Compare all
raw bytes/masks/metadata, groups/cases/audit and embedded blob digests. Preserve
old unbound source provenance and source/tool failure evidence. No source
execution, Native/Windows/device/full-matrix acceptance claim.
"""
import argparse,base64,datetime,hashlib,json,zlib
from pathlib import Path

PINS={'e3abb5dec759c28103c5a746972d7fb1469e7fa7b8ca151a09fc952e6d5621f6':(192093188,22)}

def sha(raw):return hashlib.sha256(raw).hexdigest()
def unpack(e):
    raw=zlib.decompress(base64.b64decode(e['deflate'],validate=True),-15)
    assert len(raw)==e['count'] and sha(raw)==e['sha256']
    return raw

def verify(index,source):
    index_raw=index.read_bytes();d=json.loads(index_raw);assert d['schema']==2
    length,total=PINS[d['source']['sha256']];assert d['source']['bytes']==length and len(d['cases'])==total
    assert source.stat().st_size==length
    audit_raw=unpack(d['auditBlob']);assert sha(audit_raw)==d['audit']['sha256']
    audit=json.loads(audit_raw);assert audit['sourceAudited'] is True and audit['cases']==total
    assert audit['raw']==dict(bytes=length,sha256=d['source']['sha256'])
    assert d['coverage']==audit['coverage'] and d['finiteAcceptanceComplete']==audit['finiteAcceptanceComplete']
    metadata_raw=unpack(d['metadataBlob']);metadata=json.loads(metadata_raw)
    files={index.name:dict(bytes=len(index_raw),sha256=sha(index_raw))};groups={}
    assert sorted(p.name for p in index.parent.glob('*.json'))==sorted([index.name]+list(d['files']))
    for name,pin in d['files'].items():
        assert Path(name).name==name
        raw=(index.parent/name).read_bytes();assert dict(bytes=len(raw),sha256=sha(raw))==pin
        files[name]=pin;groups[name]=json.loads(raw)
    assert sum(len(g['cases']) for g in groups.values())==total
    digest=hashlib.sha256();compared=0;positions=set()
    with source.open('rb') as f:
        def consume(raw):
            nonlocal compared
            assert f.read(len(raw))==raw,('original raw byte mismatch',compared)
            digest.update(raw);compared+=len(raw)
        consume(b'{"cases":[')
        for number,row in enumerate(d['cases']):
            assert row['index']==number
            group=groups[row['path']];position=row['position'];key=(row['path'],position)
            assert key not in positions;positions.add(key)
            assert group['firstCase']+position==number
            raw=unpack(group['cases'][position]);assert len(raw)==row['bytes'] and sha(raw)==row['sha256']
            c=json.loads(raw);assert c['spec']['label']==row['label']
            if number:consume(b',')
            consume(raw)
            if number%50==0:print('verified packed case',number,flush=True)
        consume(b'],'+metadata_raw[1:]+b'\n');assert not f.read(1)
    assert compared==length and digest.hexdigest()==d['source']['sha256']
    decoded=0
    for key,blob in metadata['blobs'].items():
        raw=unpack(blob);assert sha(raw)==key;decoded+=len(raw)
    assert len(metadata['blobs'])==audit['blobs'] and decoded==audit['decodedBlobBytes']
    return dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),cases=total,
        raw=dict(bytes=compared,sha256=digest.hexdigest()),files=files,packedBytes=sum(p['bytes'] for p in files.values()),
        metadataBytes=len(metadata_raw),metadataSHA256=sha(metadata_raw),blobs=len(metadata['blobs']),decodedBlobBytes=decoded,
        sourceBytesEqual=True,allGroupCaseAndBlobDigestsVerified=True,coverage=d['coverage'],nativeCompared=False)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('index',type=Path);p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();assert not a.output.exists();d=verify(a.index,a.source)
    a.output.write_text(json.dumps(d,indent=2)+'\n');print({k:d[k] for k in ('cases','raw','packedBytes','blobs','sourceBytesEqual')})
