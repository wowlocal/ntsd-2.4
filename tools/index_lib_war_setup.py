#!/usr/bin/env python3
"""Index the preserved574/192/40 War corpora for bounded-memory Native comparison.
Reads only the completed pinned NTSD EXE/lib/VC80 Unicorn2.1.4 corpus and its
successful full read/store/REP/ownership audits. The supplements cover all44
cells and14 multi-human action masks with independently reproduced parents.
No EXE execution, recapture,
expected-byte edits, Windows/device or Native-equivalence claim. Keep the
original raw document and every atomic part immutable. The index holds input
metadata and exact part hashes; it does not import an after-state into Native.
"""
import argparse,datetime,hashlib,json,os
from pathlib import Path
from verify_lib_war_setup import stream_document,canonical,sha

RAW_BYTES=3456631996
RAW_SHA='9b7e923c7f43ef328c4e7760ae5633589d83ce2bcbef430258f8d8f53a40b1aa'
PROFILES={
    'setup':dict(cases=574,bytes=RAW_BYTES,sha256=RAW_SHA,manifest='lib-war-manifest3.json',fixture='original-lib-war-setup',counts=dict(wholeReturns=573,warReturns=571,preparationBoundaries=1,readyConsumerBindings=16,constructorReturns=802,warBitmapAllocations=4)),
    'cells':dict(cases=192,bytes=1138424571,sha256='d2f17f5a4b32cc950227de4c1061430d34242fb7b6a883c79a43d02a38547f57',manifest='lib-war-cells-manifest1.json',fixture='original-lib-war-cells',counts=dict(wholeReturns=192,warReturns=191,preparationBoundaries=0,readyConsumerBindings=8,constructorReturns=401,warBitmapAllocations=2,source2ParentReproductions=2,declaredCellEdits=44)),
    'multiaction':dict(cases=40,bytes=247848404,sha256='fba1f47a4f7770405cd139fbc2ee2bfbd86f0c059f0658e29d56c2fe8bd8f36c',manifest='lib-war-multiaction-manifest1.json',fixture='original-lib-war-multiaction',counts=dict(wholeReturns=40,warReturns=39,preparationBoundaries=0,readyConsumerBindings=8,constructorReturns=401,warBitmapAllocations=2,source2ParentReproductions=2,declaredActionCombinations=14)),
}

def index(source,audit,output,profile='setup'):
    assert not output.exists()
    expected=PROFILES[profile]
    report=json.loads(audit.read_text())
    assert report['sourceAudited'] is True and report['cases']==expected['cases']
    assert report['raw']=={k:expected[k] for k in ('bytes','sha256')}
    for key,value in expected['counts'].items():
        assert report['counts'].get(key,0)==value,(key,report['counts'].get(key))
    if profile!='setup':assert report['coverage']['complete'] is True and not report['coverage']['missingEditableCells']
    metadata,case_hashes,pin=stream_document(source)
    assert pin==report['raw'] and len(case_hashes)==expected['cases']
    manifest=json.loads((source.parent/expected['manifest']).read_text())
    assert len(manifest)==expected['cases']
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
    document=dict(schema=1,scope=__doc__,profile=profile,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        source=dict(path=str(source.resolve()),**pin),audit=dict(path=str(audit.resolve()),sha256=sha(audit.read_bytes())),
        metadata=shared,cases=rows,coverage=report.get('coverage'),finiteAcceptanceComplete=report.get('finiteAcceptanceComplete',False),nativeCompared=False)
    with output.open('x') as f:json.dump(document,f,indent=2);f.write('\n')
    return dict(cases=len(rows),bytes=output.stat().st_size,sha256=sha(output.read_bytes()),sourceUnchanged=True,finiteAcceptanceComplete=document['finiteAcceptanceComplete'],nativeCompared=False)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('source',type=Path);p.add_argument('--audit',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--profile',choices=PROFILES,default='setup')
    a=p.parse_args();print(index(a.source,a.audit,a.output,a.profile))
