#!/usr/bin/env bash

set -uo pipefail
shopt -s nullglob globstar

test_files=(integration_test/**/*_test.dart)
evidence_root="${CHRONOSPARK_INTEGRATION_EVIDENCE_DIR:-artifacts/integration-evidence}"
timeout_seconds="${CHRONOSPARK_INTEGRATION_TIMEOUT_SECONDS:-600}"
total_timeout_seconds="${CHRONOSPARK_INTEGRATION_TOTAL_TIMEOUT_SECONDS:-1800}"
if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo '::error::CHRONOSPARK_INTEGRATION_TIMEOUT_SECONDS must be a positive integer.'
  exit 64
fi
if [[ ! "$total_timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo '::error::CHRONOSPARK_INTEGRATION_TOTAL_TIMEOUT_SECONDS must be a positive integer.'
  exit 64
fi
if (( ${#test_files[@]} == 0 )); then
  echo '::error::No Linux integration test files were found.'
  exit 1
fi
mkdir -p "$evidence_root"

failures=0
suite_started_seconds=$SECONDS
for test_file in "${test_files[@]}"; do
  elapsed_seconds=$((SECONDS - suite_started_seconds))
  remaining_seconds=$((total_timeout_seconds - elapsed_seconds))
  if (( remaining_seconds <= 0 )); then
    failures=$((failures + 1))
    echo "::error::Linux integration suite exhausted its ${total_timeout_seconds}-second total budget before $test_file."
    break
  fi
  effective_timeout_seconds=$timeout_seconds
  if (( effective_timeout_seconds > remaining_seconds )); then
    effective_timeout_seconds=$remaining_seconds
  fi
  test_name="$(basename "$test_file" _test.dart)"
  echo "::group::Linux integration: $test_file"
  if xvfb-run -a dart run tool/run_flutter_tests.dart \
    --report "$evidence_root/${test_name}.jsonl" \
    --manifest "$evidence_root/${test_name}-manifest.json" \
    --timeout-seconds "$effective_timeout_seconds" \
    -- "$test_file" --no-pub -d linux; then
    echo "Passed: $test_file"
  else
    test_status=$?
    failures=$((failures + 1))
    echo "::error file=$test_file::Linux integration failed with exit code $test_status."
  fi
  echo '::endgroup::'
done

if (( failures > 0 )); then
  echo "::error::$failures Linux integration test file(s) failed."
  exit 1
fi

echo "All ${#test_files[@]} Linux integration test files passed in isolated Xvfb processes."
