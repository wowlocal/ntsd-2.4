"""Read saved color observations; never execute a probe or change acceptance data."""
import json, sys
from pathlib import Path
from archive_catalog53_storage import checked

def check(task):
    report=json.loads((task/'verification1.json').read_text())
    checked(Path(report['result']['path']),report['result'])
    data=json.loads((task/'result2.json').read_text())
    colors=[0,1,0xff,0xff0000,0xff00,0x123456,0xffabcdef,0x336699]
    expected={(p,d,c) for p in ['default','sRGB','screen'] for d in [False,True] for c in colors}
    cases=data['cases'];direct=data['directImages']
    assert len(cases)==48 and len(direct)==8
    index={(v['policy'],v['directCGContext'],v['color']):v for v in cases}
    assert set(index)==expected and {v['color'] for v in direct}==set(colors)
    for v in direct:
        rgb=[(v['color']>>shift)&255 for shift in [16,8,0]]
        assert v['bitmap']['space']['cgName']=='kCGColorSpaceSRGB'
        assert len(v['bitmap']['samples'])==3
        assert all(s['raw']==rgb for s in v['bitmap']['samples'])
    for p in ['default','sRGB','screen']:
        for c in colors:
            a=index[p,False,c]['bitmap'];b=index[p,True,c]['bitmap']
            assert a==b and len(a['samples'])==3
    for d in [False,True]:
        for c in colors:
            assert index['default',d,c]['bitmap']==index['screen',d,c]['bitmap']
            v=index['sRGB',d,c]['bitmap'];rgb=[(c>>shift)&255 for shift in [16,8,0]]
            assert v['space']['cgName']=='kCGColorSpaceSRGB'
            assert all(s['raw']==rgb+[255] for s in v['samples'])
    assert all(s['colorSpace']['cgName']=='kCGColorSpaceGenericRGB' for v in cases+direct for s in v['bitmap']['samples'])
    parent=task.parent/'application-mac-display-correction1-20260926'
    failure=json.loads((parent/'failure-diagnosis1.json').read_text())
    assert all(s['sRGB'][:3]==failure['actualRGB'] for s in index['default',False,0x336699]['bitmap']['samples'])
    return dict(cases=48,directImages=8,drawPairs=24,profilePairs=16,failedTripletExact=True,productionAccepted=False,independentReview=False)

if __name__=='__main__': print(json.dumps(check(Path(sys.argv[1]).resolve())))
