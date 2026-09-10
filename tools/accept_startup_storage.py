#!/usr/bin/env python3
"""Pack unchanged constructor results and separately incomplete CRT traces.

Requires terminal native raw comparison and independent source verification.
No partial CRT capture is reclassified as a successful/native startup. Embedded
raw JSON preserves every original byte, including newlines, of both CRT captures.
"""
import base64,hashlib,json,re,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
def pack(raw):
    payload=raw[:-1];assert raw.endswith(b'\n');c=zlib.compressobj(9,zlib.DEFLATED,-15)
    return (json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(c.compress(payload)+c.flush()).decode()),separators=(',',':'))+'\n').encode()
def main():
    bp=ROOT/'build/research';wp=bp/'startup-storage-work.json';w=json.loads(wp.read_bytes());v=json.loads((bp/'startup-storage-source-verification.json').read_bytes())
    assert w['sourceExitCode']==w['rawExitCode']==0 and w['rawStatus']=='terminal'
    assert digest((ROOT/'tools/oracle_startup_storage.py').read_bytes())==w['sourceToolSHA256']
    exported=Path(w['isolatedPackage']).parent;pins=json.loads((bp/'startup-storage-export-pins.json').read_bytes())
    for n,h in pins.items():assert digest((exported/n).read_bytes())==h,n
    for n in w['ownedNativeFiles']:assert digest((ROOT/n).read_bytes())==pins[n],n
    log=(bp/'startup-storage-native-raw.log').read_text();assert 'Executed 3 tests, with 0 failures' in log and 'STARTUP STORAGE 12 controlled table calls 36 constructors 4992 written bytes' in log
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((bp/'startup-storage-prior-pins.json').read_bytes())
    for n,h in prior.items():assert digest((fixtures/n).read_bytes())==h,n
    raw=(ROOT/'build/original/startup-storage.json').read_bytes();assert digest(raw)==w['sourceSHA256']==v['rawSHA256']
    summary={**v,'nativeCompared':True,'corpus':'startup-storage.json','fixture':'original-startup-storage.json'}
    captures=[]
    for name,key in [('crt-startup-probe11.json','incompleteCRT'),('crt-startup-probe4.json','rejectedCRT')]:
        b=(bp/name).read_bytes();assert digest(b)==v[key]['rawSHA256'];captures.append(dict(name=name,sha256=digest(b),count=len(b),rawJSON=b.decode()))
    prefix_raw=(json.dumps(dict(scope='Incomplete CRT process attach and separate missing-KERNEL32 rejection; no native or Windows success',captures=captures,nativeCompared=False,windowsVerified=False),sort_keys=True,separators=(',',':'))+'\n').encode()
    prefix_path=ROOT/'build/original/crt-startup-prefix.json'
    if prefix_path.exists():assert prefix_path.read_bytes()==prefix_raw
    else:prefix_path.write_bytes(prefix_raw)
    prefix_summary=dict(corpus=prefix_path.name,fixture='original-crt-startup-prefix.json',nativeCompared=False,windowsVerified=False,fullCRTStartupCompared=False,incompleteCRT=v['incompleteCRT'],rejectedCRT=v['rejectedCRT'])
    for data,report,name in [(raw,summary,'startup-storage'),(prefix_raw,prefix_summary,'crt-startup-prefix')]:
        packed=pack(data);p=fixtures/report['fixture']
        if p.exists():assert p.read_bytes()==packed
        else:p.write_bytes(packed)
        report.update(rawSHA256=digest(data),rawBytes=len(data),fixtureBytes=len(packed),fixtureSHA256=digest(packed))
        (ROOT/'docs/evidence'/f'{name}.json').write_text(json.dumps(report,indent=2)+'\n')
    w.update(status='raw-accepted-packaged-pending',rawTests=3,rawTestSeconds=float(re.findall(r'Executed 3 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',log)[-1]),rawBuildSeconds=float(re.search(r'Build complete! \(([0-9.]+)s\)',log)[1]),rawLogSHA256=digest(log.encode()),rawSession=36375,verifierSession=54058,verifierExitCode=0,nativeCompared=True,fullCRTStartupCompared=False)
    current={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')};w['currentFixtures']=len(current)
    (bp/'startup-storage-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');wp.write_text(json.dumps(w,indent=2)+'\n');print(json.dumps(w,indent=2))
if __name__=='__main__':main()
