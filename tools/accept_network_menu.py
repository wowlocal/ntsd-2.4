#!/usr/bin/env python3
"""Publish lossless network-menu fixtures after completed raw native acceptance.

Source EXE/lib/CRT bytes and private stack observations stay immutable. Three
partial-receive own rejections remain separate from successful UI comparisons.
This publishes repository research fixtures, not a game app or network service.
"""
import base64,hashlib,json,re,zlib,sys
from pathlib import Path
from import_ntsd import ROOT
from verify_network_menu import audit
H=lambda b:hashlib.sha256(b).hexdigest()
INPUTS=[('', 'primary-candidate2'),('-control','control-candidate2'),('-partial-greeting','partial-greeting-candidate1'),('-partial-flags','partial-flags-candidate1'),('-partial-names','partial-names-candidate1')]

def write_once(path,data):
 if path.exists():assert path.read_bytes()==data,('Immutable publication differs',str(path))
 else:path.write_bytes(data)

def publish_sound():
 b=ROOT/'build/research';wp=b/'network-menu-work.json';w=json.loads(wp.read_bytes());key='network-menu-sound-raw-native'
 assert w[key+'Status']=='terminal' and w[key+'ExitCode']==0
 log=(b/(key+'.log')).read_text();assert 'Executed 23 tests, with 0 failures' in log and log.count('20 calls 16 network bodies 11 network requests 4 late rollbacks 0 explicit own rejections')==2
 pins=json.loads((b/'network-menu-fixture-pins.json').read_bytes());assert len(pins) in (223,225)
 if len(pins)==223:write_once(b/'network-menu-first-publication-pins.json',(json.dumps(pins,indent=2)+'\n').encode())
 folder=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
 for name,sha in pins.items():assert H((folder/name).read_bytes())==sha
 source_pins=json.loads((b/'network-menu-source-pins.json').read_bytes())
 for suffix in ['primary','control']:
  raw_path=b/('network-menu-sound-'+suffix+'-candidate1.json');raw=raw_path.read_bytes();d=json.loads(raw)
  assert d['producerSHA256']==H(raw_path.with_name(raw_path.stem+'-source.py').read_bytes())==H((ROOT/'tools/oracle_network_menu_sound.py').read_bytes())
  assert d['baseProducerSHA256']==H((ROOT/'tools/oracle_network_menu.py').read_bytes())
  report=audit(raw_path);ui=[c['network'] for c in d['calls'] if 'network' in c];assert len(d['calls'])==20 and len(ui)==16 and not report['unknownOwnLocalReads'] and report['events']['soundMethod']==27
  payload=raw[:-1];assert raw.endswith(b'\n');z=zlib.compressobj(9,zlib.DEFLATED,-15);transport=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(z.compress(payload)+z.flush()).decode()),separators=(',',':'))+'\n').encode()
  name='network-menu-sound'+('-control' if suffix=='control' else '');fixture=folder/('original-'+name+'.json');write_once(fixture,transport);pins[fixture.name]=H(transport);source_pins[str(raw_path.relative_to(ROOT))]=H(raw)
  report.update(producerSHA256=d['producerSHA256'],baseProducerSHA256=d['baseProducerSHA256'],fixture=fixture.name,fixtureSHA256=H(transport),fixtureBytes=len(transport),nativeCompared=True,nativeSuccessfulUIBodies=16,nativeRejectedOwnReads=0,nativeWholeCallerReturns=20,nativeMatchedUIEvents=sum(len(u['events']) for u in ui),nativeMatchedUIRequests=11,nativeSoundMethods=27,nativeLocalContract='Own written bytes/masks and semantic arguments; private unwritten stack remains unknown.',nativeProcessFPUClaim=False,sourceUIControlWord=0,nativeRawTests=dict(tests=23,seconds=9.930,buildSeconds=0.27),packagedNativeCompared=False)
  evidence=ROOT/'docs/evidence'/(name+'.json');write_once(evidence,(json.dumps(report,indent=2)+'\n').encode())
  row=dict(rawPath=str(raw_path.relative_to(ROOT)),fixture=str(fixture.relative_to(ROOT)),evidence=str(evidence.relative_to(ROOT)),sourceSHA256=H(raw),fixtureSHA256=H(transport))
  if not any(x['fixture']==row['fixture'] for x in w['publications']):w['publications'].append(row);w['newFixtureFiles'].append(row['fixture'])
  print(fixture.name,len(raw),len(transport),'27 sound methods',flush=True)
 assert len(pins)==225
 (b/'network-menu-fixture-pins.json').write_text(json.dumps(pins,indent=2)+'\n');(b/'network-menu-source-pins.json').write_text(json.dumps(source_pins,indent=2)+'\n');w['currentFixtures']=225;wp.write_text(json.dumps(w,indent=2)+'\n')

