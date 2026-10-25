#!/bin/sh
# Runs the real CallCenter with stubs only for unavailable Android OS services.
set -eu
repo_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
kotlinc "$repo_root"/test/native_call_listener/*.kt \
  "$repo_root/android/app/src/main/kotlin/com/labbiah/labbiah/CallCenter.kt" \
  -include-runtime -d "$test_tmp/regression.jar"
java -jar "$test_tmp/regression.jar"
