#!/usr/bin/env python3
"""Index, losslessly package or independently verify the War success matrix.
Read completed pinned NTSD EXE/lib/VC80/resources, controlled Unicorn2.1.4/CW023f
observations and full source audit. Preserve every original byte/mask/metadata,
atomic part and blob; fixture deflation is research transport, not game replay
compression. Reuse the accepted preflight transport algorithm with an explicit
new immutable profile. No source execution, fault continuation, Native/device/
Windows/private ABI or full-preparation/full-game acceptance claim.
"""
import argparse,json
from pathlib import Path
import index_lib_war_preparation as indexing
import package_lib_war_preparation as packing
import verify_lib_war_preparation_transport as transport

# Filled only from the terminal capture and independently checked full audit.
RAW_BYTES=2866445440
RAW_SHA256='79b14f3aaa971e5ef1d60eac6d72955c1f9c924fcc2c2948caa74de67d24495a'
PROFILE=dict(cases=256,bytes=RAW_BYTES,sha256=RAW_SHA256,
 manifest='war-preparation-matrix-manifest2.json',fixture='original-lib-war-preparation-matrix',
 counts=dict(wholeReturns=256,warReturns=236,wholePreparations=56,
 readyConsumerBindings=160,constructorReturns=8020,warBitmapAllocations=40,
 source2ParentReproductions=40,capture1CallsReproduced=25,capture2RetainedCalls=234,capture2PrefixReproduced=10,numericPoints=680,
 releasePairs=302,arenaBitmapAllocations=619,recordingReplacements=36,initialRecordingFrees=20))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('operation',choices=['index','package','verify'])
 p.add_argument('--source',type=Path,required=True);p.add_argument('--audit',type=Path)
 p.add_argument('--index',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 assert RAW_BYTES>0 and len(RAW_SHA256)==64
 indexing.PROFILES['matrix']=PROFILE;transport.PINS[RAW_SHA256]=(RAW_BYTES,256)
 indexing.__doc__=packing.__doc__=transport.__doc__=__doc__
 if a.operation=='index':
  assert a.audit is not None;result=indexing.index(a.source,a.audit,a.output,'matrix')
 elif a.operation=='package':
  assert a.audit is not None and a.index is not None;result=packing.package(a.source,a.audit,a.index,a.output,'matrix')
 else:
  assert a.index is not None and not a.output.exists();result=transport.verify(a.index,a.source)
  a.output.write_text(json.dumps(result,indent=2)+'\n')
 print(result)

if __name__=='__main__':main()
