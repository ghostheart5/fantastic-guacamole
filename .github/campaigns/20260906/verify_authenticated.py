"""Require complete authenticated-start stress, unchanged runner gates and real UI proof."""
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

APK='af2f8d4ffb8b2af3e80f4b06b873ed4b40d3fb5e333af35bf1c8e53cad899d38'
SOURCE='43b7065507e41f11e6cb31628f928e985e4307d2'
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    loaded=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded
def require(value,message):
    if not value:
        raise ValueError(message)
def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))
def fatal_matches(text):
    package=r'com\.ghostheart5\.chronospark'
    patterns=[r'(?im)^.*// (?:CRASH|ANR):\s*'+package+r'.*$',
              r'(?im)^.*ANR in\s+'+package+r'(?:\s|$).*$',
              r'(?im)^.*(?:am_crash|am_anr).*'+package+r'.*$',
              r'(?is)FATAL EXCEPTION.{0,1200}Process:\s*'+package+r'(?:,|\s)',
              r'(?im)^.*Fatal signal.*'+package+r'.*$',
              r'(?im)^.*\[ERROR\]\[logger\.categorized_error\][ \t]*\[Riverpod Errors\][ \t]*Provider failure\b[^\r\n]*$',
              r'(?im)^.*\[ERROR\]\[logger\.categorized_error\][ \t]*$',
              r'(?im)^.*(?:E/flutter|\bE\s+flutter\s*:|FLUTTER_ERROR_MARKER\s+>>>|MissingPluginException|Failed assertion).*$']
    return [m.group(0)[:500] for pattern in patterns for m in re.finditer(pattern,text)]
def readiness(folder,bootstrap,base):
    receipt=read(folder/'receipt.json')
    require(receipt['status']=='passed' and receipt['freshNexusVisible'] and receipt['maestroExitCode']==0,'UI readiness did not pass')
    xml=(folder/'nexus.xml').read_bytes()
    require(bootstrap.nexus_visible(xml),'Actual hierarchy does not show Nexus and navigation')
    for name,key in (('nexus.xml','xmlSha256'),('nexus.png','screenshotSha256'),('junit.xml','junitSha256')):
        require(base.digest(folder/name)==receipt[key],'Readiness file hash mismatch: '+name)
    junit=ET.parse(folder/'junit.xml')
    cases=junit.findall('.//testcase')
    require(len(cases)==1 and cases[0].get('name')=='sign-in-qa','Unexpected readiness JUnit inventory')
    require(not any(junit.findall('.//'+tag) for tag in ('failure','error','skipped')),'Nonpassing actual readiness JUnit')
    return {'name':receipt['name'],'xmlSha256':receipt['xmlSha256'],'screenshotSha256':receipt['screenshotSha256'],'status':'passed'}
def verify(root,controls):
    base=module('base_campaign_verifier',controls/'verify_campaign.py')
    prep=module('authenticated_runner_preparation',controls/'prepare_authenticated_runner.py')
    bootstrap=module('authenticated_ui_bootstrap',controls/'bootstrap_authenticated.py')
    m=read(root/'campaign-manifest.json')
    require(m['kind']=='authenticated-start-stress' and m['status']=='passed' and m['sourceCleanAfter'],'Authenticated campaign incomplete or failed')
    require(m['sourceCommit']==SOURCE,'Wrong frozen application source')
    require([s['name'] for s in m['steps']]==['authenticated-monkey','final-nexus-readback'] and all(s['exitCode']==0 for s in m['steps']),'Missing or nonpassing required stages')
    require(base.digest(root/'qa.apk')==m['apk']['sha256']==APK,'APK identity mismatch')
    require((root/'qa.apk').stat().st_size==m['apk']['bytes'],'APK byte count mismatch')
    original=(root/'controls/original-monkey-runner.ps1').read_text(encoding='utf-8')
    executed=(root/'controls/executed-monkey-runner.ps1').read_text(encoding='utf-8')
    require(executed==prep.adjusted(original),'Runner has unexpected modifications')
    config=read(controls/'authenticated.json')
    monkey=base.monkey(root/'authenticated-monkey',config,APK)
    require(monkey['variants']==15 and monkey['injectedEvents']==8750,'Authenticated stress inventory mismatch')
    path,matrix=base.one_manifest(root/'authenticated-monkey')
    results=[]
    for variant in matrix['results']:
        require(variant['authenticatedStartVerified'],'Variant did not verify authenticated startup')
        proof=readiness(path.parent/('authenticated-start-'+variant['name']),bootstrap,base)
        text=(path.parent/(variant['name']+'-monkey.log')).read_text(encoding='utf-8-sig')
        counts=re.findall(r'^\s*Events injected:\s*(\d+)\s*$',text,re.M)
        require(len(counts)==1 and int(counts[0])==variant['events'],'Actual injected event count mismatch')
        require(not re.search(r'// CRASH:|// ANR:|System appears to have crashed|Monkey aborted',text,re.I),'Monkey output contains abort/crash markers')
        log_path=path.parent/(variant['name']+'-full-logcat.log')
        require(log_path.stat().st_size>0,'Missing full runtime Logcat')
        fatal=fatal_matches(log_path.read_text(encoding='utf-8-sig'))
        require(not fatal,'Fatal runtime evidence in '+variant['name']+': '+str(fatal[:2]))
        results.append({'name':variant['name'],'seed':variant['seed'],'injectedEvents':int(counts[0]),
                        'readiness':proof,'fullLogcatSha256':base.digest(log_path)})
    final_folder=root/'authenticated-start-final-readback'
    final=readiness(final_folder,bootstrap,base)
    require(not fatal_matches((final_folder/'final-logcat.log').read_text(encoding='utf-8-sig')),'Final UI readback has fatal runtime markers')
    return {'status':'passed','kind':m['kind'],'sourceCommit':SOURCE,'harnessCommit':m['harnessCommit'],
            'runId':m['runId'],'attempt':m['attempt'],'apkSha256':APK,'monkey':monkey,'variants':results,
            'finalNexusReadback':final,'originalRunnerGatesPreserved':True,'verifiedAtUtc':datetime.now(timezone.utc).isoformat()}

if __name__=='__main__':
    root=Path(sys.argv[1])
    controls=Path(__file__).resolve().parent
    try:
        result=verify(root,controls)
    except Exception as error:
        result={'status':'failed','error':str(error),'verifiedAtUtc':datetime.now(timezone.utc).isoformat()}
    root.mkdir(parents=True,exist_ok=True)
    (root/'verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))
    raise SystemExit(0 if result['status']=='passed' else 1)
