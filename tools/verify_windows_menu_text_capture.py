#!/usr/bin/env python3
"""Verify structural/provenance integrity of controlled DirectDraw text capture."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
from build_windows_menu_text_probe import INPUT_SHA


def bits(x):
    assert isinstance(x,int) and not isinstance(x,bool) and 0 <= x <= 0xffffffff
    return x


def result(record,key):
    r=record[key];bits(r['lastErrorAfter']);return bits(r['resultBits'])


def rawhex(value,n=None):
    assert isinstance(value,str)
    b=bytes.fromhex(value)
    assert len(value)==len(b)*2 and (n is None or len(b)==n)
    return b


def snapshot(s):
    assert s['lockFlags']==17
    before=rawhex(s['descriptorBefore'],108);assert before==struct.pack('<I',108)+b'\xa5'*104
    desc=struct.unpack('<27I',rawhex(s['descriptorAfter'],108))
    if result(s,'lock')!=0:
        assert s['storageAccepted'] is False and 'pixelsTopLeft' not in s and 'unlock' not in s
        return dict(outcome='lock-failed')
    result(s,'unlock')
    pitch=struct.unpack('<i',struct.pack('<I',desc[4]))[0];bpp=desc[21]
    fmt=bool(desc[19]&0x40) and not bool(desc[19]&4) and bpp in (8,16,24,32)
    row=(794*bpp+7)//8 if fmt else 0
    valid=desc[0]==108 and desc[1]&0x180e==0x180e and desc[2:4]==(550,794) and desc[18]==32 and fmt and desc[9]!=0 and -32768<=pitch<=32768 and abs(pitch)>=row
    assert s['storageAccepted']==valid
    if not valid:
        assert 'pixelsTopLeft' not in s
        return dict(outcome='collector-descriptor-boundary',unlockResult=result(s,'unlock'))
    assert s['rowBytes']==row and s['rows']==550
    pixels=rawhex(s['pixelsTopLeft'],row*550)
    return dict(outcome='owned-pixels-observed',unlockResult=result(s,'unlock'),rowBytes=row,
                pitch=pitch,bpp=bpp,pixelFormat=list(desc[18:26]),pixelsSHA256=hashlib.sha256(pixels).hexdigest(),bytes=len(pixels))


def verify_raw(x,lines):
    assert x['schema']=='ntsd-windows-menu-text-v1' and x['complete'] is True
    assert x['gameExecuted'] is False and x['fullMenu'] is False and x['snapshotsAreWriteMasks'] is False
    env=x['environment'];assert env['compiledMachine']==332 and env['pointerBits']==32
    for name in ('acp','oemcp'):bits(env[name])
    assert [v['name'] for v in env['modules']]==['kernel32.dll','user32.dll','gdi32.dll','ddraw.dll']
    for module in env['modules']:
        count=bits(module['pathCharacters']);rawhex(module['pathUTF16LE'],min(count,1024)*2)
        assert module['loaded'] in (0,1)
    # Complete branch records are required even when there are no text samples.
    # This validates the collector's control flow, not Windows success/equivalence.
    can_draw=False
    if not x['functionsReady']:
        assert 'registerClass' not in x
    else:
        registered=result(x,'registerClass')!=0
        if registered:
            assert 'unregisterClass' in x
            window=bits(x['window']);bits(x['createWindowError'])
            if window:
                result(x,'destroyWindow')
                created=result(x,'directDrawCreate')==0 and bits(x['draw'])!=0
                if created:
                    result(x,'releaseDraw')
                    cooperative=result(x,'setCooperativeLevel')&0x80000000==0
                    if cooperative:
                        primary=list(struct.unpack('<27I',rawhex(x['primaryDescriptor'],108)))
                        expected=[0]*27;expected[0]=108;expected[1]=1;expected[26]=0x200
                        assert primary==expected
                        primary_owned=result(x,'createPrimary')==0 and bits(x['primary'])!=0
                        if primary_owned:
                            result(x,'releasePrimary')
                            back=struct.unpack('<27I',rawhex(x['backDescriptor'],108))
                            assert back[:4]==(108,7,550,794) and back[26]==0x40
                            back_owned=result(x,'createBack')==0 and bits(x['back'])!=0
                            if back_owned:
                                result(x,'releaseBack')
                                assert rawhex(x['pixelFormatBefore'],32)==struct.pack('<I',32)+b'\xa5'*28
                                rawhex(x['pixelFormatAfter'],32);result(x,'getPixelFormat')
                                fx=list(struct.unpack('<25I',rawhex(x['fillEffects'],100)))
                                expected=[0]*25;expected[0]=100;expected[20]=0x10206c;assert fx==expected
                                can_draw=result(x,'fill')==0
                            else:assert 'releaseBack' not in x and 'fill' not in x
                        else:assert 'releasePrimary' not in x and 'createBack' not in x
                    else:assert 'createPrimary' not in x
                else:assert 'setCooperativeLevel' not in x and 'releaseDraw' not in x
            else:assert 'directDrawCreate' not in x
        else:assert 'window' not in x and 'unregisterClass' not in x
    if can_draw:assert 'beforeText' in x
    else:assert 'beforeText' not in x and 'afterText' not in x and 'lines' not in x
    observations=[]
    for i,row in enumerate(x.get('lines',[])):
        assert i<3 and row['index']==i
        expected=lines[i];assert [row['x'],row['y'],row['length']]==expected['arguments'][1:]
        assert rawhex(row['bytes'])==bytes(expected['strings'][0])
        acquired=result(row,'getDC');bits(row['dc'])
        if acquired&0x80000000:
            assert 'textOut' not in row and 'releaseDC' not in row
            observations.append(dict(index=i,outcome='getdc-failed'));continue
        if not row['dc']:
            assert row['boundary']=='nonnegative-getdc-with-null-handle' and 'textOut' not in row
            observations.append(dict(index=i,outcome='null-dc-boundary'));assert i==len(x['lines'])-1;continue
        font=bits(row['selectedFont']);bits(row['selectedFontError'])
        if font:
            assert rawhex(row['logFontBefore'],92)==b'\xa5'*92
            rawhex(row['logFontAfter'],92);result(row,'getObject')
        assert rawhex(row['textMetricBefore'],60)==b'\xa5'*60
        rawhex(row['textMetricAfter'],60);result(row,'getTextMetrics')
        face=rawhex(row['textFaceUTF16LE'],512);n=result(row,'getTextFace');name=None
        if 0<n<=256:
            used=face[:n*2];name=used.decode('utf-16le',errors='replace').rstrip('\x00')
        for key in ('charset','textAlign','mapMode','bkMode','textColor','bkColor'):result(row,key)
        for key in ('viewportOrg','windowOrg','viewportExt','windowExt'):
            assert rawhex(row[key]['before'],8)==b'\xa5'*8;rawhex(row[key]['after'],8);result(row[key],'query')
        assert [v['index'] for v in row['deviceCaps']]==[2,8,10,12,14,38,88,90,104,117,118]
        for v in row['deviceCaps']:result(v,'query')
        assert rawhex(row['extentBefore'],8)==b'\xa5'*8;rawhex(row['extentAfter'],8)
        for key in ('getTextExtent','setBkMode','setTextColor','textOut','releaseDC'):result(row,key)
        if result(row,'releaseDC')!=0:assert i==len(x['lines'])-1 and 'afterText' not in x
        observations.append(dict(index=i,outcome='text-request-observed',fontFace=name,
            textOutResult=result(row,'textOut'),releaseDCResult=result(row,'releaseDC')))
    snapshots={name:snapshot(x[name]) for name in ('beforeText','afterText') if name in x}
    if 'beforeText' in snapshots and snapshots['beforeText'].get('unlockResult',0)!=0:assert not observations and 'afterText' not in x
    if 'beforeText' in snapshots and snapshots['beforeText'].get('unlockResult',0)==0:
        assert observations
        last=x['lines'][-1]
        stopped=(result(last,'getDC')<0x80000000 and (last['dc']==0 or result(last,'releaseDC')!=0))
        if not stopped:assert len(observations)==3 and 'afterText' in x
    changed=None
    if len(snapshots)==2 and all(s['outcome']=='owned-pixels-observed' for s in snapshots.values()):
        a,b=snapshots['beforeText'],snapshots['afterText']
        if a['rowBytes']==b['rowBytes'] and a['pixelFormat']==b['pixelFormat']:
            changed=sum(c!=d for c,d in zip(rawhex(x['beforeText']['pixelsTopLeft']),rawhex(x['afterText']['pixelsTopLeft'])))
    return dict(structuralVerificationOnly=True,compatibilityAccepted=False,fullMenu=False,
                snapshots=snapshots,lines=observations,changedPixelStorageBytes=changed,
                initializationGuaranteed=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('capture',type=Path)
    p.add_argument('--manifest-sha256',required=True);p.add_argument('--kit',required=True,type=Path)
    a=p.parse_args();manifest=(a.kit/'manifest.json').read_bytes()
    assert hashlib.sha256(manifest).hexdigest()==a.manifest_sha256
    assert (a.capture/'manifest.json').read_bytes()==manifest
    m=json.loads(manifest);assert m['schema']=='ntsd-windows-menu-text-build-v1'
    for name,pin in m['files'].items():
        assert Path(name).name==name and '/' not in name and '\\' not in name
        b=(a.kit/name).read_bytes();assert len(b)==pin['bytes'] and hashlib.sha256(b).hexdigest()==pin['sha256']
    source=(a.kit/'first-menu1.json').read_bytes();assert hashlib.sha256(source).hexdigest()==INPUT_SHA
    lines=[v['command']['event'] for v in json.loads(source)['front'] if v['command']['event']['kind']=='textOut']
    run=json.loads((a.capture/'run.json').read_text(encoding='utf-8-sig'))
    assert run['schema']=='ntsd-windows-menu-text-run-v1' and run['complete'] is True and run['failure'] is None
    assert run['manifestSHA256']==a.manifest_sha256 and run['gameExecuted'] is False
    assert run['environmentDescription'].strip() and run['windowsRegistry']
    assert len(run['captures'])==1;c=run['captures'][0]
    assert c['architecture']=='x86' and c['terminal'] and not c['timedOut'] and c['exitCode']==0
    assert c['processId']>0 and c['processStartUTC'] and c['executable'] and c['launchWorkingDirectory']
    data=(a.capture/'x86/menu-text.json').read_bytes()
    assert len(data)==c['bytes'] and hashlib.sha256(data).hexdigest()==c['sha256']
    print(json.dumps(verify_raw(json.loads(data),lines),indent=2))


if __name__=='__main__':main()
