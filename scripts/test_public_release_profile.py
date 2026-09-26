import copy
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from public_release_profile import (
    PUBLIC_FLAGS, PUBLIC_POLICY, PUBLIC_SETTINGS, SOURCE_CAPABILITIES,
    EVIDENCE_GATES, assemble_public_defines, canonical, prepare, strict_json,
    validate_public_defines, validate_public_evidence, validate_source_gates,
)


class PublicProfileTests(unittest.TestCase):
    def setUp(self):
        self.defines = assemble_public_defines(
            {key: 'synthetic-setting' for key in PUBLIC_SETTINGS}, PUBLIC_POLICY)
        self.policy_hash = hashlib.sha256(canonical(PUBLIC_POLICY).encode()).hexdigest()
        self.source_sha = 'a'*40
        self.now = datetime(2026, 9, 26, tzinfo=timezone.utc)
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        (self.root/'review.txt').write_text('Synthetic reviewer fixture; never production approval.')
        self.evidence = {
            'schemaVersion': 2, 'sourceSha': self.source_sha,
            'definesSha256': hashlib.sha256(canonical(self.defines).encode()).hexdigest(),
            'gates': {name: {
                'status': 'approved', 'scope': 'source-and-configuration',
                'reviewer': 'Release owner - synthetic test fixture',
                'reviewedAt': (self.now-timedelta(hours=1)).isoformat(),
                'validUntil': (self.now+timedelta(days=1)).isoformat(),
                'file': 'review.txt',
                'sha256': hashlib.sha256((self.root/'review.txt').read_bytes()).hexdigest(),
            } for name in EVIDENCE_GATES},
        }

    def validate(self, receipt=None, defines=None):
        return validate_public_evidence(receipt or self.evidence, self.root,
            self.source_sha, defines or self.defines, self.now)

    def test_public_profile_has_no_test_cohort_or_bypasses(self):
        result = validate_public_defines(self.defines, self.policy_hash)
        self.assertEqual(result['stage'], 'general')
        self.assertFalse(result['internalBillingTest'])
        for key in PUBLIC_FLAGS:
            altered = {**self.defines, key: 'true' if self.defines[key] != 'true' else 'false'}
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_public_defines(altered, self.policy_hash)
        with self.assertRaises(ValueError):
            validate_public_defines({**self.defines, 'BYPASS': 'true'}, self.policy_hash)

    def test_private_and_drifted_assistant_policies_are_rejected(self):
        for key in PUBLIC_POLICY:
            bad = {**PUBLIC_POLICY, key: 'internal'}
            with self.subTest(key=key), self.assertRaises(ValueError):
                assemble_public_defines({k:'synthetic' for k in PUBLIC_SETTINGS}, bad)
        with self.assertRaises(ValueError):
            assemble_public_defines({k:'synthetic' for k in PUBLIC_SETTINGS},
                {**PUBLIC_POLICY, 'assistant_release_canary_basis_points': False})
        with self.assertRaises(ValueError):
            validate_public_defines(self.defines, '0'*64)

    def test_review_documents_are_bound_to_source_and_every_define(self):
        result = self.validate()
        self.assertEqual(len(result['gates']), 6)
        self.assertNotIn('reviewer', canonical(result))
        for field, wrong in [('sourceSha','b'*40),('definesSha256','0'*64),('schemaVersion',True)]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.validate({**self.evidence, field:wrong})
        with self.assertRaises(ValueError):
            self.validate(defines={**self.defines,'CHRONOSPARK_SUPABASE_URL':'https://another.invalid'})

    def test_each_missing_or_unaccepted_validation_blocks_build(self):
        for name in EVIDENCE_GATES:
            bad = copy.deepcopy(self.evidence)
            del bad['gates'][name]
            with self.subTest(missing=name), self.assertRaises(ValueError):
                self.validate(bad)
            for field, wrong in [('status','pending'),('reviewer',''),('scope','preliminary'),
                                 ('sha256','0'*64),('file','missing.txt')]:
                bad = copy.deepcopy(self.evidence)
                bad['gates'][name][field] = wrong
                with self.subTest(gate=name,field=field), self.assertRaises(ValueError):
                    self.validate(bad)

    def test_expired_future_stale_and_naive_dates_are_rejected(self):
        for field, wrong in [
            ('reviewedAt',(self.now+timedelta(hours=1)).isoformat()),
            ('reviewedAt',(self.now-timedelta(days=8)).isoformat()),
            ('validUntil',self.now.isoformat()),
            ('reviewedAt','2026-09-25T00:00:00'),('validUntil',None)]:
            bad = copy.deepcopy(self.evidence)
            bad['gates']['backendParity'][field] = wrong
            with self.subTest(field=field,wrong=wrong), self.assertRaises(ValueError):
                self.validate(bad)

    def test_packet_paths_and_modified_review_bytes_fail_closed(self):
        for path in ['../review.txt', '/review.txt', 'C:/review.txt', '..\\review.txt', 'review.txt:stream']:
            bad = copy.deepcopy(self.evidence)
            bad['gates']['privacyDisclosureValidation']['file'] = path
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.validate(bad)
        (self.root/'review.txt').write_text('Changed after review')
        with self.assertRaises(ValueError):
            self.validate()

    def test_source_gate_never_accepts_missing_approval(self):
        source = '\n'.join(f'static const bool {name} = true;' for name in SOURCE_CAPABILITIES)
        source += '\n'+'\n'.join(f'static const bool {name} = false;' for name in
                                 ['analyticsEnabled','crashReportingEnabled','inferredIdentityEnabled'])
        validate_source_gates(source)
        for name in SOURCE_CAPABILITIES:
            with self.subTest(name=name), self.assertRaises(ValueError):
                validate_source_gates(source.replace(f'{name} = true;', f'{name} = false;'))

    def test_owner_validation_accepted_without_professional_certificate(self):
        self.assertEqual(len(self.validate()['gates']), 6)
        legacy = copy.deepcopy(self.evidence)
        legacy['schemaVersion'] = 1
        legacy['gates']['privacyLegal'] = legacy['gates'].pop('privacyDisclosureValidation')
        legacy['gates']['mentalHealthSafety'] = legacy['gates'].pop('aiSafetyValidation')
        with self.assertRaises(ValueError):
            self.validate(legacy)

    def test_real_pending_source_blocks_before_defines_or_evidence_access(self):
        repo = Path(__file__).resolve().parent.parent
        with self.assertRaisesRegex(ValueError, 'Public source gate is not approved'):
            prepare(repo, self.root/'does-not-exist.json', self.root/'no-review.json')
        self.assertFalse((self.root/'does-not-exist.json').exists())

    def test_prepare_writes_only_the_exact_reviewed_defines(self):
        repo = self.root/'synthetic-source'
        (repo/'lib/config').mkdir(parents=True)
        (repo/'tool').mkdir()
        source = '\n'.join(f'static const bool {name} = true;' for name in SOURCE_CAPABILITIES)
        source += '\n'+'\n'.join(f'static const bool {name} = false;' for name in
                                 ['analyticsEnabled','crashReportingEnabled','inferredIdentityEnabled'])
        (repo/'lib/config/launch_containment.dart').write_text(source)
        (repo/'tool/public_assistant_release.json').write_text(canonical(PUBLIC_POLICY))
        settings = {key:'synthetic-setting' for key in PUBLIC_SETTINGS}
        settings['CHRONOSPARK_SUPABASE_URL'] = 'https://synthetic.supabase.co'
        for key, function in [('CHRONOSPARK_AI_REPORT_ENDPOINT','ai-report'),
                              ('CHRONOSPARK_PLANNER_EXPLANATION_ENDPOINT','planner-explanation')]:
            settings[key] = settings['CHRONOSPARK_SUPABASE_URL']+'/functions/v1/'+function
        expected = assemble_public_defines(settings, PUBLIC_POLICY)
        evidence = copy.deepcopy(self.evidence)
        evidence['definesSha256'] = hashlib.sha256(canonical(expected).encode()).hexdigest()
        # Fixture validity must track execution time; production evidence is not generated here.
        current = datetime.now(timezone.utc)
        for gate in evidence['gates'].values():
            gate['reviewedAt'] = (current-timedelta(hours=1)).isoformat()
            gate['validUntil'] = (current+timedelta(hours=1)).isoformat()
        defines_path = self.root/'defines.json'
        evidence_path = self.root/'evidence.json'
        defines_path.write_text(canonical(settings))
        evidence_path.write_text(canonical(evidence))
        with patch('public_release_profile.subprocess.check_output', side_effect=[self.source_sha, '']):
            result = prepare(repo, defines_path, evidence_path)
        self.assertEqual(strict_json(defines_path.read_text()), expected)
        self.assertEqual(result['definesSha256'], evidence['definesSha256'])

    def test_duplicate_keys_and_non_json_numbers_are_rejected(self):
        for value in ['{"status":"pending","status":"approved"}', '{"x":NaN}', '{"x":Infinity}']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                strict_json(value)


if __name__ == '__main__':
    unittest.main()
