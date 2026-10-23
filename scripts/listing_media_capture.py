"""Capture real UI on one disposable hosted QA emulator; never fabricate app state.

All planning records are entered through accessibility-observed visible controls.
Outputs are review candidates, not production acceptance or approved marketing.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shutil
import struct
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
import zipfile

PACKAGE = 'com.ghostheart5.chronospark.qa'
SERIAL = 'emulator-5554'
RETIRED = re.compile(r'\b(?:Nexus Core|Smart Planner|Now Engine|Trajectory Engine|Future Branches|Truth Ledger|Reality Builder|Capability Matrix|Deep Intelligence|SI Console|Human Profile|Control Center|Daily Rhythms)\b', re.I)


def run(*args, binary=False, timeout=40):
    return subprocess.check_output(args, timeout=timeout, text=not binary)


def adb(*args, binary=False):
    return run('adb', '-s', SERIAL, *args, binary=binary)


def shell(*args):
    return adb('shell', *args).strip()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def signer_digest(signing):
    signers = sorted({v.lower() for v in re.findall(
        r'^(?:V\d+(?:\.\d+)? )?Signer(?: #\d+|:) certificate SHA-256 digest: ([a-fA-F0-9]{64})$',
        signing, re.M)})
    assert len(signers) == 1, 'Expected one unique signer certificate; raw output retained'
    return signers[0]


def unique_title_editor(tree):
    editors = [n for n in tree.iter('node') if n.get('class') == 'android.widget.EditText'
               and n.get('package') == PACKAGE and n.get('enabled') == 'true'
               and n.get('password') != 'true'
               and re.fullmatch(r'\[\d+,\d+\]\[\d+,\d+\]', n.get('bounds',''))]
    assert len(editors) == 1, 'Expected exactly one observed editable title field'
    assert not editors[0].get('text'), 'New title field must be empty before demo input'
    left, top, right, bottom = map(int,re.findall(r'\d+',editors[0].get('bounds')))
    assert right > left and bottom > top
    return left, top, right, bottom


def apk_identity(apk, diagnostics=None):
    sdk = Path(os.environ['ANDROID_HOME'])
    available = sorted(sdk.glob('build-tools/*/aapt2'))
    assert available
    tools = available[-1].parent
    badging = run(str(tools/'aapt2'), 'dump', 'badging', str(apk))
    if diagnostics:
        (diagnostics/'apk-badging.txt').write_text(badging)
    signature = subprocess.run([str(tools/'apksigner'), 'verify', '--verbose', '--print-certs', str(apk)],
                               capture_output=True, text=True, timeout=40)
    signing = signature.stdout
    if diagnostics:
        (diagnostics/'apk-signature.txt').write_text(signing)
        (diagnostics/'apk-signature-stderr.txt').write_text(signature.stderr)
    signature.check_returncode()
    match = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging, re.M)
    version = re.search(r'^version:\s*(.*)$', Path('pubspec.yaml').read_text(), re.M).group(1)
    name, code = version.split('+')
    assert match and match.groups() == (PACKAGE, code, name+'-qa')
    assert re.search(r'^application-debuggable\s*$', badging, re.M)
    native = re.search(r'^native-code:\s*(.*)$', badging, re.M)
    assert native
    abis = re.findall(r"'([^']+)'", native[1])
    assert 'x86_64' in abis
    # Plugins may carry extra ABIs even in the x86_64 Flutter build. Require
    # the actual Flutter engine ABI instead of assuming aapt lists only one.
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None
        flutter_abis = sorted(p.split('/')[1] for p in archive.namelist()
                              if re.fullmatch(r'lib/[^/]+/libflutter\.so', p))
    assert 'x86_64' in flutter_abis
    # Match the existing main build-only verifier: the same certificate can
    # appear for several signature schemes. Distinct certificates still fail.
    signer = signer_digest(signing)
    return {'package': PACKAGE, 'versionCode': code, 'versionName': name+'-qa',
            'requiredFlutterAbi': 'x86_64', 'flutterAbis': flutter_abis, 'nativeAbis': abis,
            'debuggable': True, 'signerSha256': signer}, badging, signing


def apk_artifact_mode():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['preserve-apk', 'seal-apk', 'verify-reused-apk'])
    parser.add_argument('--source', required=True)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    assert os.name == 'posix' and os.environ.get('GITHUB_ACTIONS') == 'true'
    assert os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted'
    assert os.environ.get('GITHUB_REPOSITORY') == 'ghostheart5/fantastic-guacamole'
    assert re.fullmatch('[a-f0-9]{40}', args.source)
    assert run('git', 'rev-parse', 'HEAD').strip() == args.source
    assert not run('git', 'status', '--porcelain').strip()
    assert args.apk.is_file() and not args.apk.is_symlink()
    assert args.apk.stat().st_size < 189*1024**2
    current = {'schema': 1, 'sourceSha': args.source,
               'sourceTree': run('git','rev-parse','HEAD^{tree}').strip(),
               'qaDefinesSha256': sha('tool/qa_defines.json'), 'lockfileSha256': sha('pubspec.lock'),
               'apkSha256': sha(args.apk)}
    if args.mode == 'preserve-apk':
        assert args.output is not None
        args.output.mkdir(parents=True, exist_ok=False)
        # Preserve expensive compilation bytes before parsing any tool output.
        # This artifact is explicitly unverified and cannot claim app acceptance.
        shutil.copyfile(args.apk, args.output/'app-debug.apk')
        current.update({'verificationStatus': 'NOT_VERIFIED',
                        'producerRunId': os.environ['GITHUB_RUN_ID'],
                        'producerToolingSha': os.environ['GITHUB_SHA'],
                        'producerWorkflowRef': os.environ['GITHUB_WORKFLOW_REF'],
                        'boundary': 'Raw compilation preservation only. Identity/signature NOT VERIFIED. Never a public release or app acceptance.'})
        (args.output/'receipt.json').write_text(json.dumps(current,indent=2)+'\n')
        assert sum(p.stat().st_size for p in args.output.iterdir()) < 190*1024**2
        return
    diagnostics = Path('test-results/listing-media/apk-verification')
    diagnostics.mkdir(parents=True, exist_ok=True)
    identity, badging, signing = apk_identity(args.apk, diagnostics)
    current['identity'] = identity
    if args.mode == 'seal-apk':
        assert args.output is not None
        args.output.mkdir(parents=True, exist_ok=False)
        current.update({'producerRunId': os.environ['GITHUB_RUN_ID'],
                        'verificationStatus': 'verified',
                        'producerToolingSha': os.environ['GITHUB_SHA'],
                        'producerWorkflowRef': os.environ['GITHUB_WORKFLOW_REF'],
                        'sealToolSha256': sha(__file__),
                        'boundary': 'Debug x86_64 local QA APK only. Not public release or app acceptance.'})
        shutil.copyfile(args.apk, args.output/'app-debug.apk')
        (args.output/'apk-badging.txt').write_text(badging)
        (args.output/'apk-signature.txt').write_text(signing)
        (args.output/'receipt.json').write_text(json.dumps(current,indent=2)+'\n')
        assert sum(p.stat().st_size for p in args.output.iterdir()) < 190*1024**2
    else:
        expected_receipt = os.environ['REUSE_RECEIPT_SHA256']
        expected_apk = os.environ['REUSE_APK_SHA256']
        producer_sha = os.environ['REUSE_TOOLING_SHA']
        producer_run = os.environ['REUSE_RUN_ID']
        assert re.fullmatch('[a-f0-9]{64}', expected_receipt)
        assert re.fullmatch('[a-f0-9]{64}', expected_apk)
        assert re.fullmatch('[a-f0-9]{40}', producer_sha)
        assert re.fullmatch('[0-9]+', producer_run)
        receipt_path = args.apk.parent/'receipt.json'
        assert sha(receipt_path) == expected_receipt
        receipt = json.loads(receipt_path.read_text())
        assert receipt.get('verificationStatus') in {'verified', 'NOT_VERIFIED'}
        for key, actual in current.items():
            if key == 'identity' and receipt['verificationStatus'] == 'NOT_VERIFIED':
                # Explicitly reviewed raw receipts have no identity assertion.
                # The consumer has just reverified the real APK independently.
                continue
            assert receipt[key] == actual, key
        assert current['apkSha256'] == expected_apk
        assert receipt['producerRunId'] == producer_run
        assert receipt['producerToolingSha'] == producer_sha
        repo = os.environ['GITHUB_REPOSITORY']
        producer = json.loads(run('gh','api',f'repos/{repo}/actions/runs/{producer_run}'))
        assert producer['head_sha'] == producer_sha
        assert producer['event'] == 'workflow_dispatch'
        assert producer['repository']['full_name'] == repo
        assert producer['path'] in {'.github/workflows/maestro-runtime.yml','.github/workflows/listing-media-capture.yml'}
        artifacts = json.loads(run('gh','api',f'repos/{repo}/actions/runs/{producer_run}/artifacts'))['artifacts']
        matching = [a for a in artifacts if a['name'] == os.environ['REUSE_ARTIFACT'] and not a['expired']]
        assert len(matching) == 1
        assert matching[0]['workflow_run']['head_sha'] == producer_sha
        target = Path('build/app/outputs/flutter-apk/app-debug.apk')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args.apk, target)
        assert sha(target) == expected_apk
        evidence = Path('test-results/listing-media/reuse')
        evidence.mkdir(parents=True, exist_ok=False)
        shutil.copyfile(receipt_path, evidence/'producer-receipt.json')
        (evidence/'verification.json').write_text(json.dumps({'status':'verified',
            'producerRunId': producer_run, 'producerToolingSha': producer_sha,
            'producerReceiptSha256': expected_receipt, 'artifactId': matching[0]['id'],
            'consumerToolingSha': os.environ['GITHUB_SHA'], **current},indent=2)+'\n')


class Capture:
    def __init__(self, output, locale):
        self.output, self.locale = output, locale
        self.width, self.height = 1080, 1920
        self.actions = []
        self.images = []
        self.frames = 0
        self.dumps = 0
        self.ui_readiness = []
        self.diagnostic_form_captured = False

    def tree(self):
        # Cold Flutter startup can briefly have no accessibility root. Observe
        # readiness passively; never reuse an earlier dump or repeat an action.
        from hosted_guest_anr import classify_anr
        for attempt in range(5):
            self.dumps += 1
            remote = f'/sdcard/listing-capture-{self.dumps:04d}.xml'
            dump = subprocess.run(['adb','-s',SERIAL,'shell','uiautomator','dump',remote],
                                  capture_output=True, text=True, timeout=40)
            prefix = self.output/f'ui-dump-{self.dumps:04d}'
            Path(str(prefix)+'-stdout.txt').write_text(dump.stdout)
            Path(str(prefix)+'-stderr.txt').write_text(dump.stderr)
            content = subprocess.run(['adb','-s',SERIAL,'exec-out','cat',remote],
                                     capture_output=True, text=True, timeout=20)
            xml = content.stdout
            Path(str(prefix)+'-raw.txt').write_text(xml+content.stderr)
            try:
                tree = ET.fromstring(xml)
                assert tree.tag == 'hierarchy' and next(tree.iter('node'), None) is not None
                valid = dump.returncode == 0 and content.returncode == 0
            except (ET.ParseError, AssertionError):
                valid = False
            self.ui_readiness.append({'dump': self.dumps, 'attempt': attempt,
                                      'dumpExitCode': dump.returncode,
                                      'readExitCode': content.returncode, 'validHierarchy': valid})
            if valid:
                self.frames += 1
                (self.output/f'ui-{self.frames:04d}.xml').write_text(xml, encoding='utf-8')
                visible = '\n'.join(n.get('text', '')+'\n'+n.get('content-desc', '') for n in tree.iter('node'))
                assert not re.search(r"isn.t responding|Application Error|keeps stopping", visible, re.I), visible
                return tree
            window = shell('dumpsys','window','windows')
            assert not re.search(r"Application (?:Error|Not Responding)|isn.t responding", window, re.I)
            last_anr = shell('dumpsys','activity','lastanr')
            events = shell('logcat','-d','-b','events','-v','threadtime')
            anr = classify_anr(last_anr, events, PACKAGE)
            assert not anr['appAnrObserved'], 'App ANR while waiting for accessibility readiness'
            time.sleep(2)
        raise AssertionError('No valid fresh UI hierarchy after five passive observations; dump diagnostics retained')

    def find(self, pattern, tree=None):
        result = []
        for node in (tree if tree is not None else self.tree()).iter('node'):
            if node.get('enabled') == 'false':
                continue
            values = (node.get('text', ''), node.get('content-desc', ''))
            if any(re.search(pattern, value, re.S) for value in values):
                bounds = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
                if len(bounds) == 4 and bounds[2] > bounds[0] and bounds[3] > bounds[1]:
                    result.append((node, bounds))
        return sorted(result, key=lambda pair: (pair[1][2]-pair[1][0])*(pair[1][3]-pair[1][1]))

    def tap(self, pattern, *, scroll=False, optional=False, up=False):
        for attempt in range(8 if scroll else 3):
            matches = self.find(pattern)
            if matches:
                _, (left, top, right, bottom) = matches[0]
                shell('input', 'tap', str((left+right)//2), str((top+bottom)//2))
                self.actions.append({'action': 'tap', 'observedSelector': pattern})
                time.sleep(1)
                return True
            if scroll:
                self.swipe(up=up)
            else:
                time.sleep(1)
        if optional:
            return False
        raise AssertionError(f'Visible control not found: {pattern}')

    def swipe(self, up=False):
        x = str(self.width//2)
        start, end = (0.35, 0.8) if up else (0.8, 0.35)
        shell('input', 'swipe', x, str(int(self.height*start)), x, str(int(self.height*end)), '450')
        time.sleep(0.5)

    def wait(self, pattern, seconds=30):
        end = time.monotonic()+seconds
        while time.monotonic() < end:
            if self.find(pattern):
                return
            time.sleep(1)
        raise AssertionError(f'UI did not reach {pattern}')

    def nav(self, en, es):
        # The extended tablet rail adds its visible Tools text to the same
        # semantics node; accept only those source-defined language pairs.
        self.tap(r'^(?:Browse tools(?:\nTools)?|Ver herramientas(?:\nHerramientas)?)$')
        self.tap(r'^(?:'+re.escape(en)+'|'+re.escape(es)+r')(?:\n.*)?$', scroll=True)
        # Insights is the navigation label; its real screen heading is more
        # descriptive. Require that heading rather than a stale nav label.
        heading = (r'^(?:Patterns & future outcomes|Patrones y resultados futuros)$'
                   if en == 'Insights' else r'^(?:'+re.escape(en)+'|'+re.escape(es)+r')$')
        self.wait(heading)

    def screenshot(self, name):
        time.sleep(2)
        tree = self.tree()
        rendered = '\n'.join(n.get('text', '')+' '+n.get('content-desc', '') for n in tree.iter('node'))
        assert not RETIRED.search(rendered), 'Retired visible label in candidate: '+name
        image = self.output / (name+'.png')
        image.parent.mkdir(parents=True, exist_ok=True)
        image.write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
        assert image.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n'
        size = struct.unpack('>II', image.read_bytes()[16:24])
        assert size == (self.width, self.height), size
        self.images.append({'path': image.relative_to(self.output).as_posix(), 'sha256': sha(image), 'pixels': list(size),
                            'locale': self.locale, 'uiTree': f'ui-{self.frames:04d}.xml',
                            'uiTreeSha256': sha(self.output/f'ui-{self.frames:04d}.xml')})

    def profile(self):
        # Only first-run guide actions and local profile creation are allowed.
        for _ in range(12):
            tree = self.tree()
            if self.find(r'^(?:Add a goal, task or habit|Añadir una meta, tarea o hábito)$', tree):
                return
            for pattern in [r'^CONTINUE TO (?:LOGIN|PROFILE|SETUP)$|^CONTINUAR (?:AL ACCESO|AL PERFIL|CONFIGURACIÓN)$',
                            r'^(?:Start login|Comenzar acceso)$',
                            r'^(?:Create profile|Crear perfil|Open profile|Abrir perfil)$',
                            r'^(?:Go to Today|Ir a Hoy|SKIP FOR NOW|SALTAR POR AHORA)$',
                            r'^(?:Pause guide|Pausar guía)$']:
                if self.find(pattern, tree):
                    self.tap(pattern)
                    break
            else:
                time.sleep(2)
        # Do not claim onboarding succeeded just because a guide action ran.
        self.wait(r'^(?:Today|Hoy)$')
        assert self.find(r'^(?:Add a goal, task or habit|Añadir una meta, tarea o hábito)$')

    def create(self, kind, title, schedule=False, capture_form=None):
        self.nav('Add something', 'Añadir algo')
        names = {'task': ('Task', 'Tarea'), 'goal': ('Goal', 'Meta'), 'habit': ('Habit', 'Hábito')}
        # Saved receipts deliberately survive navigation. New item is the
        # visible action that opens a fresh form; the last selected type also
        # persists, so never assume the next dropdown starts at Task.
        if self.find(r'^(?:New item|Nuevo elemento)$'):
            self.tap(r'^(?:New item|Nuevo elemento)$')
        en, es = names[kind]
        desired = r'^(?:'+en+'|'+es+')$'
        if not self.find(desired):
            self.tap(r'^(?:Task|Tarea|Goal|Meta|Habit|Hábito|Note|Nota)$', scroll=True)
            self.tap(desired)
        if not self.diagnostic_form_captured:
            self.screenshot('diagnostic/01-add-task-before-demo')
            self.diagnostic_form_captured = True
        tree = self.tree()
        labeled = self.find(r'^(?:Title, required|Título, obligatorio)(?:\s+Title \*|\s+Título \*)?$', tree)
        if labeled:
            self.tap(r'^(?:Title, required|Título, obligatorio)(?:\s+Title \*|\s+Título \*)?$')
        else:
            # The real Android 35 dump omits Flutter TextField hint/label text.
            # In this collapsed form the title is the sole editable control.
            # Require that exact observed condition rather than guessed pixels.
            assert self.find(r'^(?:Add something|Añadir algo)$', tree)
            left, top, right, bottom = unique_title_editor(tree)
            shell('input','tap',str((left+right)//2),str((top+bottom)//2))
            self.actions.append({'action':'tap','observedSelector':'unique visible nonpassword title EditText in Add something',
                                 'uiTree':f'ui-{self.frames:04d}.xml'})
        assert title.isascii(), 'ADB input text is deliberately limited to ASCII demo names'
        shell('input', 'text', title.replace(' ', '%s'))
        self.wait('^'+re.escape(title)+'$')
        shell('input', 'keyevent', '111')
        if schedule:
            self.tap(r'^(?:Task options \(optional\)|Opciones de la tarea \(opcional\)).*', scroll=True)
            self.tap(r'^(?:Schedule date and time|Elegir fecha y hora)(?:\.\.\.)?$', scroll=True)
            self.tap(r'^(?:OK|Aceptar|ACEPTAR)$')
            self.tap(r'^(?:OK|Aceptar|ACEPTAR)$')
        en, es = names[kind]
        if capture_form:
            self.swipe(up=True)
            self.swipe(up=True)
            self.screenshot(capture_form+'/06-add-task')
        self.tap(r'^(?:Save '+en.lower()+'|Guardar '+es.lower()+')$', scroll=True)
        receipt_pattern = r'^(?:'+en+'|'+es+'): '+re.escape(title)+r'$'
        self.wait(receipt_pattern)
        if capture_form:
            self.screenshot(capture_form+'/07-saved-task')

    def record_screens(self, form):
        folder = form+'/'+('es' if self.locale == 'es-US' else 'en')
        self.nav('Today', 'Hoy')
        self.screenshot(folder+'/01-today')
        self.nav('My plan', 'Mi plan')
        self.screenshot(folder+'/02-my-plan')
        self.tap(r'^(?:Schedule|Agenda)$', scroll=True)
        self.wait(r'^(?:Schedule|Agenda)$')
        self.screenshot(folder+'/03-schedule')
        # My plan opens Schedule on a pushed route without the shell tools menu.
        shell('input', 'keyevent', '4')
        self.actions.append({'action': 'back', 'fromObservedScreen': 'Schedule'})
        self.wait(r'^(?:My plan|Mi plan)$')
        self.nav('Insights', 'Perspectivas')
        self.screenshot(folder+'/04-insights')
        self.nav('Chat', 'Chat')
        # Never submit an external AI request. This is the authentic entry view.
        self.screenshot(folder+'/05-chat')
        titles = {'phone': ('Stretch for two minutes', 'Estirar durante dos minutos'),
                  'tablet-7': ('Prepare lunch for tomorrow', 'Preparar el almuerzo de hoy'),
                  'tablet': ('Write down one priority', 'Anotar una prioridad')}
        self.create('task', titles[form][self.locale == 'es-US'], capture_form=folder)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--locale', choices=['en-US', 'es-US'], required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert os.name == 'posix' and os.environ.get('GITHUB_ACTIONS') == 'true'
    assert os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted'
    assert os.environ.get('GITHUB_REPOSITORY') == 'ghostheart5/fantastic-guacamole'
    assert re.fullmatch('[a-f0-9]{40}', args.source)
    assert run('git', 'rev-parse', 'HEAD').strip() == args.source
    assert not run('git', 'status', '--porcelain').strip()
    assert [line for line in run('adb', 'devices').splitlines()[1:] if line.strip()] == [SERIAL+'\tdevice']
    assert shell('getprop', 'ro.kernel.qemu') == '1'
    assert shell('am', 'get-current-user') == '0'
    assert shell('getprop', 'ro.build.version.sdk') == '35'
    args.output.mkdir(parents=True, exist_ok=False)
    c = Capture(args.output, args.locale)
    receipt = {'status': 'failed', 'sourceSha': args.source, 'sourceTree': run('git', 'rev-parse', 'HEAD^{tree}').strip(),
               'workflowSha': os.environ['GITHUB_SHA'], 'runId': os.environ['GITHUB_RUN_ID'],
               'apkSha256': sha(args.apk), 'locale': args.locale,
               'version': re.search(r'^version:\s*(.*)$', Path('pubspec.yaml').read_text(), re.M).group(1),
               'qaDefines': json.loads(Path('tool/qa_defines.json').read_text()),
               'qaDefinesSha256': sha('tool/qa_defines.json'),
               'startedAtUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'boundary': 'Real UI in disposable local QA profile. No cloud account or external AI request; no production acceptance. Media requires visual review before upload.',
               'actions': c.actions, 'screenshots': c.images, 'videos': [], 'uiReadiness': c.ui_readiness}
    recorder = None
    try:
        build_tools = sorted(Path(os.environ['ANDROID_HOME']).glob('build-tools/*/aapt2'))
        assert build_tools
        badging = run(str(build_tools[-1]), 'dump', 'badging', str(args.apk))
        (args.output/'apk-badging.txt').write_text(badging)
        identity = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging, re.M)
        version_name, version_code = receipt['version'].split('+')
        assert identity and identity.groups() == (PACKAGE, version_code, version_name+'-qa')
        receipt['apkIdentity'] = {'package': identity[1], 'versionCode': identity[2], 'versionName': identity[3]}
        sys.path.insert(0, str(Path.cwd()/'scripts'))
        from hosted_guest_anr import classify_anr
        # Passive readiness guard: never inject HOME/MENU or dismiss an ANR.
        receipt['resolvedHomeBeforeSettling'] = shell('cmd', 'package', 'resolve-activity', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.HOME')
        def canonical(component):
            package, activity = component.split('/')
            return package+'/'+(package+activity if activity.startswith('.') else activity)
        stable = 0
        previous_home = None
        receipt['homeSamples'] = []
        for index in range(7):
            window = shell('dumpsys', 'window', 'windows')
            activities = shell('dumpsys', 'activity', 'activities')
            assert not re.search(r"Application (?:Error|Not Responding)|isn.t responding", window, re.I)
            last_anr = shell('dumpsys', 'activity', 'lastanr')
            events = shell('logcat', '-d', '-b', 'events', '-v', 'threadtime')
            for label, value in [('window',window), ('activities',activities), ('lastanr',last_anr), ('anr-events',events)]:
                (args.output/f'home-{index}-{label}.txt').write_text(value)
            anr = classify_anr(last_anr, events, PACKAGE)
            assert not anr['appAnrObserved'], 'Fresh guest has app ANR evidence'
            # Android 35 reports these activity focus fields in the activity
            # dump. The early HOME resolver may still name Setup. Match the
            # actual visible HOME task, as the existing runtime guard does.
            homes = set(re.findall(r'^\s*\* Task\{[^\n]*\btype=home\b[^\n]*\bI=([\w.]+/[\w.$]+)[^\n]*\bU=0\b[^\n]*\bvisible=true\b', activities, re.M))
            home = next(iter(homes)) if len(homes) == 1 else None
            focuses = {canonical(v) for v in re.findall(r'^\s*mCurrentFocus=Window\{[^\n}]*\bu0\s+([\w.]+/[\w.$]+)', activities, re.M)}
            resumed = {canonical(v) for v in re.findall(r'^\s*(?:topResumedActivity=|ResumedActivity:)\s*ActivityRecord\{[^\n}]*\bu0\s+([\w.]+/[\w.$]+)', activities, re.M)}
            focused = home is not None and focuses == {canonical(home)}
            active = home is not None and resumed == {canonical(home)}
            setup = home is not None and home.startswith('com.google.android.googlesdksetup/')
            stable = (stable+1 if home == previous_home else 1) if focused and active and not setup else 0
            previous_home = home
            receipt['homeSamples'].append({'focused': focused, 'resumed': active, 'homeActivity': home,
                                          'focusedActivities': sorted(focuses), 'resumedActivities': sorted(resumed),
                                          'stable': stable, 'anr': anr})
            time.sleep(10)
        assert stable >= 3, 'Guest must already focus HOME without injected input'
        adb('install', str(args.apk))
        assert shell('pm', 'path', PACKAGE).startswith('package:')
        shell('cmd', 'locale', 'set-app-locales', PACKAGE, '--user', '0', '--locales', args.locale)
        receipt['localeReadback'] = shell('cmd', 'locale', 'get-app-locales', PACKAGE, '--user', '0')
        assert args.locale in receipt['localeReadback']
        shell('wm', 'size', '1080x1920')
        shell('wm', 'density', '420')
        shell('am', 'start', '-n', PACKAGE+'/'+ 'com.ghostheart5.chronospark.MainActivity')
        c.profile()
        c.screenshot('diagnostic/00-today-before-demo')
        titles = ['Plan a relaxing evening', 'Read a little each day', 'Make time for walking'] if args.locale == 'en-US' else ['Preparar una tarde tranquila', 'Leer un rato', 'Dedicar tiempo a caminar']
        c.create('task', titles[0], schedule=True)
        c.nav('My plan', 'Mi plan')
        c.tap(r'^(?:Schedule|Agenda)$', scroll=True)
        c.tap(r'^(?:Complete|Completar)$', scroll=True)
        c.wait(r'.*(?:Task Completed|Tarea completada|marcada como completada).*')
        shell('input', 'keyevent', '4')
        c.actions.append({'action': 'back', 'fromObservedScreen': 'Schedule'})
        c.wait(r'^(?:My plan|Mi plan)$')
        c.create('habit', titles[1])
        c.create('goal', titles[2])
        c.create('task', 'Take five quiet minutes' if args.locale == 'en-US' else 'Tomar cinco minutos de calma', schedule=True)
        for form, width, height, density in [('phone',1080,1920,420), ('tablet-7',1200,1920,240), ('tablet',1600,2560,240)]:
            shell('wm', 'size', f'{width}x{height}')
            shell('wm', 'density', str(density))
            c.width, c.height = width, height
            time.sleep(4)
            remote = '/sdcard/'+form+'.mp4'
            recorder = subprocess.Popen(['adb','-s',SERIAL,'shell','screenrecord','--time-limit','180','--bit-rate','6000000',remote])
            c.record_screens(form)
            observed = subprocess.run(['adb','-s',SERIAL,'shell','pidof','screenrecord'], capture_output=True, text=True, timeout=20)
            pid = observed.stdout.strip()
            if pid:
                assert re.fullmatch(r'\d+', pid), 'Expected exactly one owned guest recorder'
                shell('kill', '-2', pid)
            recorder.wait(timeout=15)
            recorder = None
            video = args.output/(form+'-walkthrough.mp4')
            adb('pull', remote, str(video))
            receipt['videos'].append({'path': video.name, 'sha256': sha(video), 'requestedEmulatorPixels': [width,height],
                                      'boundary': 'Unedited real QA capture, bounded to first 180 seconds; may not include the entire screenshot journey. Not yet a polished store video.'})
        assert len([i for i in c.images if not i['path'].startswith('diagnostic/')]) == 21
        receipt['status'] = 'captured-awaiting-visual-review'
    except Exception as error:
        receipt['error'] = str(error)
        try:
            (args.output/'failure.png').write_bytes(adb('exec-out','screencap','-p',binary=True))
            c.tree()
        except Exception:
            pass
        raise
    finally:
        if recorder is not None and recorder.poll() is None:
            recorder.send_signal(signal.SIGINT)
        (args.output/'manifest.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] in {'preserve-apk','seal-apk','verify-reused-apk'}:
        apk_artifact_mode()
    else:
        main()
