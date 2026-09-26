"""Public build inputs and evidence binding; no network or activation actions.

Structured evidence is an operator assertion, not automated professional review.
The independent, non-overridable source gates are also enforced by Dart before
signing. Final artifact acceptance and production activation remain later gates.
"""
import hashlib
import json
from pathlib import Path
import re
import argparse
import subprocess
import sys
from datetime import datetime, timezone, timedelta

PUBLIC_POLICY_PATH = 'tool/public_assistant_release.json'
PUBLIC_POLICY = {
    'assistant_release_stage': 'general',
    'assistant_release_canary_basis_points': 0,
    'assistant_shadow_evaluation_enabled': False,
    'assistant_release_internal_account_digests': '',
    'kill_assistant_smart_planner_v2': False,
    'kill_assistant_si_console_v2': False,
    'kill_assistant_governed_memory': False,
    'kill_assistant_safety_critic': False,
    'kill_assistant_planner_explanation': True,
}
PUBLIC_FLAGS = {
    'CHRONOSPARK_PUBLIC_RELEASE': 'true',
    'CHRONOSPARK_APP_FLAVOR': 'prod',
    'CHRONOSPARK_BACKEND_MODE': 'cloud',
    'CHRONOSPARK_ENFORCE_PROD_READINESS': 'true',
    'CHRONOSPARK_ENABLE_CLOUD_SYNC': 'true',
    'CHRONOSPARK_INTERNAL_BILLING_TEST': 'false',
    'CHRONOSPARK_PUBLIC_CREDIT_ADMISSION_QA': 'false',
    'CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS': '',
    **{name: 'false' for name in (
        'CHRONOSPARK_VERBOSE_LOGS', 'CHRONOSPARK_ENABLE_MOCK_LOGIN',
        'CHRONOSPARK_ENABLE_MOCK_MODE', 'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
        'CHRONOSPARK_PAYWALL_DISABLED', 'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
        'CHRONOSPARK_ENABLE_ANALYTICS', 'CHRONOSPARK_ENABLE_CRASH_REPORTING')},
}
PUBLIC_SETTINGS = (
    'CHRONOSPARK_SUPABASE_URL', 'CHRONOSPARK_SUPABASE_ANON_KEY',
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT', 'CHRONOSPARK_AI_PROXY_ENDPOINT',
    'CHRONOSPARK_AI_REPORT_ENDPOINT', 'CHRONOSPARK_PLANNER_EXPLANATION_ENDPOINT',
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT', 'CHRONOSPARK_ANDROID_SHA256_CERT',
)
SOURCE_CAPABILITIES = (
    'cloudSyncEnabled', 'cloudRestoreEnabled', 'subscriptionsEnabled',
    'externalAiEnabled', 'creditSpendingEnabled',
    'externalAiProviderRetentionVerified', 'externalAiPrivacyReviewApproved',
    'externalAiSafetyReviewApproved',
)
EVIDENCE_GATES = (
    'privacyLegal', 'mentalHealthSafety', 'providerRetention',
    'backendParity', 'cloudIsolationRestoreDeletion', 'billingRecovery',
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def assemble_public_defines(settings, policy):
    require(type(policy) is dict and set(policy) == set(PUBLIC_POLICY) and all(
        type(policy[k]) is type(v) and policy[k] == v for k, v in PUBLIC_POLICY.items()),
        'Public assistant policy differs from the reviewed profile')
    require(all(type(settings.get(k)) is str and settings[k].strip() for k in PUBLIC_SETTINGS),
            'Public service settings are missing')
    return {**PUBLIC_FLAGS, **{k: settings[k] for k in PUBLIC_SETTINGS},
            'CHRONOSPARK_REMOTE_CONFIG_JSON': canonical(policy)}


def validate_public_defines(defines, expected_policy_hash):
    require(type(defines) is dict and set(defines) == set(PUBLIC_FLAGS) | set(PUBLIC_SETTINGS) |
            {'CHRONOSPARK_REMOTE_CONFIG_JSON'}, 'Unknown or missing public build input')
    require(all(type(defines[k]) is str and defines[k] == v for k, v in PUBLIC_FLAGS.items()),
            'Public build cannot contain internal QA, private cohorts or bypasses')
    require(defines['CHRONOSPARK_REMOTE_CONFIG_JSON'] == canonical(PUBLIC_POLICY),
            'Public assistant policy must be the canonical general profile')
    require(all(type(defines[k]) is str and defines[k].strip() for k in PUBLIC_SETTINGS),
            'Public service settings are missing')
    digest = hashlib.sha256(defines['CHRONOSPARK_REMOTE_CONFIG_JSON'].encode()).hexdigest()
    require(expected_policy_hash == digest, 'Reviewed public policy digest mismatch')
    return {'sha256': digest, 'stage': 'general', 'cohortCount': 0,
            'billingCohortCount': 0, 'internalBillingTest': False,
            'creditAdmissionQa': False, 'runtimeFlagsEnabled': False,
            'consentRequired': True, 'rolledBackCapabilities': ['plannerExplanation']}


def validate_source_gates(source):
    for feature in SOURCE_CAPABILITIES:
        require(re.search(rf'static const bool {feature}\s*=\s*true;', source),
                f'Public source gate is not approved: {feature}')
    for feature in ('analyticsEnabled', 'crashReportingEnabled', 'inferredIdentityEnabled'):
        require(re.search(rf'static const bool {feature}\s*=\s*false;', source),
                f'Public profile does not approve: {feature}')


def validate_public_evidence(receipt, directory, source_sha, defines, now=None):
    """Bind operator-reviewed documents to this source and all effective defines.

    Only hashes and receipt IDs are returned for build artifacts. The raw
    reviewer documents remain outside the public build-evidence directory.
    """
    now = now or datetime.now(timezone.utc)
    expected_keys = {'schemaVersion', 'sourceSha', 'definesSha256', 'gates'}
    require(type(receipt) is dict and set(receipt) == expected_keys and
            type(receipt['schemaVersion']) is int and receipt['schemaVersion'] == 1 and
            receipt['sourceSha'] == source_sha and
            re.fullmatch(r'[a-f0-9]{40}', source_sha or ''), 'Public evidence source mismatch')
    fingerprint = hashlib.sha256(canonical(defines).encode()).hexdigest()
    require(receipt['definesSha256'] == fingerprint, 'Public evidence configuration mismatch')
    gates = receipt['gates']
    require(type(gates) is dict and set(gates) == set(EVIDENCE_GATES),
            'Required public review/backend evidence is missing')
    root = Path(directory).resolve()
    verified = {}
    for name in EVIDENCE_GATES:
        gate = gates[name]
        require(type(gate) is dict and set(gate) ==
                {'status', 'scope', 'reviewer', 'reviewedAt', 'validUntil', 'file', 'sha256'},
                'Public gate receipt is incomplete')
        require(gate['status'] == 'approved' and gate['scope'] == 'source-and-configuration' and
                type(gate['reviewer']) is str and bool(gate['reviewer'].strip()),
                f'Public review is not approved: {name}')
        try:
            reviewed = datetime.fromisoformat(gate['reviewedAt'].replace('Z', '+00:00'))
            expires = datetime.fromisoformat(gate['validUntil'].replace('Z', '+00:00'))
            require(reviewed.tzinfo is not None and expires.tzinfo is not None and
                    reviewed <= now < expires, 'Public evidence is future-dated or expired')
            if name in ('backendParity', 'providerRetention'):
                require(now - reviewed <= timedelta(days=7), 'Refresh public backend/provider evidence')
        except (TypeError, AttributeError, ValueError):
            raise ValueError('Public evidence dates are invalid, stale or expired') from None
        require(type(gate['file']) is str and gate['file'] and
                not Path(gate['file']).is_absolute() and '\\' not in gate['file'] and
                ':' not in gate['file'] and '..' not in gate['file'].split('/'),
                'Public evidence must identify a relative file inside its packet')
        path = (root / gate['file']).resolve()
        require(path.is_relative_to(root) and path.is_file(), 'Public evidence file is missing or outside packet')
        require(type(gate['sha256']) is str and re.fullmatch(r'[a-f0-9]{64}', gate['sha256']) and
                hashlib.sha256(path.read_bytes()).hexdigest() == gate['sha256'],
                'Public evidence file digest mismatch')
        verified[name] = {'sha256': gate['sha256'], 'reviewedAt': gate['reviewedAt'],
                          'validUntil': gate['validUntil']}
    return {'sourceSha': source_sha, 'definesSha256': fingerprint, 'gates': verified,
            'boundary': 'Operator-reviewed pre-build evidence; not final artifact or rollout approval'}


def strict_json(text):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'Duplicate public configuration key')
            result[key] = value
        return result
    try:
        return json.loads(text, object_pairs_hook=pairs,
                          parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
    except (ValueError, TypeError):
        raise ValueError('Invalid public JSON configuration') from None


def prepare(root, defines_path, evidence_path):
    root = root.resolve()
    # This check deliberately comes before configuration, review-file reads or
    # any signing operation. There is no override flag for pending reviews.
    validate_source_gates((root/'lib/config/launch_containment.dart').read_text(encoding='utf-8'))
    source_sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    require(not subprocess.check_output(['git','status','--porcelain','--untracked-files=all'],
                                       cwd=root, text=True).strip(), 'Public build source must be clean')
    require(not defines_path.resolve().is_relative_to(root), 'Public defines must be outside source checkout')
    settings = strict_json(defines_path.read_text(encoding='utf-8-sig'))
    base = settings.get('CHRONOSPARK_SUPABASE_URL', '').rstrip('/')
    settings.update({'CHRONOSPARK_AI_REPORT_ENDPOINT': base+'/functions/v1/ai-report',
                     'CHRONOSPARK_PLANNER_EXPLANATION_ENDPOINT': base+'/functions/v1/planner-explanation'})
    policy = strict_json((root/PUBLIC_POLICY_PATH).read_text(encoding='utf-8'))
    defines = assemble_public_defines(settings, policy)
    validate_public_defines(defines, hashlib.sha256(canonical(policy).encode()).hexdigest())
    evidence = strict_json(evidence_path.read_text(encoding='utf-8'))
    receipt = validate_public_evidence(evidence, evidence_path.parent, source_sha, defines)
    defines_path.write_text(canonical(defines), encoding='utf-8')
    require(strict_json(defines_path.read_text(encoding='utf-8')) == defines, 'Public defines readback failed')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--check-source', action='store_true')
    parser.add_argument('--defines', type=Path)
    parser.add_argument('--evidence', type=Path)
    args = parser.parse_args()
    if args.check_source:
        validate_source_gates((args.root/'lib/config/launch_containment.dart').read_text(encoding='utf-8'))
        print('Public source gates are recorded; final artifact and activation remain separate.')
    else:
        require(args.defines is not None and args.evidence is not None,
                'Explicit defines and reviewed evidence packet are required')
        print(canonical(prepare(args.root, args.defines, args.evidence)))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(str(error) if type(error) is ValueError else
              'Public release preflight failed; input details suppressed.', file=sys.stderr)
        sys.exit(1)
