#!/usr/bin/env python3
"""Independently verify grouped War research transport against original raw bytes.

Read-only verification of pinned574-call setup,192-call cell and40-call
multi-human-action supplements in the
NTSD EXE/lib/VC80 Unicorn2.1.4 evidence. Compare every reconstructed byte with
the retained raw file, every group/case/metadata/audit digest, and all embedded
blob bytes. Keep masks, source2's coverage gap and declared caller boundaries.
No original execution, Native comparison, pixel/device or whole-game claim.
"""
import argparse,base64,datetime,hashlib,json,zlib
from pathlib import Path

PINS={
    '9b7e923c7f43ef328c4e7760ae5633589d83ce2bcbef430258f8d8f53a40b1aa':(3456631996,574),
    'd2f17f5a4b32cc950227de4c1061430d34242fb7b6a883c79a43d02a38547f57':(1138424571,192),
    'fba1f47a4f7770405cd139fbc2ee2bfbd86f0c059f0658e29d56c2fe8bd8f36c':(247848404,40),
}
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
