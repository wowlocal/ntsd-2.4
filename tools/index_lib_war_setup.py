#!/usr/bin/env python3
"""Index the preserved574 War source cases for bounded-memory Native comparison.
Reads only the completed pinned NTSD EXE/lib/VC80 Unicorn2.1.4 corpus and its
successful full read/store/REP/ownership audit. No EXE execution, recapture,
expected-byte edits, Windows/device or Native-equivalence claim. Keep the
original raw document and every atomic part immutable. The index holds input
metadata and exact part hashes; it does not import an after-state into Native.
"""
import argparse,datetime,hashlib,json,os
from pathlib import Path
from verify_lib_war_setup import stream_document,canonical,sha

RAW_BYTES=3456631996
RAW_SHA='9b7e923c7f43ef328c4e7760ae5633589d83ce2bcbef430258f8d8f53a40b1aa'

def index(source,audit,output):
    assert not output.exists()
    report=json.loads(audit.read_text())
    assert report['sourceAudited'] is True and report['cases']==574
    assert report['raw']==dict(bytes=RAW_BYTES,sha256=RAW_SHA)
    for key,value in dict(wholeReturns=573,warReturns=571,preparationBoundaries=1,readyConsumerBindings=16,constructorReturns=802,warBitmapAllocations=4).items():
        assert report['counts'][key]==value,(key,report['counts'].get(key))
    metadata,case_hashes,pin=stream_document(source)
    assert pin==report['raw'] and len(case_hashes)==574
    manifest=json.loads((source.parent/'lib-war-manifest3.json').read_text())
    assert len(manifest)==574
    rows=[]
    for number,(digest,spec) in enumerate(zip(case_hashes,manifest)):
        part=source.with_suffix('.parts')/f'{number:04d}.json'
        raw=part.read_bytes();document=json.loads(raw)
        assert sha(canonical(document['case']))==digest
        assert document['case']['spec']==spec
        assert document['installation']==metadata['installations'][number]
        for key,value in document['blobs'].items():assert metadata['blobs'][key]==value
        for key,value in document['assets'].items():assert metadata['assets'][key]==value
        rows.append(dict(index=number,label=spec['label'],path=os.path.relpath(part,output.parent),bytes=len(raw),sha256=sha(raw)))
    # Every blob remains in the exact atomic part that already owns it. Shared
    # catalog/address metadata is supplied once, with no projected expectations.
    shared={k:v for k,v in metadata.items() if k not in ('blobs','installations','assets','parents')}
    document=dict(schema=1,scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        source=dict(path=str(source.resolve()),**pin),audit=dict(path=str(audit.resolve()),sha256=sha(audit.read_bytes())),
        metadata=shared,cases=rows,nativeCompared=False)
    with output.open('x') as f:json.dump(document,f,indent=2);f.write('\n')
    return dict(cases=len(rows),bytes=output.stat().st_size,sha256=sha(output.read_bytes()),sourceUnchanged=True,nativeCompared=False)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('source',type=Path);p.add_argument('--audit',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();print(index(a.source,a.audit,a.output))
