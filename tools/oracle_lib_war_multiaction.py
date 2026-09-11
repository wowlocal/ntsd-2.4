#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""War multi-seat action supplement:40 controlled original menu calls.
Pinned NTSD EXE/lib/VC80 and original resources under Unicorn2.1.4/CW023f.
Three declared human seats separately supply Attack/Jump/Defense; actual438bbb
flags and selected-cell stores establish all7 masks for active/reserve rows.
Whole41bc90/4229cc/438b40/ret1c/ret4 and ownership/read/store traces are retained.
Reproduce source2 control cases412/413 as fresh provenance; preserve completed
574- and192-call corpora. No flag injection, CPU key input, pointer corruption,
fault continuation, Windows/device or played battle claim. See
LIB_WAR_MULTI_ACTION_PLAN.md. Original execution is development tooling only.
"""
import argparse,base64,copy,datetime,hashlib,json,os,struct,zlib
from pathlib import Path
from oracle_lib_war_setup import WarSetup,specifications as prior_specifications
from oracle_lib_war_setup import tournament_inputs,arena_inputs,catalog_input,CATALOG_FILE,CATALOG_SHA
from oracle_lib_war_setup import ROOT,EXE_SHA256,DLL_SHA256,WORLD,BM,TARGET,LIB,STACK,SP,TAIL_SP

def specifications():
    out=copy.deepcopy(prior_specifications()[412:414])
    def edge(label,buttons,**extra):
        out.append(dict(label=label+'-press',control=True,chain=True,buttons=[[seat,key,1] for seat,key in buttons],**extra))
        out.append(dict(label=label+'-release',control=True,chain=True,buttons=[[seat,key,0] for seat,key in buttons]))
    for i in range(2):edge('multi-action-initial-down-'+str(i),[(0,0xce)])
    for i in range(2):edge('multi-action-initial-left-'+str(i),[(0,0xcf)])
    for row in (1,2):
        if row==2:edge('multi-action-reserve-row',[(0,0xce)])
        for mask in range(1,8):
            buttons=[(seat,key) for seat,key in [(0,0xd1),(1,0xd2),(2,0xd3)] if mask&(1<<seat)]
            edge(f'multi-action-{row}-{mask}',buttons,expectedActions=dict(row=row,mask=mask,address=0x44d5f8 if row==1 else 0x44d650))
    assert len(out)==40
    return out

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--manifest-only',action='store_true');a=p.parse_args()
    assert not a.output.exists();specs=specifications()
    if a.manifest_only:
        a.output.write_text(json.dumps(specs,indent=2)+'\n');print('Finite calls',len(specs));return
    inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input()
    parts=a.output.with_suffix('.parts');parts.mkdir();blobs={};installations=[];assets={};parents=[];case_paths=[]
    vm=WarSetup(True,inputs,arenas,catalog);vm.capture_path=a.output
    parents.append(dict(firstCase=0,constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs))
    for number,s in enumerate(specs):
        c=vm.next_step(s) if s.get('chain') else vm.probe(s)
        assert c['end']=='returned'
        temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json')
        with temp.open('w') as f:
            json.dump(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,parents=parents),f,separators=(',',':'));f.write('\n')
        os.replace(temp,part);case_paths.append(part);installations.append(copy.deepcopy(vm.installation))
        if number<2:
            old=json.loads((ROOT/'build/research/lib-war/lib-war-capture2.parts'/f'{number+412:04d}.json').read_bytes())
            canonical=lambda x:json.dumps(x,separators=(',',':')).encode()
            assert canonical(c)==canonical(old['case']),(number,'source2 parent reproduction')
            old_parents=copy.deepcopy(old['parents']);assert old_parents[0]['firstCase']==412;old_parents[0]['firstCase']=0
            assert canonical(parents)==canonical(old_parents)
        if 'expectedActions' in s:
            expected=s['expectedActions'];address=expected['address']
            point=next(p for p in c['points'] if p['kind']=='war-0x438bbb')
            key=next(r['storage']['bytes'] for r in point['records'] if r['address']==0x44d000)
            raw=zlib.decompress(base64.b64decode(vm.blobs[key]['deflate']),-15)
            mask=sum((struct.unpack_from('<i',raw,p-0x44d000)[0]!=0)<<i for i,p in enumerate((0x4513b4,0x4513b8,0x4513bc)))
            assert mask==expected['mask'],(number,s['label'],'actual input flags',mask)
            writes=[w for w in c['writes'] if w['pc'] in (0x43962b,0x439637,0x439647,0x439652,0x43965b,0x439663)]
            assert writes and {w['address'] for w in writes}=={address},(number,s['label'],'actual edited addresses',[hex(w['address']) for w in writes])
        for key,value in vm.blobs.items():assert key not in blobs or blobs[key]==value;blobs[key]=value
        for key,value in vm.graphics.assets.items():assert key not in assets or assets[key]==value;assets[key]=value
        print('completed',number,s['label'],c['end'],flush=True)
    d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,
        catalogDependency=dict(path=str(CATALOG_FILE.relative_to(ROOT)),sha256=CATALOG_SHA,bitmapAddresses=[b['address'] for b in catalog['bitmaps']],checksum=catalog['checksum']),
        parents=parents,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
    temp=a.output.with_suffix('.tmp')
    with temp.open('w') as f:
        f.write('{"cases":[')
        for i,part in enumerate(case_paths):
            if i:f.write(',')
            document=json.loads(part.read_bytes());json.dump(document['case'],f,separators=(',',':'))
        f.write(']')
        for key,value in d.items():f.write(','+json.dumps(key)+':');json.dump(value,f,separators=(',',':'))
        f.write('}\n')
    os.replace(temp,a.output);h=hashlib.sha256()
    with a.output.open('rb') as f:
        for raw in iter(lambda:f.read(8*1024*1024),b''):h.update(raw)
    print(dict(cases=len(case_paths),bytes=a.output.stat().st_size,sha256=h.hexdigest()),flush=True)

if __name__=='__main__':main()
