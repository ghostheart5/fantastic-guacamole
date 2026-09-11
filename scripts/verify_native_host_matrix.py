"""Fail-closed aggregation of five independent hosted native invocations."""
import argparse
import os
from pathlib import Path
import re

from android_final_validation import INTEGRATION_CASES, digest, read_json, require, verify_terminal, write_json


def verify(root, expected):
    roots = sorted(path for path in Path(root).iterdir() if path.is_dir())
    require(len(roots) == 5, 'Exactly five native host artifacts are required')
    require(expected['jobsResult'] == 'success', 'A native host job failed or was skipped')
    seen = set()
    boot_ids = set()
    runs = []
    for artifact in roots:
        provenance = read_json(artifact / 'source-provenance.json')
        for key in ('sourceSha', 'candidateSourceSha', 'validationSourceSha', 'validationToolingSha',
                    'validationRunId', 'validationRunAttempt', 'repository', 'candidateRunId', 'aabSha256'):
            require(provenance.get(key) == expected[key], f'Native artifact provenance differs: {key}')
        require(provenance.get('commandsExecutedAfterCompletedCandidateGate') is True,
                'Native execution did not follow the candidate gate')
        ordinal = provenance.get('nativeCase')
        require(ordinal in ('1', '2', '3', '4', '5') and ordinal not in seen,
                'Duplicate or invalid native case')
        seen.add(ordinal)
        boot_id = provenance.get('hostBootId', '')
        require(re.fullmatch(r'[a-f0-9-]{36}', boot_id) and boot_id not in boot_ids,
                'Native cases must come from five independent host boots')
        boot_ids.add(boot_id)
        filename, viewport, count = INTEGRATION_CASES[int(ordinal) - 1]
        summary = read_json(artifact / 'native/android-result.json')
        require(summary.get('passed') is True and summary.get('expectedInvocations') == 1 and
                summary.get('completedInvocations') == 1 and summary.get('expectedTests') == count and
                summary.get('caseOrdinals') == [int(ordinal)] and summary.get('notRun') == [] and
                len(summary.get('runs', [])) == 1, 'Missing, failed or mismatched native invocation')
        run = summary['runs'][0]
        require((run.get('file'), run.get('viewport'), run.get('expectedTests')) ==
                (filename, viewport, count), 'Native file or viewport differs')
        require(all(run.get(key) is True for key in ('passed', 'ownedEmulatorStopped',
                'ownedLogCollectorStopped', 'ownedAdbServerStopped', 'ownedAdbServerContinuous')),
                'Native runtime or owned-process continuity/cleanup failed')
        totals = {'total': count, 'passed': count, 'failed': 0, 'error': 0, 'skipped': 0}
        require(run.get('totals') == totals and run.get('failures') == [] and
                run.get('runnerExitCode') == 0 and run.get('runtimeEvidence', {}).get('fatalLines') == [],
                'Native terminal counts or fatal-error gate failed')
        label = f'{int(ordinal):02d}-{Path(filename).stem}-{viewport}'
        require(run.get('evidenceDirectory') == label, 'Native evidence directory differs')
        directory = artifact / 'native' / label
        manifest = directory / f'{Path(filename).stem}-{viewport}-manifest.json'
        require(verify_terminal(manifest) == totals, 'Canonical manifest totals differ')
        report = directory / f'{Path(filename).stem}-{viewport}.jsonl'
        require(report.is_file() and report.stat().st_size > 0, 'Canonical raw test report is missing')
        runs.append({'case': int(ordinal), 'file': filename, 'viewport': viewport,
                     'totals': totals, 'hostBootId': boot_id, 'artifact': artifact.name,
                     'manifestSha256': digest(manifest), 'reportSha256': digest(report),
                     'provenanceSha256': digest(artifact / 'source-provenance.json')})
    return {'passed': True, **expected, 'expectedInvocations': 5, 'completedInvocations': 5,
            'totals': {'total': 15, 'passed': 15, 'failed': 0, 'error': 0, 'skipped': 0},
            'runs': sorted(runs, key=lambda entry: entry['case']),
            'boundary': 'Five independent GitHub hosts; complete canonical file/viewport tests, no retries. Fixture integration, not Play Billing or human UAT.'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = {'passed': False}
    try:
        expected = {key: os.environ[value] for key, value in {
            'sourceSha': 'SOURCE_SHA', 'candidateSourceSha': 'SOURCE_SHA',
            'validationSourceSha': 'SOURCE_SHA', 'validationToolingSha': 'GITHUB_SHA',
            'validationRunId': 'GITHUB_RUN_ID', 'validationRunAttempt': 'GITHUB_RUN_ATTEMPT',
            'repository': 'GITHUB_REPOSITORY', 'candidateRunId': 'CANDIDATE_RUN',
            'aabSha256': 'CANDIDATE_AAB_SHA', 'jobsResult': 'NATIVE_JOBS_RESULT'}.items()}
        result = verify(args.input, expected)
    except Exception as error:
        result['failure'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        write_json(args.output, result)


if __name__ == '__main__':
    main()
