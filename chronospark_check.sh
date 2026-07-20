#!/usr/bin/env bash

echo "====================================="
echo "ChronoSpark Diagnostic"
echo "====================================="

LOG_FILE="chronospark_diagnostic.log"

echo "" > "$LOG_FILE"

run_check() {
    echo ""
    echo "===== $1 =====" | tee -a "$LOG_FILE"
    echo "Command: $2" | tee -a "$LOG_FILE"
    eval "$2" 2>&1 | tee -a "$LOG_FILE"
}

run_check "Current Directory" "pwd"
run_check "Project Files" "ls"
run_check "Git Status" "git status"
run_check "Flutter Version" "flutter --version"
run_check "Flutter Doctor" "flutter doctor -v"
run_check "Pub Get" "flutter pub get"
run_check "Flutter Analyze" "flutter analyze"

echo ""
echo "====================================="
echo "Diagnostic Complete"
echo "Log saved to:"
echo "$LOG_FILE"
echo "====================================="