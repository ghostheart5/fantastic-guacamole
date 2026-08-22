#!/usr/bin/env bash

set -uo pipefail
shopt -s nullglob

test_files=(integration_test/*_test.dart)
if (( ${#test_files[@]} == 0 )); then
  echo '::error::No Linux integration test files were found.'
  exit 1
fi

failures=0
for test_file in "${test_files[@]}"; do
  echo "::group::Linux integration: $test_file"
  if xvfb-run -a flutter test "$test_file" --no-pub -d linux; then
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
