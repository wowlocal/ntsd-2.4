"""Verify saved finite capture controls; never run Native or rewrite expectations."""
import json, math, sys
from pathlib import Path

COLORS=[0,1,0xff,0xff0000,0xff00,0x123456,0xffabcdef,0x336699,
        0x808080,0xffffff,0x010203,0xfedcba,0x7f00ff,0x32cd71,0x97412e,0x4da870]

def check(task):
    d=json.loads((task/'result1.json').read_text());tolerance=2/255
    assert d['colors']==COLORS and d['tolerance']==tolerance and d['failures']==[]
    expected={f'{p}-{i}' for p in ['direct','default','sRGB','screen'] for i in [0,1]}
    assert len(d['records'])==8 and {r['label'] for r in d['records']}==expected
    maximum=0
    def compare(a,b):
        nonlocal maximum
        assert len(a)==len(b)==4 and all(math.isfinite(v) for v in a+b)
        delta=max(abs(x-y) for x,y in zip(a,b));maximum=max(maximum,delta)
        assert delta<=tolerance,(a,b,delta)
    for r in d['records']:
        colors=COLORS if r['label'].endswith('-0') else COLORS[::-1]
        assert len(r['samples'])==16
        for i,s in enumerate(r['samples']):
            assert [s['x'],s['y']]==[(2*(i%4)+1)*r['width']//8,(2*(i//4)+1)*r['height']//8]
            color=colors[i];expected=[((color>>shift)&255)/255 for shift in [16,8,0]]+[1]
            assert s['expected']==expected
            compare(s['actual'],expected);compare(s['profileAwareControl'],expected)
            compare(s['actual'],s['profileAwareControl'])
    raw=[[0,0,0,0],[32,16,8,64],[64,32,16,128],[255,128,64,255]]
    assert len(d['alpha'])==4
    for v,s in zip(raw,d['alpha']):
        expected=[0,0,0,0] if v[3]==0 else [x/v[3] for x in v[:3]]+[v[3]/255]
        assert s['expected']==expected;compare(s['actual'],expected)
    assert d['ownership']==[True,True] and d['bounds']==[True]*4
    assert d['missingRejected'] and d['budgetRejected'] and not d['productionAccepted']
    return dict(opaqueRecords=8,opaqueSamples=128,alphaSamples=4,bounds=4,ownership=2,
                missingImage=1,budgetRejection=1,maximumError=maximum,tolerance=tolerance,
                independentReview=False,productionAccepted=False)

if __name__=='__main__':print(json.dumps(check(Path(sys.argv[1]).resolve())))
