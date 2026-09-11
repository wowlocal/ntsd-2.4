#!/usr/bin/env python3
"""Index the separately bound22-call War preparation source and full audit.
Pinned original NTSD EXE/lib/VC80 controlled Unicorn2.1.4/CW023f observations.
Exact atomic part hashes retain every original byte/mask; metadata supplies
explicit test inputs, not after-state. No source execution, own startup,
Windows/device or Native-equivalence claim. Preserve all older corpora.
"""
import argparse,datetime,hashlib,json,os
from pathlib import Path
from verify_lib_war_setup import stream_document,canonical,sha

PROFILES={'preparation':dict(cases=22,bytes=192093188,sha256='e3abb5dec759c28103c5a746972d7fb1469e7fa7b8ca151a09fc952e6d5621f6',manifest='war-preparation-bound-manifest1.json',fixture='original-lib-war-preparation-bound',counts=dict(wholeReturns=22,warReturns=20,wholePreparations=2,readyConsumerBindings=16,constructorReturns=802,warBitmapAllocations=4,source2ParentReproductions=4))}

def index(source,audit,output,profile='preparation'):
    assert not output.exists()
    expected=PROFILES[profile]
    report=json.loads(audit.read_text())
    assert report['sourceAudited'] is True and report['cases']==expected['cases']
    assert report['raw']=={k:expected[k] for k in ('bytes','sha256')}
    for key,value in expected['counts'].items():
        assert report['counts'].get(key,0)==value,(key,report['counts'].get(key))
    assert report['coverage']['complete'] is True and report['coverage']['recordingInputsBound'] is True
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
    p.add_argument('--profile',choices=PROFILES,default='preparation')
    a=p.parse_args();print(index(a.source,a.audit,a.output,a.profile))
