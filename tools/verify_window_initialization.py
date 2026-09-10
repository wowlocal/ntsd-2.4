#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Independently verify controlled window/DirectDraw startup evidence.

Reconstruct whole globals/masks and each structure from explicit helper-entry
backing, validate exact original instruction bytes and installer equality, and
separate unreachable signed-negative paths from executed coverage. Declared
Win32/COM inputs are not actual Windows/device observations. No source execution
or expected-byte alteration occurs. Full CRT/NLS and initialized app remain open.
"""
import argparse,base64,hashlib,json,struct,zlib
from collections import Counter
from pathlib import Path
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE

def digest(b):return hashlib.sha256(b).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',action='store_true');args=p.parse_args();bp=ROOT/'build/research'
    raw=(ROOT/'build/original/window-initialization.json').read_bytes();doc=json.loads(raw);r=json.loads((bp/'window-initialization.json').read_bytes())
    assert digest(raw)==r['sha256'] and len(raw)==r['bytes'] and len(doc['cases'])==280
    parent_raw=(ROOT/'build/original/lib-initialization.json').read_bytes();parent_report=json.loads((ROOT/'docs/evidence/lib-initialization.json').read_bytes());assert digest(parent_raw)==parent_report['sha256']
    assert doc['parent']==json.loads(parent_raw)['cases'][0]
    first50=json.loads((bp/'window-initialization-attempt1-50.json').read_bytes())['cases'];assert doc['cases'][:50]==first50
    retained=json.loads((ROOT/'build/original/window-initialization.incomplete.json').read_bytes());assert retained['incomplete'] and retained['cases']==doc['cases']
    pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());assert digest(pe.data)==EXE_SHA256==doc['exeSHA256'];cs=Cs(CS_ARCH_X86,CS_MODE_32)
    patched=bytearray(pe.data)
    for patch in doc['parent']['patches']:
        o=pe.offset(patch['address']-pe.base);assert patched[o:o+patch['count']].hex()==patch['before'];patched[o:o+patch['count']]=bytes.fromhex(patch['after'])
    pcs={};events=Counter();helpers=Counter();structures=Counter();writes=Counter();window_failures=0;full_modes_after_failure=0;ignored_pixel_errors=0;ignored_clip_errors=0
    for c in doc['cases']:
        before=bytes(c['before']);after=bytes(c['after']);assert len(before)==len(after)==0xb440
        rebuilt=bytearray(before);mask=bytearray(len(before))
        for w in c['writes']:
            data=bytes.fromhex(w['bytes']);o=w['address']-0x44d000;assert 0<=o<o+len(data)<=len(before)
            rebuilt[o:o+len(data)]=data;mask[o:o+len(data)]=b'\1'*len(data);writes[w['origin']]+=1
        assert bytes(rebuilt)==after and list(mask)==c['written']
        assert c['result']==1 and c['sp']==0x2000f004 and c['fpcw']==0x37f and not c['showReads']
        helpers.update(h['kind'] for h in c['helpers']);assert c['helpers'][-1]['kind']=='wrapper' and c['helpers'][-1]['eax']==1
        assert all(h['eax'] in (0,1) for h in c['helpers'] if h['kind'] in ('display','wrapper','fullConfigure','clearSetup'))
        for i in c['instructions']:
            a=i['address'];data=bytes.fromhex(i['bytes']);o=pe.offset(a-pe.base);assert patched[o:o+len(data)]==data
            decoded=list(cs.disasm(data,a));assert len(decoded)==1 and decoded[0].size==len(data);pcs[a]=i
        at=0;description=None;desc_mask=None;swap_count=0;icon=cursor=None;objects=[];counter=Counter();width=int.from_bytes(before[0x44d78c-0x44d000:0x44d790-0x44d000],'little')
        height=int.from_bytes(before[0x44d790-0x44d000:0x44d794-0x44d000],'little')
        def take(kind,n):
            nonlocal at
            b=c['backings'][at];at+=1;assert b['kind']==kind and len(b['bytes'])==n
            return bytearray(b['bytes']),bytearray(n)
        def put(buffer,defined,offset,value):struct.pack_into('<I',buffer,offset,value&0xffffffff);defined[offset:offset+4]=b'\1'*4
        for e in c['events']:
            q=e['request'];kind=q['kind'];counter[kind]+=1;assert e['key']==kind+'#'+str(counter[kind]);events[kind]+=1;value=e['response']['result']
            for string in q['strings']:assert bytes(string)+b'\0' in pe.data
            if kind=='icon':icon=value&0xffffffff
            if kind=='cursor':cursor=value&0xffffffff
            if kind=='registerClass':
                data,defined=take('windowClass',40);full=c['spec'].get('mode',0)!=0
                values={0:3,4:0x43b3d0,8:0,12:0,16:c['spec'].get('instance',0x400000),20:icon,28:0,32:0x447634,36:0x447634}
                if not full:values[24]=cursor
                for o,v in values.items():put(data,defined,o,v)
            elif kind=='createSurface':
                if e['returnPC']==0x4010e0:
                    data,defined=take('surfaceDescription',108);swap_count+=1
                    for o,v in {0:108,4:0x21,8:height,12:width,20:2 if swap_count==1 else 1,104:0x4218}.items():put(data,defined,o,v)
                elif e['returnPC']==0x401148:
                    description,desc_mask=take('surfaceDescription',108)
                    for o,v in {0:108,4:1,104:0x200}.items():put(description,desc_mask,o,v)
                    data,defined=description,desc_mask
                else:
                    assert e['returnPC']==0x40119f and description is not None
                    for o,v in {4:7,8:height,12:width,104:0x40}.items():put(description,desc_mask,o,v)
                    data,defined=description,desc_mask
            elif kind=='pixelFormat':data,defined=take('pixelFormat',32);put(data,defined,0,32);ignored_pixel_errors+=value<0
            elif kind=='blt':
                data,defined=take('fillEffects',100);put(data,defined,0,100);put(data,defined,80,0);assert q['words'][1:]==[0,0,0,0x1000400]
            if 'bytes' in q:
                assert list(data)==q['bytes'] and [bool(b) for b in defined]==q['defined'],(c['index'],e['key']);structures[kind]+=1
            if 'output' in e['response']:
                output=e['response']['output'];assert value>=0 and output!=0 and not any(o['address']==output for o in objects)
                family='draw' if kind=='directDrawCreate' else 'clipper' if kind=='createClipper' else 'surface';objects.append(dict(address=output,family=family,releases=[]))
            if kind=='release':next(o for o in objects if o['address']==q['words'][0])['releases'].append(dict(key=e['key'],result=value&0xffffffff))
            if kind=='setClipper':ignored_clip_errors+=value<0
        assert at==len(c['backings']) and objects==c['objects']
        shows=[e for e in c['events'] if e['request']['kind']=='showWindow'];assert shows and all(e['request']['words'][1]==5 for e in shows)
        create=next(e for e in c['events'] if e['request']['kind']=='createWindow')
        if create['response']['result']==0:
            window_failures+=1;assert shows[-1]['request']['words']==[0,5] and not any(e['request']['kind']=='directDrawCreate' for e in c['events'])
        if c['spec'].get('mode',0)!=0 and any(h['kind']=='fullConfigure' and h['eax']==0 for h in c['helpers']):
            full_modes_after_failure+=1;assert int.from_bytes(after[0xb348:0xb34c],'little')==2
    ranges=[(0x43bdd0,0x43beba),(0x43bec0,0x43bf03),(0x401000,0x40108e),(0x401090,0x40110b),(0x401110,0x4011cb),(0x4011d0,0x401246),(0x401250,0x401282),(0x401300,0x4013cf),(0x401b00,0x401be9),(0x401bf0,0x401c86),(0x43e8e0,0x43e935),(0x43f37e,0x43f384)]
    static={}
    for a,b in ranges:
        o=pe.offset(a-pe.base)
        for i in cs.disasm(patched[o:o+b-a],a):static[i.address]=dict(address=i.address,bytes=bytes(i.bytes).hex(),instruction=i.mnemonic+' '+i.op_str)
    missing=[static[a] for a in sorted(set(static)-set(pcs))];assert set(pcs)<=set(static)
    assert all(0x43bed2<=i['address']<0x43beee or 0x40137f<=i['address']<0x4013c6 for i in missing)
    result=dict(rawSHA256=digest(raw),rawBytes=len(raw),cases=len(doc['cases']),globalBytes=len(doc['cases'])*0xb440,events=dict(events),eventCount=sum(events.values()),helpers=dict(helpers),helperCount=sum(helpers.values()),structures=dict(structures),structureCount=sum(structures.values()),writes=dict(writes),actualEXEPCs=len(pcs),actualDLLPCs=0,staticStarts=len(static),unexecutedStatic=missing,windowFailureStillReturnsOne=window_failures,fullConfigureZeroStillSelectsModeTwo=full_modes_after_failure,ignoredPixelErrors=ignored_pixel_errors,ignoredSetClipperErrors=ignored_clip_errors,retained50Unchanged=True,final280CheckpointEqual=True,wholeInstallerEqual=True,windowsVerified=False,fullCRTStartupCompared=False)
    result['structureBytes']=sum(len(e['request'].get('bytes',[])) for c in doc['cases'] for e in c['events'])
    result['structureWrittenFieldBytes']=sum(sum(e['request'].get('defined',[])) for c in doc['cases'] for e in c['events'])
    result['fullscreenUnknownCursorCalls']=helpers['fullscreen']
    (bp/'window-initialization-source-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    if args.artifacts:
        report=json.loads((ROOT/'docs/evidence/window-initialization.json').read_bytes());fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
        packed=(fixtures/report['fixture']).read_bytes();envelope=json.loads(packed);decoded=zlib.decompress(base64.b64decode(envelope['deflate']),-15)
        assert digest(packed)==report['fixtureSHA256'] and len(packed)==report['fixtureBytes']
        assert decoded+b'\n'==raw and len(decoded)==envelope['count'] and digest(decoded)==envelope['sha256'] and json.loads(decoded)==doc
        prior=json.loads((bp/'window-initialization-prior-pins.json').read_bytes());pins=json.loads((bp/'window-initialization-fixture-pins.json').read_bytes())
        assert all(pins[n]==h for n,h in prior.items())
        for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
        meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
        for n,entry in vendor.items():assert digest((meta.parent/'vendor'/n).read_bytes())==entry['vendoredSHA256'],n
        work=json.loads((bp/'window-initialization-work.json').read_bytes());dest=Path(work['isolatedPackage']).parent;export=json.loads((bp/'window-initialization-final-export-pins.json').read_bytes())
        for n,h in export.items():assert digest((dest/n).read_bytes())==h,n
        for n in work['ownedNativeFiles']:assert digest((ROOT/n).read_bytes())==export[n],n
        artifact=dict(rawBytes=len(raw),packedBytes=len(packed),rawSHA256=digest(raw),packedSHA256=digest(packed),fullJSONEqual=True,retained50Unchanged=True,final280CheckpointEqual=True,priorUnchanged=len(prior),currentFixtures=len(pins),vendorFiles=len(vendor),exportFiles=len(export),windowsVerified=False,fullCRTStartupCompared=False)
        (bp/'window-initialization-artifact-verification.json').write_text(json.dumps(artifact,indent=2)+'\n');result['artifactVerification']=artifact
    print(json.dumps({k:v for k,v in result.items() if k!='unexecutedStatic'},indent=2))
if __name__=='__main__':main()