def main():
 if sys.argv[1:]==['--sound']:publish_sound();return
 assert not sys.argv[1:]
 b=ROOT/'build/research';wp=b/'network-menu-work.json';w=json.loads(wp.read_bytes())
 assert w['network-menu-final-raw-nativeStatus']=='terminal' and w['network-menu-final-raw-nativeExitCode']==0
 log=(b/'network-menu-final-raw-native.log').read_text();assert 'Executed 14 tests, with 0 failures' in log
 assert log.count('944 calls 938 network bodies 87 network requests 7 late rollbacks 0 explicit own rejections')==2
 assert log.count('17 calls 12 network bodies 11 network requests 4 late rollbacks 1 explicit own rejections')==3
 prior=json.loads((b/'network-menu-prior-pins.json').read_bytes());assert len(prior)==218
 fixture_dir=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
 for name,sha in prior.items():assert H((fixture_dir/name).read_bytes())==sha
 tool_sha=H((ROOT/'tools/oracle_network_menu.py').read_bytes());publications=[];pins=dict(prior);raw_pins={}
 for suffix,source in INPUTS:
  path=b/('network-menu-'+source+'.json');raw=path.read_bytes();d=json.loads(raw);assert d['producerSHA256']==tool_sha==H(path.with_name(path.stem+'-source.py').read_bytes())
  report=audit(path);unknown=d.get('unsupportedOwnRead');matched=[c['network'] for i,c in enumerate(d['calls']) if 'network' in c and (unknown is None or i!=unknown['case'])]
  assert len(d['calls'])==(17 if unknown else 944) and len(matched)==(12 if unknown else 938)
  assert all(r['case']==unknown['case'] for r in report['unknownOwnLocalReads']) if unknown else not report['unknownOwnLocalReads']
  assert raw.endswith(b'\n');payload=raw[:-1];z=zlib.compressobj(9,zlib.DEFLATED,-15);packed=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(z.compress(payload)+z.flush()).decode()),separators=(',',':'))+'\n').encode()
  fixture=fixture_dir/('original-network-menu'+suffix+'.json');write_once(fixture,packed);pins[fixture.name]=H(packed);raw_pins[str(path.relative_to(ROOT))]=H(raw)
  report.update(producerSHA256=tool_sha,fixture=fixture.name,fixtureSHA256=H(packed),fixtureBytes=len(packed),nativeCompared=True,nativeSuccessfulUIBodies=len(matched),nativeRejectedOwnReads=1 if unknown else 0,nativeWholeCallerReturns=16 if unknown else 943,nativeMatchedUIEvents=sum(len(u['events']) for u in matched),nativeMatchedUIRequests=sum(len(u['networkRequests']) for u in matched),nativeLocalContract='Own written bytes/masks and recovered semantic arguments; private unwritten caller stack is not imported.',nativeProcessFPUClaim=False,sourceUIControlWord=0,nativeRawTests=dict(tests=14,seconds=18.195,buildSeconds=48.80),packagedNativeCompared=False)
  evidence=ROOT/'docs/evidence'/('network-menu'+suffix+'.json');write_once(evidence,(json.dumps(report,indent=2)+'\n').encode());publications.append(dict(rawPath=str(path.relative_to(ROOT)),fixture=str(fixture.relative_to(ROOT)),evidence=str(evidence.relative_to(ROOT)),sourceSHA256=H(raw),fixtureSHA256=H(packed)))
  print(fixture.name,len(raw),len(packed),len(matched),'matches',bool(unknown),'rejection',flush=True)
 assert len(pins)==223
 (b/'network-menu-fixture-pins.json').write_text(json.dumps(pins,indent=2)+'\n');(b/'network-menu-source-pins.json').write_text(json.dumps(raw_pins,indent=2)+'\n')
 w=json.loads(wp.read_bytes());w.update(fixturePublished=True,acceptedMilestone=False,currentFixtures=223,publications=publications,newFixtureFiles=[x['fixture'] for x in publications],nativeRawCompared=True);wp.write_text(json.dumps(w,indent=2)+'\n')
if __name__=='__main__':main()
