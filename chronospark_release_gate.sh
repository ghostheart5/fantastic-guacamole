#!/usr/bin/env bash

set +e

LOG_FILE="chronospark_release_gate.log"

echo "ChronoSpark Release Gate" > "$LOG_FILE"
echo "Date: $(date)" >> "$LOG_FILE"
echo "Folder: $(pwd)" >> "$LOG_FILE"

run_step() {
  NAME="$1"
  COMMAND="$2"

  echo ""
  echo "============================================================"
  echo "$NAME"
  echo "============================================================"
  echo "COMMAND: $COMMAND"

  {
    echo ""
    echo "============================================================"
    echo "$NAME"
    echo "============================================================"
    echo "COMMAND: $COMMAND"
    eval "$COMMAND"
    echo "EXIT CODE: $?"
  } 2>&1 | tee -a "$LOG_FILE"
}

run_step "Git Status" "git status"
run_step "Flutter Analyze" "flutter analyze"
run_step "Flutter Test" "flutter test"
run_step "Release App Bundle Build" "flutter build appbundle --release"

echo ""
echo "Release gate complete."
echo "Log saved to: $LOG_FILE"
