"""Verify rebuilt-source Android repair evidence, including full runtime logs."""
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

def require(value, message):
    if not value:
        raise ValueError(message)

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def fatal_matches(text):
    package = r'com\.ghostheart5\.chronospark'
    patterns = [r'(?im)^.*// (?:CRASH|ANR):\s*'+package+r'.*$',
        r'(?im)^.*ANR in\s+'+package+r'(?:\s|$).*$',
        r'(?im)^.*(?:am_crash|am_anr).*'+package+r'.*$',
        r'(?is)FATAL EXCEPTION.{0,1200}Process:\s*'+package+r'(?:,|\s)',
        r'(?im)^.*Fatal signal.*'+package+r'.*$',
        r'(?im)^.*\[ERROR\]\[logger\.categorized_error\][ \t]*\[Riverpod Errors\][ \t]*Provider failure\b[^\r\n]*$',
        r'(?im)^.*\[ERROR\]\[logger\.categorized_error\][ \t]*$',
        r'(?im)^.*\[ERROR\]\[(?:startup\.(?:flutter_framework_error|platform_dispatcher_error|uncaught_zone_error)|error_boundary\.global_error)\](?:[ \t]|$).*$',
        r'(?im)^.*(?:E/flutter|\bE\s+flutter\s*:|FLUTTER_ERROR_MARKER\s+>>>|PLATFORM_ERROR_MARKER\s+>>>|MissingPluginException|Failed assertion).*$']
    return [match.group(0)[:500] for pattern in patterns for match in re.finditer(pattern, text)]

def readiness(folder, bootstrap, base):
    r = read(folder / 'receipt.json')
    require(r['status']=='passed' and r['freshNexusVisible'] and r['foregroundOwnsWindow'] and r['maestroExitCode']==0, 'Readiness failed')
    for name, key in [('window-displays.txt','windowStateSha256'),('nexus.xml','xmlSha256'),('nexus.png','screenshotSha256'),('junit.xml','junitSha256')]:
        require(base.digest(folder / name)==r[key], 'Readiness evidence hash mismatch: '+name)
    require(re.search(r'mCurrentFocus=.*com\.ghostheart5\.chronospark',(folder/'window-displays.txt').read_text(encoding='utf-8')), 'Actual focus is not ChronoSpark')
    require(bootstrap.nexus_visible((folder/'nexus.xml').read_bytes()), 'Actual Nexus is not visible')
    xml = ET.parse(folder/'junit.xml')
    cases = xml.findall('.//testcase')
    require(len(cases)==1 and cases[0].get('name')=='sign-in-qa' and not any(xml.findall('.//'+tag) for tag in ('failure','error','skipped')), 'Actual sign-in JUnit failed')
    return {'name':r['name'],'status':'passed','xmlSha256':r['xmlSha256'],'screenshotSha256':r['screenshotSha256']}

