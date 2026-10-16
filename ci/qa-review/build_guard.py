"""UNEXECUTED proposal: manual clearance binding and public APK identity checks.

Storage validation checks an external reviewed attestation, not GitHub billing.
Only the future 'apk' mode invokes SDK verification; no build/install/device calls.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from datetime import datetime, timedelta, timezone

PACKAGE = 'com.ghostheart5.chronospark.qa.review20261016'
ACTIVITY = 'com.ghostheart5.chronospark.MainActivity'
SCHEME = 'chronospark-qa-review20261016'
ANDROID = '{http://schemas.android.com/apk/res/android}'
CONTENTS = 199 * 1024**2
RESERVATION = 200 * 1024**2


def need(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def manifest(payload):
    path = payload / 'ci/qa-review/candidate-manifest.json'
    need(sha(path) == os.environ['MANIFEST_SHA256'], 'Manifest digest mismatch')
    return json.loads(path.read_text(encoding='utf-8'))


def instant(value):
    need(type(value) is str, 'UTC timestamp required')
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    need(result.tzinfo is not None and result.utcoffset() == timedelta(0), 'UTC required')
    return result


def clearance(m):
    raw = os.environ.get('STORAGE_CLEARANCE_JSON', '').encode('utf-8')
    expected = os.environ.get('STORAGE_CLEARANCE_SHA256', '')
    need(0 < len(raw) <= 8192 and re.fullmatch('[a-f0-9]{64}', expected), 'Reviewed clearance input required')
    need(hashlib.sha256(raw).hexdigest() == expected, 'Clearance exact-byte hash mismatch')
    value = json.loads(raw)
    need(type(value) is dict, 'Clearance object required')
    required = {
        'schemaVersion': 1,
        'decision': 'CLEARED_NO_ADDITIONAL_CHARGE',
        'repository': 'ghostheart5/fantastic-guacamole',
        'sourceManifestSha256': os.environ['MANIFEST_SHA256'],
        'sourceStackSha256': m['sourceStackSha256'],
        'workflowSha': os.environ['WORKFLOW_SHA'],
        'applicationId': PACKAGE,
        'artifactContentsLimitBytes': CONTENTS,
        'artifactZipReservationBytes': RESERVATION,
        'retentionDays': 1,
        'maximumRuns': 1,
        'jobTimeoutMinutes': 40,
        'capacityVerified': True,
        'noAdditionalCharge': True,
        'ownerApproved': True,
        'noCacheUploads': True,
        'allowEphemeralDebugSigningForDistinctFixture': True,
        'allowExactNdkProvisionWithExistingLicensesOnly': True,
    }
    for key, expected_value in required.items():
        need(type(value.get(key)) is type(expected_value) and value[key] == expected_value, 'Unverified/mismatched clearance: ' + key)
    for key in ('capacityEvidenceSha256', 'independentReviewSha256'):
        need(type(value.get(key)) is str and re.fullmatch('[a-f0-9]{64}', value[key]), 'Missing external reviewed evidence: ' + key)
    need(re.fullmatch('Sentinel_[A-Za-z0-9]+', value.get('ownerApprovalReference', '')), 'Exact new owner authorization reference required')
    now = datetime.now(timezone.utc)
    reviewed = instant(value.get('reviewedAtUtc'))
    expires = instant(value.get('validUntilUtc'))
    covered = instant(value.get('storageCoveredThroughUtc'))
    need(timedelta(0) <= now - reviewed <= timedelta(hours=2), 'Clearance not freshly reviewed')
    need(now < expires <= reviewed + timedelta(hours=2), 'Clearance expired or excessively valid')
    # Reserve the entire future retention even at the pre-upload recheck.
    need(covered >= now + timedelta(days=1, minutes=40), 'Clearance does not cover complete reserved retention')
    print(json.dumps({'manualClearanceDigest': expected, 'externalManualProofRequired': True, 'mechanicalAttestationChecksPassed': True, 'accountBillingApiQueried': False, 'reservationBytes': RESERVATION, 'retentionDays': 1}), flush=True)
    return expected


def sdk_paths():
    sdk = Path(os.environ['ANDROID_HOME']).resolve()
    need((sdk / 'platforms/android-36/android.jar').is_file(), 'Preinstalled platform36 required')
    need((sdk / 'ndk/28.2.13676358/source.properties').is_file(), 'Preinstalled exact NDK required; no SDK/license install fallback')
    candidates = [p for p in (sdk / 'build-tools').iterdir() if re.fullmatch(r'\d+\.\d+\.\d+', p.name) and (p / 'aapt2').is_file() and (p / 'apksigner').is_file()]
    need(bool(candidates), 'Preinstalled Android verification tools required')
    tools = max(candidates, key=lambda p: tuple(map(int, p.name.split('.'))))
    need(int(tools.name.split('.')[0]) >= 36, 'Build-tools36 or later required')
    analyzer = sdk / 'cmdline-tools/latest/bin/apkanalyzer'
    need(analyzer.is_file(), 'Preinstalled apkanalyzer required; no tool-download fallback')
    return tools / 'aapt2', tools / 'apksigner', analyzer


def provision_exact_ndk():
    sdk = Path(os.environ['ANDROID_HOME']).resolve()
    revision = sdk / 'ndk/28.2.13676358/source.properties'
    if revision.is_file():
        need(re.search(r'^Pkg.Revision\s*=\s*28\.2\.13676358\s*$', revision.read_text(), re.M), 'Unexpected preinstalled NDK revision')
        print(json.dumps({'exactNdkAlreadyPresent': True, 'provisionInvoked': False}), flush=True)
        return
    available = next(int(line.split()[1]) * 1024 for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemAvailable:'))
    need(available >= 6 * 1024**3 and shutil.disk_usage(sdk).free >= 8 * 1024**3, 'NDK provision resource floor not met')
    manager = sdk / 'cmdline-tools/latest/bin/sdkmanager'
    need(manager.is_file() and (sdk / 'licenses/android-sdk-license').is_file(), 'Existing SDK manager and preaccepted license required; no license grant fallback')
    print(json.dumps({'sdkmanagerSha256': sha(manager), 'package': 'ndk;28.2.13676358', 'stdin': 'DEVNULL', 'timeoutSeconds': 240, 'newLicenseAcceptanceAllowed': False}), flush=True)
    result = subprocess.run([str(manager), '--install', 'ndk;28.2.13676358'], stdin=subprocess.DEVNULL, capture_output=True, timeout=240, env=dict(os.environ, JAVA_TOOL_OPTIONS='-Xmx256m'))
    need(len(result.stdout) <= 1024**2 and len(result.stderr) <= 1024**2, 'Oversized SDK manager report')
    output = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    print('::group::Exact NDK provision with preaccepted licenses only', flush=True)
    print(output, flush=True)
    print('::endgroup::', flush=True)
    need(result.returncode == 0 and re.search(r'accept\s*\?|accept.*licenses?|licenses?.*(?:not accepted|unaccepted)|review.*licenses?|do you (?:accept|wish)', output, re.I) is None, 'SDK license prompt/nonzero; STOP, no yes/--licenses/retry')
    need(revision.is_file() and re.search(r'^Pkg.Revision\s*=\s*28\.2\.13676358\s*$', revision.read_text(), re.M), 'Exact provisioned NDK revision absent')
    print(json.dumps({'exactNdkProvisioned': True, 'provisionInvoked': True, 'exitCode': result.returncode, 'licenseAcceptancePerformed': False}), flush=True)


def sdk_run(command):
    env = dict(os.environ, JAVA_TOOL_OPTIONS='-Xmx128m -XX:MaxMetaspaceSize=128m')
    result = subprocess.run([str(x) for x in command], capture_output=True, timeout=90, env=env)
    need(len(result.stdout) <= 1024**2 and len(result.stderr) <= 1024**2, 'Oversized SDK report')
    print('::group::SDK ' + Path(command[0]).name, flush=True)
    print(result.stdout.decode('utf-8'), flush=True)
    print(result.stderr.decode('utf-8'), flush=True)
    print('::endgroup::', flush=True)
    need(result.returncode == 0, 'SDK identity verification failed: ' + Path(command[0]).name)
    return result.stdout.decode('utf-8')


def verify_exported_components(app):
    # Existing pinned plugin/library receivers; this changes no Android declaration.
    receivers = {
        'io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver',
        'com.google.firebase.iid.FirebaseInstanceIdReceiver',
    }
    exported = [x for x in app
                if x.tag in ('activity', 'activity-alias', 'service', 'receiver', 'provider')
                and x.get(ANDROID + 'exported') == 'true']
    pairs = [(x.tag, x.get(ANDROID + 'name')) for x in exported]
    expected = {('activity', ACTIVITY)} | {('receiver', name) for name in receivers}
    need(len(pairs) == 3 and len(set(pairs)) == 3 and set(pairs) == expected,
         'Unexpected, missing or duplicate exported component')
    for component in exported:
        if component.tag != 'receiver':
            need(component.get(ANDROID + 'permission') is None,
                 'Unexpected launcher permission')
            continue
        need(component.get(ANDROID + 'permission') == 'com.google.android.c2dm.permission.SEND',
             'Exported FCM receiver lost exact sender permission')
        need(component.get(ANDROID + 'enabled', 'true') == 'true'
             and component.get(ANDROID + 'directBootAware', 'false') == 'false',
             'Exported FCM receiver enabled/direct-boot contract changed')
        filters = component.findall('intent-filter')
        need(len(filters) == 1
             and [x.get(ANDROID + 'name') for x in filters[0].findall('action')]
                 == ['com.google.android.c2dm.intent.RECEIVE']
             and not filters[0].findall('category') and not filters[0].findall('data'),
             'Exported FCM receiver intent contract changed')


def verify_apk(source, evidence, m):
    aapt, signer, analyzer = sdk_paths()
    apk = source / 'build/app/outputs/flutter-apk/app-debug.apk'
    need(apk.is_file() and not apk.is_symlink() and 0 < apk.stat().st_size <= CONTENTS, 'APK absent, symlinked or exceeds contents cap')
    print(json.dumps({'compiledApkSha256': sha(apk), 'bytes': apk.stat().st_size, 'nativeAcceptance': False, 'uploadNotYetAllowed': True}), flush=True)
    need(not (source / 'android/key.properties').exists(), 'Unexpected signing configuration')
    badging = sdk_run([aapt, 'dump', 'badging', apk])
    package = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging, re.M)
    need(package and package.groups() == (PACKAGE, '2026101201', '4.2.4-qa'), 'Wrong package/version')
    permissions = sorted(set(re.findall(r"^uses-permission(?:-sdk-\d+)?: name='([^']+)'", badging, re.M)))
    need(permissions == m['expectedPermissionNames'], 'Permission declaration set changed')
    xml_text = sdk_run([analyzer, 'manifest', 'print', apk])
    need('<!DOCTYPE' not in xml_text and '<!ENTITY' not in xml_text, 'Unexpected XML entities')
    root = ET.fromstring(xml_text)
    need(root.get('package') == PACKAGE and root.get(ANDROID + 'sharedUserId') is None, 'Wrong manifest identity/shared UID')
    uses = root.find('uses-sdk')
    need(uses is not None and uses.get(ANDROID + 'minSdkVersion') == '24' and uses.get(ANDROID + 'targetSdkVersion') == '36', 'SDK bounds changed')
    app = root.find('application')
    need(app is not None and app.get(ANDROID + 'label') == 'Axiomara QA Review 1016' and app.get(ANDROID + 'debuggable') == 'true', 'Wrong label or debug mode')
    need(app.get(ANDROID + 'testOnly', 'false') == 'false' and app.get(ANDROID + 'allowBackup') == 'false', 'Unexpected testOnly/backup')
    metadata = {x.get(ANDROID + 'name'): x.get(ANDROID + 'value') for x in app.findall('meta-data')}
    for key, value in {'chronospark.backend_mode': 'local', 'io.flutter.automatically-register-plugins': 'false', 'firebase_analytics_collection_enabled': 'false', 'firebase_messaging_auto_init_enabled': 'false', 'firebase_crashlytics_collection_enabled': 'false'}.items():
        need(metadata.get(key) == value, 'Wrong local/telemetry manifest metadata: ' + key)
    verify_exported_components(app)
    launchers = []
    schemes = []
    for activity in app.findall('activity'):
        for intent in activity.findall('intent-filter'):
            actions = {x.get(ANDROID + 'name') for x in intent.findall('action')}
            categories = {x.get(ANDROID + 'name') for x in intent.findall('category')}
            if 'android.intent.action.MAIN' in actions and 'android.intent.category.LAUNCHER' in categories:
                launchers.append(activity.get(ANDROID + 'name'))
            for data in intent.findall('data'):
                if data.get(ANDROID + 'scheme'):
                    schemes.append((data.get(ANDROID + 'scheme'), data.get(ANDROID + 'host')))
    need(launchers == [ACTIVITY] and schemes == [(SCHEME, 'auth-callback')], 'Launcher or isolated auth scheme changed')
    authorities = []
    for provider in app.findall('provider'):
        names = provider.get(ANDROID + 'authorities', '').split(';')
        need(all(x.startswith(PACKAGE + '.') for x in names), 'Provider authority is not review-package scoped')
        authorities.extend(names)
        need(provider.get(ANDROID + 'exported', 'false') == 'false', 'Exported provider')
    need(len(authorities) == len(set(authorities)), 'Duplicate provider authority')
    signature = sdk_run([signer, 'verify', '--verbose', '--print-certs', apk])
    need(re.search(r'^Number of signers: 1\s*$', signature, re.M), 'Exactly one signer required')
    certs = re.findall(r'^(?:Signer #1|V2 Signer:) certificate SHA-256 digest: ([A-Fa-f0-9]{64})\s*$', signature, re.M)
    need(len(certs) == 1 and re.search(r'^(?:Signer #1|V2 Signer:) certificate DN: .*\bCN=Android Debug\b', signature, re.M), 'One actual Android Debug certificate required')
    need('Verified using v2 scheme (APK Signature Scheme v2): true' in signature, 'APK v2 verification required')
    with zipfile.ZipFile(apk) as archive:
        need(archive.testzip() is None, 'APK ZIP CRC failure')
        names = archive.namelist()
        engines = sorted({n.split('/')[1] for n in names if re.fullmatch(r'lib/[^/]+/libflutter\.so', n)})
        abis = sorted({n.split('/')[1] for n in names if re.fullmatch(r'lib/[^/]+/[^/]+\.so', n)})
    need(engines == ['arm64-v8a'] and set(abis) <= {'arm64-v8a', 'armeabi-v7a', 'x86_64'}, 'Unexpected engine/native ABI')
    upload = evidence / 'upload'
    need(not upload.exists(), 'Upload preparation is one-shot')
    upload.mkdir()
    shutil.copyfile(apk, upload / 'app-debug.apk')
    digest = sha(apk)
    need(sha(upload / 'app-debug.apk') == digest, 'Upload APK copy changed')
    receipt = {'sourceCommit': m['sourceCommit'], 'sourceStackSha256': m['sourceStackSha256'], 'composedTreeGitSha1': m['composedTreeGitSha1'], 'workflowCommit': os.environ['WORKFLOW_SHA'], 'runId': os.environ['GITHUB_RUN_ID'], 'runAttempt': 1, 'package': PACKAGE, 'versionName': '4.2.4-qa', 'versionCode': 2026101201, 'sha256': digest, 'bytes': apk.stat().st_size, 'signerSha256': certs[0].lower(), 'signatureVerified': True, 'flutterEngineAbis': engines, 'nativeAbis': abis, 'providerAuthorities': authorities, 'permissions': permissions, 'samePackageEarnedQaUpdated': False, 'nativeAcceptance': False, 'toolsSha256': {str(p): sha(p) for p in (aapt, signer, analyzer)}}
    (evidence / 'apk-identity.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['storage', 'provision', 'prerequisites', 'apk', 'upload'])
    parser.add_argument('--payload', required=True, type=Path)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--evidence', required=True, type=Path)
    args = parser.parse_args()
    m = manifest(args.payload)
    need(os.environ['RUN_ATTEMPT'] == '1' and os.environ['WORKFLOW_SHA_INPUT'] == os.environ['WORKFLOW_SHA'] == os.environ['GITHUB_SHA'], 'Workflow/run binding changed')
    if args.mode in ('storage', 'upload'):
        clearance(m)
    if args.mode == 'provision':
        clearance(m)
        provision_exact_ndk()
    if args.mode == 'prerequisites':
        sdk_paths()
        need(not (args.source / 'android/key.properties').exists(), 'Unexpected signing configuration')
        print(json.dumps({'preinstalledSdkPrerequisites': True, 'sdkExecuted': False}))
    if args.mode == 'apk':
        verify_apk(args.source, args.evidence, m)
    if args.mode == 'upload':
        identity = json.loads((args.evidence / 'apk-identity.json').read_text())
        upload = args.evidence / 'upload'
        files = list(upload.iterdir())
        need(len(files) == 1 and files[0].name == 'app-debug.apk' and files[0].is_file() and not files[0].is_symlink(), 'APK-only upload required')
        need(0 < files[0].stat().st_size <= CONTENTS and sha(files[0]) == identity['sha256'], 'Upload hash/size changed')
        need(identity['package'] == PACKAGE and identity['sourceStackSha256'] == m['sourceStackSha256'] and identity['workflowCommit'] == os.environ['WORKFLOW_SHA'] and identity['runId'] == os.environ['GITHUB_RUN_ID'], 'Upload identity chain mismatch')
        print(json.dumps({'uploadAllowed': True, 'artifactContentsBytes': files[0].stat().st_size, 'reservedZipBytes': RESERVATION, 'retentionDays': 1, 'privateKeyIncluded': False}))


if __name__ == '__main__':
    main()
