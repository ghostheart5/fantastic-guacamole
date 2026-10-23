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
import struct
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

PACKAGE = 'com.ghostheart5.chronospark.qa'
SERIAL = 'emulator-5554'
RETIRED = re.compile(r'\b(?:Nexus Core|Smart Planner|Trajectory Engine|Truth Ledger|Reality Builder|Capability Matrix|Deep Intelligence|Control Center|Daily Rhythms)\b', re.I)


def run(*args, binary=False, timeout=40):
    return subprocess.check_output(args, timeout=timeout, text=not binary)


def adb(*args, binary=False):
    return run('adb', '-s', SERIAL, *args, binary=binary)


def shell(*args):
    return adb('shell', *args).strip()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class Capture:
    def __init__(self, output, locale):
        self.output, self.locale = output, locale
        self.width, self.height = 1080, 1920
        self.actions = []
        self.images = []
        self.frames = 0

    def tree(self):
        shell('uiautomator', 'dump', '/sdcard/window.xml')
        xml = adb('exec-out', 'cat', '/sdcard/window.xml')
        tree = ET.fromstring(xml)
        self.frames += 1
        (self.output / f'ui-{self.frames:04d}.xml').write_text(xml, encoding='utf-8')
        visible = '\n'.join(n.get('text', '') + '\n' + n.get('content-desc', '') for n in tree.iter('node'))
        assert not re.search(r"isn.t responding|Application Error|keeps stopping", visible, re.I), visible
        return tree

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
        self.tap(r'^(?:Browse tools|Ver herramientas)$')
        self.tap(r'^(?:'+re.escape(en)+'|'+re.escape(es)+r')(?:\n.*)?$', scroll=True)
        self.wait(r'^(?:'+re.escape(en)+'|'+re.escape(es)+r')$')

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
                            r'^(?:Go to Today|Ir a Hoy|SKIP FOR NOW|OMITIR POR AHORA)$',
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
        if kind != 'task':
            self.tap(r'^(?:Task|Tarea)$', scroll=True)
            en, es = names[kind]
            self.tap(r'^(?:'+en+'|'+es+')$')
        self.tap(r'^(?:Title, required|Título, obligatorio)(?:\s+Title \*|\s+Título \*)?$', scroll=True)
        assert title.isascii(), 'ADB input text is deliberately limited to ASCII demo names'
        shell('input', 'text', title.replace(' ', '%s'))
        shell('input', 'keyevent', '111')
        if schedule:
            self.tap(r'^(?:Task options \(optional\)|Opciones de la tarea \(opcional\)).*', scroll=True)
            self.tap(r'^(?:Schedule date and time|Elegir fecha y hora)\.\.\.$', scroll=True)
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
               'actions': c.actions, 'screenshots': c.images, 'videos': []}
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
        home = shell('cmd', 'package', 'resolve-activity', '--brief', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.HOME').splitlines()[-1].split('/')[0]
        stable = 0
        receipt['homeSamples'] = []
        for _ in range(7):
            window = shell('dumpsys', 'window', 'windows')
            assert not re.search(r"Application (?:Error|Not Responding)|isn.t responding", window, re.I)
            last_anr = shell('dumpsys', 'activity', 'lastanr')
            events = shell('logcat', '-d', '-b', 'events', '-v', 'threadtime')
            anr = classify_anr(last_anr, events, PACKAGE)
            assert not anr['appAnrObserved'], 'Fresh guest has app ANR evidence'
            focused = bool(re.search(r'mCurrentFocus=.*'+re.escape(home), window))
            stable = stable+1 if focused else 0
            receipt['homeSamples'].append({'focused': focused, 'stable': stable, 'anr': anr})
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
        assert len(c.images) == 21
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
    main()
