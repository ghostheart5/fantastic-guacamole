"""Use the real QA sign-in UI and require an observed Nexus before stress."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

PACKAGE = 'com.ghostheart5.chronospark'
def sha(data):
    return hashlib.sha256(data).hexdigest()
def require(value,message):
    if not value:
        raise ValueError(message)
def nexus_visible(xml):
    tree = ET.fromstring(xml)
    observed=set()
    for node in tree.iter('node'):
        match=re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',node.get('bounds',''))
        if node.get('package')!=PACKAGE or node.get('enabled')!='true' or not match:
            continue
        left,top,right,bottom=map(int,match.groups())
        if not (0<=left<right<=10000 and 0<=top<bottom<=10000):
            continue
        observed.update((node.get('text'),node.get('content-desc')))
    return {'NEXUS','Open navigation map'}.issubset(observed)
def run(source, output, name, serial):
    require(serial=='emulator-5554','Authenticated stress is restricted to the hosted emulator')
    require(re.fullmatch(r'(?:low|medium|high)-(?:smoke|balanced|navigation|touch-motion|lifecycle)|final-readback',name), 'Unknown stress readiness label')
    folder = output/('authenticated-start-'+name)
    folder.mkdir(parents=True,exist_ok=False)
    receipt = {'status':'failed','name':name,'serial':serial,'startedAtUtc':datetime.now(timezone.utc).isoformat(),
               'authenticationMethod':'existing QA Test Login UI; no real credentials','clearState':False}
    def adb(*args):
        return subprocess.run(['adb','-s',serial,*args],capture_output=True,check=True,timeout=30).stdout
    try:
        require(adb('shell','getprop','ro.build.version.sdk').strip()==b'35','Wrong emulator API')
        require(adb('shell','getprop','ro.kernel.qemu').strip()==b'1','A disposable emulator is required')
        receipt['signInFlowSha256']=sha((source/'.maestro/subflows/sign-in-qa.yaml').read_bytes())
        args = ['timeout','--kill-after=5s','180s','maestro','test','--udid',serial,'--no-ansi',
                '--format','JUNIT','--output',str(folder/'junit.xml'),'--debug-output',str(folder/'debug'),
                '--test-output-dir',str(folder/'artifacts'),str(source/'.maestro/subflows/sign-in-qa.yaml')]
        with (folder/'maestro.log').open('xb') as log:
            process = subprocess.run(args,stdout=log,stderr=subprocess.STDOUT,timeout=195)
        receipt['maestroExitCode']=process.returncode
        require(process.returncode==0,'QA UI sign-in/readiness did not pass')
        junit = ET.parse(folder/'junit.xml')
        cases = junit.findall('.//testcase')
        require(len(cases)==1 and not any(junit.findall('.//'+tag) for tag in ('failure','error','skipped')),
                'Incomplete or nonpassing QA sign-in JUnit')
        focus_bytes = adb('shell','dumpsys','window','displays')
        (folder/'window-displays.txt').write_bytes(focus_bytes)
        focus = focus_bytes.decode('utf-8',errors='replace')
        receipt['foregroundOwnsWindow'] = bool(re.search(r'mCurrentFocus=.*com\.ghostheart5\.chronospark',focus))
        receipt['windowStateSha256'] = sha(focus_bytes)
        remote = '/sdcard/chronospark-authenticated-'+name+'.xml'
        adb('shell','uiautomator','dump',remote)
        xml = adb('exec-out','cat',remote)
        (folder/'nexus.xml').write_bytes(xml)
        receipt['freshNexusVisible'] = nexus_visible(xml)
        png = adb('exec-out','screencap','-p')
        require(png.startswith(b'\x89PNG\r\n\x1a\n'),'Invalid actual screenshot')
        (folder/'nexus.png').write_bytes(png)
        adb('shell','rm',remote)
        require(receipt['foregroundOwnsWindow'],'ChronoSpark is not the foreground window')
        require(receipt['freshNexusVisible'],'Visible enabled Nexus was not observed before stress')
        if name=='final-readback':
            (folder/'final-logcat.log').write_bytes(adb('logcat','-d','-v','threadtime'))
        receipt.update({'status':'passed','freshNexusVisible':True,'xmlSha256':sha(xml),'screenshotSha256':sha(png),
                        'junitSha256':sha((folder/'junit.xml').read_bytes())})
    except Exception as error:
        receipt['error']=str(error)
    finally:
        receipt['finishedAtUtc']=datetime.now(timezone.utc).isoformat()
        (folder/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt))
    return 0 if receipt['status']=='passed' else 1

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for key in ('source','output','name','serial'):
        parser.add_argument('--'+key,required=True)
    args=parser.parse_args()
    raise SystemExit(run(Path(args.source),Path(args.output),args.name,args.serial))
