"""Supported Flutter Android instrumentation, with raw, fail-closed evidence.

This harness lives in tooling and is added only by an explicit debug Gradle init
script. It does not edit the candidate checkout or alter the released AAB.
"""
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

TEST_CLASS = 'com.ghostheart5.chronospark.ChronoSparkInstrumentationTest'
COMPONENT = 'com.ghostheart5.chronospark.test/androidx.test.runner.AndroidJUnitRunner'
SCHEMA = 'android-instrumentation-v1'


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def parse_report(raw, expected):
    """Count actual FlutterTestRunner JUnit results, never discovered test counts.

    Flutter's custom runner discovers one Java container but reports each Dart
    test separately. Android's numtests field is consequently not authoritative.
    Every named result must have exactly one start and one successful finish.
    """
    fields, started, completed, active, terminal = {}, set(), [], None, []
    for line in raw.splitlines():
        if line.startswith('INSTRUMENTATION_STATUS: '):
            require(not terminal, 'Status appeared after instrumentation completion')
            key, separator, value = line[len('INSTRUMENTATION_STATUS: '):].partition('=')
            require(separator, 'Malformed instrumentation status')
            if key in ('class', 'test'):
                require(key not in fields and value.strip(), 'Missing or duplicate test identity')
                fields[key] = value
        elif line.startswith('INSTRUMENTATION_STATUS_CODE: '):
            require(not terminal, 'Status code appeared after completion')
            code = line[len('INSTRUMENTATION_STATUS_CODE: '):]
            require(code in ('1', '0'), 'Failed, errored, skipped or unknown instrumentation status')
            require(fields.get('class') == TEST_CLASS and fields.get('test'), 'Unexpected test identity')
            name = fields['test']
            if code == '1':
                require(active is None and name not in started, 'Duplicate or overlapping test start')
                started.add(name)
                active = name
            else:
                require(active == name, 'Test completion has no matching start')
                completed.append(name)
                active = None
            fields = {}
        elif line.startswith('INSTRUMENTATION_CODE: '):
            terminal.append(line[len('INSTRUMENTATION_CODE: '):])
        elif line.startswith(('INSTRUMENTATION_FAILED:', 'INSTRUMENTATION_ABORTED:')):
            raise RuntimeError('Instrumentation failed or aborted')
    require(terminal == ['-1'] and not fields and active is None,
            'Missing, repeated or unsuccessful instrumentation terminal completion')
    require(len(completed) == expected and len(started) == expected,
            'Maintained native test count changed or tests were omitted')
    summaries = re.findall(r'^OK \((\d+) tests?\)\s*$', raw, re.MULTILINE)
    require(summaries == [str(expected)], 'JUnit terminal summary disagrees with completed tests')
    return {'totals': {'total': expected, 'passed': expected, 'failed': 0, 'error': 0, 'skipped': 0},
            'completedTestNames': completed}


def prepare(commands, source, tooling, filename):
    source, tooling = Path(source).resolve(), Path(tooling).resolve()
    target = source / 'integration_test' / filename
    harness = tooling / 'scripts/native_instrumentation'
    require(target.is_file() and target.parent == source / 'integration_test', 'Missing maintained native target')
    require((harness / 'harness.gradle').is_file(), 'Missing instrumentation harness')
    output = source / 'build/chronospark-native-fixture'
    require(not output.exists(), 'Native preparation output must be fresh')
    output.mkdir(parents=True)
    commands.run('compile-native-dependencies', ['flutter', 'build', 'apk', '--debug', '--no-pub',
                 '--target-platform', 'android-x64', '--target', 'integration_test/' + filename],
                 cwd=source, timeout=1200)
    commands.run('compile-instrumentation-harness', ['bash', './gradlew', '--no-daemon',
                 '--init-script', str(harness / 'harness.gradle'), ':app:assembleDebug', ':app:assembleAndroidTest',
                 '-Ptarget=' + str(target), '-Ptarget-platform=android-x64',
                 '-PchronosparkInstrumentationSource=' + str(harness / 'java')],
                 cwd=source / 'android', timeout=600)
    receipt = {'schema': SCHEMA, 'file': filename, 'targetSha256': sha256(target), 'apks': {}}
    for name, path in {'app.apk': source / 'build/app/outputs/apk/debug/app-debug.apk',
                       'test.apk': source / 'build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk'}.items():
        require(path.is_file() and zipfile.is_zipfile(path), 'Instrumentation APK is missing or invalid')
        shutil.copyfile(path, output / name)
        receipt['apks'][name] = {'sha256': sha256(output / name), 'bytes': path.stat().st_size}
    (output / 'prepared.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


def execute(commands, source, adb, filename, expected, label):
    require(len(adb) >= 3 and adb[-2] == '-s' and
            re.fullmatch(r'emulator-(5554|5586|5588|5590|5592|5594)', adb[-1]),
            'Instrumentation installs require the owned emulator')
    directory = Path(source) / 'build/chronospark-native-fixture'
    prepared = json.loads((directory / 'prepared.json').read_text(encoding='utf-8'))
    require(prepared.get('schema') == SCHEMA and prepared.get('file') == filename and
            prepared.get('targetSha256') == sha256(Path(source) / 'integration_test' / filename),
            'Prepared APK target differs from the maintained test')
    for name in ('app.apk', 'test.apk'):
        path = directory / name
        require(sha256(path) == prepared['apks'][name]['sha256'], 'Prepared APK bytes changed')
        commands.run('install-fixture-' + name, adb + ['install', '-t', str(path)], timeout=90)
    raw = commands.run(label, adb + ['shell', 'am', 'instrument', '-w', '-r', '-e', 'class', TEST_CLASS,
                                  COMPONENT], timeout=900, check=False)
    record = commands.records[-1]
    require(record['exitCode'] == 0 and not record.get('timedOut') and not record.get('launchFailed'),
            'Android instrumentation command did not complete successfully')
    result = parse_report(raw, expected)
    report = commands.evidence / (label + '.log')
    manifest = {'schema': SCHEMA, 'passed': True, 'runnerExitCode': 0, **result,
                'rawReportSha256': sha256(report), 'prepared': prepared}
    (commands.evidence / (label + '-instrumentation.json')).write_text(
        json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return result


def verify_evidence(directory, label, filename, expected):
    directory = Path(directory)
    path = directory / (label + '-instrumentation.json')
    receipt = json.loads(path.read_text(encoding='utf-8'))
    raw = directory / (label + '.log')
    require(receipt.get('schema') == SCHEMA and receipt.get('passed') is True and
            receipt.get('runnerExitCode') == 0 and receipt.get('rawReportSha256') == sha256(raw),
            'Instrumentation receipt or raw report identity differs')
    result = parse_report(raw.read_text(encoding='utf-8'), expected)
    require(all(receipt.get(key) == value for key, value in result.items()), 'Instrumentation result differs from raw report')
    prepared = receipt.get('prepared', {})
    require(prepared.get('schema') == SCHEMA and prepared.get('file') == filename and
            re.fullmatch(r'[a-f0-9]{64}', prepared.get('targetSha256', '')),
            'Instrumentation preparation identity is missing')
    require(set(prepared.get('apks', {})) == {'app.apk', 'test.apk'} and all(
        re.fullmatch(r'[a-f0-9]{64}', entry.get('sha256', '')) and type(entry.get('bytes')) is int and entry['bytes'] > 0
        for entry in prepared['apks'].values()), 'Prepared APK hashes are missing')
    return result
