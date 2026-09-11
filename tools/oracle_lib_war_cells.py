#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""War44-cell coverage supplement:192 controlled original menu calls.
Pinned NTSD EXE/lib/VC80, original resources, Unicorn2.1.4/CW023f and declared
normal allocator/COM/GDI/music responses. Recover active/reserve editing through
separate Defense/Right edges after real41bc90/4229cc/438b40/ret1c/ret4 execution.
Reads/stores/stack/helper/ownership traces distinguish input priority from troop
updates. Preserve completed574-case source2 and reproduce only its two parent
calls as the necessary fresh provenance for this new sequence; never replace it.
No pointer corruption, fault continuation, Windows/device/played-battle claim.
See LIB_WAR_CELL_COVERAGE_PLAN.md; original execution remains research tooling.
"""
import argparse,copy,datetime,hashlib,json,os
from pathlib import Path
from oracle_lib_war_setup import WarSetup,specifications as prior_specifications
from oracle_lib_war_setup import tournament_inputs,arena_inputs,catalog_input,CATALOG_FILE,CATALOG_SHA
from oracle_lib_war_setup import ROOT,EXE_SHA256,DLL_SHA256,WORLD,BM,TARGET,LIB,STACK,SP,TAIL_SP

def specifications():
    out=copy.deepcopy(prior_specifications()[:2])
    def edge(label,button,**extra):
        out.append(dict(label=label+'-press',control=False,chain=True,buttons=[[0,button,1]],**extra))
        out.append(dict(label=label+'-release',control=False,chain=True,buttons=[[0,button,0]]))
    for i in range(2):edge('cell-grid-initial-down-'+str(i),0xce)
    for i in range(2):edge('cell-grid-initial-left-'+str(i),0xcf)
    for row in range(1,5):
        if row>1:edge('cell-grid-row-'+str(row),0xce)
        width=6 if row<=2 else 5
        for position in range(2*width):
            side=position//width;unit=position%width+(0 if row<=2 else 6)
            address=(0x44d5f8 if row%2 else 0x44d650)+(side*11+unit)*4
            label=f'cell-grid-{row}-{side}-{unit}'
            edge(label+'-edit',0xd3,expectedEdit=dict(row=row,side=side,unit=unit,address=address))
            edge(label+'-right',0xd0)
    assert len(out)==192
    assert {s['expectedEdit']['address'] for s in out if 'expectedEdit' in s}==set(range(0x44d5f8,0x44d6a8,4))
    return out

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--manifest-only',action='store_true');a=p.parse_args()
    assert not a.output.exists();specs=specifications()
    if a.manifest_only:
        a.output.write_text(json.dumps(specs,indent=2)+'\n');print('Finite calls',len(specs));return
    inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input()
    parts=a.output.with_suffix('.parts');parts.mkdir();blobs={};installations=[];assets={};parents=[];case_paths=[]
    vm=WarSetup(False,inputs,arenas,catalog);vm.capture_path=a.output
    parents.append(dict(firstCase=0,constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs))
    for number,s in enumerate(specs):
        c=vm.next_step(s) if s.get('chain') else vm.probe(s)
        assert c['end']=='returned'
        temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json')
        with temp.open('w') as f:
            json.dump(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,parents=parents),f,separators=(',',':'));f.write('\n')
        os.replace(temp,part);case_paths.append(part);installations.append(copy.deepcopy(vm.installation))
        if number<2:
            old=json.loads((ROOT/'build/research/lib-war/lib-war-capture2.parts'/f'{number:04d}.json').read_bytes())
            canonical=lambda x:json.dumps(x,separators=(',',':')).encode()
            assert canonical(c)==canonical(old['case']),(number,'source2 parent reproduction')
            assert canonical(parents)==canonical(old['parents'])
        if 'expectedEdit' in s:
            address=s['expectedEdit']['address']
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
