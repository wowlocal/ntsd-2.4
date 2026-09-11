#!/usr/bin/env python3
"""Losslessly package the separate bound22-call War preparation preflight.
Original NTSD EXE/lib/VC80/resources, controlled Unicorn2.1.4/CW023f observations.
Require full source audit and exact atomic case index. Preserve every original
raw byte/mask/metadata/newline and all older unbound corpora. Transport deflation
only stores research fixtures; it is not game replay compression. No source
execution, Native/Windows/device/full-matrix acceptance claim.
"""
import argparse,base64,hashlib,json,zlib
from pathlib import Path
from index_lib_war_preparation import PROFILES
from verify_lib_war_setup import stream_document,canonical,sha

def envelope(raw):
    codec=zlib.compressobj(9,wbits=-15)
    packed=codec.compress(raw)+codec.flush()
    assert zlib.decompress(packed,-15)==raw
    return dict(count=len(raw),sha256=sha(raw),deflate=base64.b64encode(packed).decode('ascii'))

def package(source,audit,index,output,profile='preparation'):
    assert not output.exists()
    expected=PROFILES[profile];stem=expected['fixture'];total=expected['cases']
    audit_raw=audit.read_bytes();report=json.loads(audit_raw)
    assert report['sourceAudited'] is True and report['cases']==total
    assert report['raw']=={k:expected[k] for k in ('bytes','sha256')}
    indexed=json.loads(index.read_bytes())
    assert indexed['schema']==1 and len(indexed['cases'])==total
    assert indexed['audit']['sha256']==sha(audit_raw)
    metadata,case_hashes,pin=stream_document(source)
    assert pin==report['raw'] and len(case_hashes)==total
    metadata_raw=canonical(metadata)
    output.mkdir(parents=True)
    digest=hashlib.sha256();count=0
    def consume(raw):
        nonlocal count
        digest.update(raw);count+=len(raw)
    consume(b'{"cases":[')
    rows=[];files={};group=[];group_number=0
    def flush():
        nonlocal group,group_number
        name=f'{stem}-cases{group_number+1}.json'
        raw=canonical(dict(firstCase=len(rows)-len(group),cases=group))+b'\n'
        with (output/name).open('xb') as f:f.write(raw)
        files[name]=dict(bytes=len(raw),sha256=sha(raw))
        group=[];group_number+=1
    for number,entry in enumerate(indexed['cases']):
        assert entry['index']==number
        part=index.parent/entry['path'];raw=part.read_bytes()
        assert dict(bytes=len(raw),sha256=sha(raw))=={k:entry[k] for k in ('bytes','sha256')}
        document=json.loads(raw);case=canonical(document['case'])
        assert sha(case)==case_hashes[number] and document['case']['spec']['label']==entry['label']
        assert document['installation']==metadata['installations'][number]
        for key in ('blobs','assets'):
            for name,value in document[key].items():assert metadata[key][name]==value
        parent=max((p for p in metadata['parents'] if p['firstCase']<=number),key=lambda p:p['firstCase'])
        assert document['parents']==[parent]
        if number:consume(b',')
        consume(case)
        rows.append(dict(index=number,label=entry['label'],path=f'{stem}-cases{group_number+1}.json',position=len(group),bytes=len(case),sha256=sha(case)))
        group.append(envelope(case))
        if len(group)==50:flush()
        if number%25==0:print('packed',number,entry['label'],flush=True)
    if group:flush()
    consume(b'],'+metadata_raw[1:]+b'\n')
    assert dict(bytes=count,sha256=digest.hexdigest())==pin
    result=dict(schema=2,scope=__doc__,profile=profile,source=indexed['source'],audit=dict(sha256=sha(audit_raw)),
        auditBlob=envelope(audit_raw),metadataBlob=envelope(metadata_raw),cases=rows,files=files,
        coverage=report.get('coverage'),finiteAcceptanceComplete=report.get('finiteAcceptanceComplete',False),nativeCompared=False)
    raw=canonical(result)+b'\n'
    with (output/(stem+'.json')).open('xb') as f:f.write(raw)
    return dict(cases=total,raw=pin,files=len(files)+1,packedBytes=len(raw)+sum(v['bytes'] for v in files.values()),
        indexSHA256=sha(raw),allOriginalRawBytesReconstructed=True,nativeCompared=False)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('source',type=Path);p.add_argument('--audit',type=Path,required=True)
    p.add_argument('--index',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--profile',choices=PROFILES,default='preparation')
    a=p.parse_args();print(package(a.source,a.audit,a.index,a.output,a.profile))