def verify(root, controls, expected_commit):
    require(re.fullmatch(r'[a-f0-9]{40}', expected_commit or ''), 'Expected exact source commit is required')
    base = module('repair_base_verifier', controls/'verify_campaign.py')
    base.SOURCE = expected_commit
    prep = module('repair_runner_preparation', controls/'prepare_authenticated_runner.py')
    flow = module('repair_flow_preparation', controls/'prepare_flow.py')
    bootstrap = module('repair_bootstrap', controls/'bootstrap_authenticated.py')
    m = read(root/'campaign-manifest.json')
    require(m['status']=='passed' and m['kind']=='dialog-runtime-repair' and m['sourceCleanAfter'], 'Campaign incomplete or failed')
    require(m['sourceCommit']==m['harnessCommit']==expected_commit, 'Source/controls identity mismatch')
    require([s['name'] for s in m['steps']]==['authenticated-monkey','journeys','welcome','final-nexus-readback'] and all(s['exitCode']==0 for s in m['steps']), 'Required stage inventory did not pass')
    apk = base.digest(root/'qa.apk')
    require(apk==m['apk']['sha256'] and (root/'qa.apk').stat().st_size==m['apk']['bytes'] and m['apk']['rebuiltFromSource']==expected_commit, 'Rebuilt APK identity mismatch')
    source_proofs = []
    for entry in read(controls/'source-manifest.json')['files']:
        require(base.digest(root/'source-proofs'/entry['path'])==entry['canonicalSha256'], 'Repaired source proof mismatch')
        source_proofs.append(entry)
    original=(root/'controls/original-monkey-runner.ps1').read_text(encoding='utf-8')
    require((root/'controls/executed-monkey-runner.ps1').read_text(encoding='utf-8')==prep.adjusted(original), 'Unexpected runner modification')
    old_flow=(root/'controls/original-priority8-learned-lifecycle.yaml').read_text(encoding='utf-8')
    require((root/'controls/executed-priority8-learned-lifecycle.yaml').read_text(encoding='utf-8')==flow.adjusted(old_flow), 'Unexpected journey modification')
    monkey = base.monkey(root/'authenticated-monkey',read(controls/'authenticated.json'),apk)
    require(monkey['variants']==15 and monkey['injectedEvents']==8750, 'Wrong stress workload')
    path, matrix = base.one_manifest(root/'authenticated-monkey')
    variants=[]
    for item in matrix['results']:
        name=item['name']
        require(item['authenticatedStartVerified'], 'Missing authenticated start')
        proof=readiness(path.parent/('authenticated-start-'+name),bootstrap,base)
        text=(path.parent/(name+'-monkey.log')).read_text(encoding='utf-8-sig')
        counts=re.findall(r'^\s*Events injected:\s*(\d+)\s*$',text,re.M)
        require(len(counts)==1 and int(counts[0])==item['events'], 'Actual random events mismatch')
        require(not re.search(r'// CRASH:|// ANR:|System appears to have crashed|Monkey aborted',text,re.I), 'Random input aborted')
        log=path.parent/(name+'-full-logcat.log')
        require(base.digest(log)==item['fullLogcatSha256'] and log.stat().st_size==item['fullLogcatBytes']>0, 'Full stress Logcat identity mismatch')
        matches=fatal_matches(log.read_text(encoding='utf-8-sig'))
        require(not matches,'Runtime errors in '+name+': '+str(matches[:2]))
        variants.append({'name':name,'seed':item['seed'],'events':int(counts[0]),'readiness':proof,'fullLogcatSha256':base.digest(log)})
    ui=[]
    for stage, flows in [('maestro',base.FLOWS),('welcome',['03-onboarding-tutorial.yaml'])]:
        summary=base.maestro(root/stage,flows,apk)
        path, manifest=base.one_manifest(root/stage)
        log=path.parent/'adb-logcat-raw.log'
        require(log.stat().st_size==manifest['logcatCapture']['outputBytes'] and (path.parent/'adb-logcat-stderr.log').stat().st_size==0, 'Incomplete full journey Logcat')
        matches=fatal_matches(log.read_text(encoding='utf-8-sig'))
        require(not matches,'Runtime errors in '+stage+': '+str(matches[:2]))
        ui.append({'stage':stage,**summary,'fullLogcatSha256':base.digest(log)})
    final_folder=root/'authenticated-start-final-readback'
    final=readiness(final_folder,bootstrap,base)
    require(not fatal_matches((final_folder/'final-logcat.log').read_text(encoding='utf-8-sig')), 'Final Nexus has runtime errors')
    return {'status':'passed','sourceCommit':expected_commit,'runId':m['runId'],'apkSha256':apk,
            'sourceProofs':source_proofs,'monkey':monkey,'variants':variants,'ui':ui,'finalNexusReadback':final,
            'verifiedAtUtc':datetime.now(timezone.utc).isoformat()}

if __name__=='__main__':
    root=Path(sys.argv[1])
    try:
        result=verify(root,Path(__file__).resolve().parent,os.environ.get('GITHUB_SHA'))
    except Exception as error:
        result={'status':'failed','error':str(error),'verifiedAtUtc':datetime.now(timezone.utc).isoformat()}
    root.mkdir(parents=True,exist_ok=True)
    (root/'verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))
    raise SystemExit(0 if result['status']=='passed' else 1)
