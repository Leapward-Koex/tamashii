#!/usr/bin/env bash
set -Eeuo pipefail

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

usage() {
  printf '%s\n' \
    'Usage: tool/test-network-policy.sh [debug|release] [--device ID] [--keep-on-failure]' >&2
  exit 64
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
build_mode="${TAMASHII_NETWORK_POLICY_BUILD_MODE:-debug}"
device_id="${TAMASHII_DEVICE_ID:-}"
keep_on_failure="${TAMASHII_KEEP_NETWORK_POLICY_TEST_DATA:-false}"
timeout_input="${TAMASHII_NETWORK_POLICY_TEST_TIMEOUT_MINUTES:-5}"

if [[ $# -gt 0 && ("$1" == "debug" || "$1" == "release") ]]; then
  build_mode="$1"
  shift
fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      [[ $# -ge 2 ]] || usage
      device_id="$2"
      shift 2
      ;;
    --keep-on-failure)
      keep_on_failure=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[[ "$build_mode" == "debug" || "$build_mode" == "release" ]] || usage
[[ "$timeout_input" =~ ^[0-9]+$ && ${#timeout_input} -le 2 ]] ||
  { printf 'Timeout must be an integer from 1 to 60.\n' >&2; exit 64; }
timeout_minutes=$((10#$timeout_input))
((timeout_minutes >= 1 && timeout_minutes <= 60)) ||
  { printf 'Timeout must be an integer from 1 to 60.\n' >&2; exit 64; }
case "$keep_on_failure" in
  1|true|TRUE|yes|YES) keep_on_failure=true ;;
  *) keep_on_failure=false ;;
esac

timestamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"
diagnostics_root="$repo_root/build/test-network-policy/$timestamp"
mkdir -p "$diagnostics_root"
log_path="$diagnostics_root/flutter-test.log"
result_path="$diagnostics_root/result.json"
: > "$log_path"

device_target=""
release_artifact_built=false
test_execution_mode="debug"
handling_failure=false
temporary_key_properties=false
key_properties_path="$repo_root/android/key.properties"
if [[ "$build_mode" == "release" ]]; then
  test_execution_mode="profile"
fi

cleanup_signing_config() {
  if [[ "$temporary_key_properties" == true && -f "$key_properties_path" ]]; then
    rm -f -- "$key_properties_path"
  fi
  temporary_key_properties=false
}
trap cleanup_signing_config EXIT

write_result() {
  local passed="$1"
  local exit_code="$2"
  local error_message="${3:-}"
  local error_field=""
  if [[ -n "$error_message" ]]; then
    error_field=",\"error\":\"$(json_escape "$error_message")\""
  fi
  local json
  json="{\"passed\":$passed,\"device\":\"$(json_escape "$device_id")\",\"targetPlatform\":\"$(json_escape "$device_target")\",\"buildMode\":\"$build_mode\",\"testExecutionMode\":\"$test_execution_mode\",\"releaseArtifactBuilt\":$release_artifact_built,\"timeoutMinutes\":$timeout_minutes,\"keepOnFailure\":$keep_on_failure,\"testFile\":\"integration_test/network_policy_integration_test.dart\",\"exitCode\":$exit_code,\"log\":\"$(json_escape "$log_path")\",\"result\":\"$(json_escape "$result_path")\",\"completedAt\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"$error_field}"
  printf '%s\n' "$json" > "$result_path"
  printf 'TAMASHII_NETWORK_POLICY_TEST_RESULT=%s\n' "$json"
}

fail() {
  local message="$1"
  local code="${2:-1}"
  handling_failure=true
  set +e
  trap - ERR
  printf 'ERROR: %s\n' "$message" >> "$log_path"
  printf '%s\n' "$message" >&2
  write_result false "$code" "$message"
  exit "$code"
}

unexpected_failure() {
  local code="$1"
  local line="$2"
  if [[ "$handling_failure" == true ]]; then
    exit "$code"
  fi
  fail "Unexpected script failure at line $line." "$code"
}
trap 'unexpected_failure "$?" "$LINENO"' ERR

create_smoke_signing_config_if_needed() {
  if [[ -e "$key_properties_path" ]]; then
    return
  fi
  command -v keytool >/dev/null 2>&1 ||
    fail 'keytool is required to create the temporary Release smoke-test key.' 69

  local keystore_path="$diagnostics_root/smoke-upload-keystore.jks"
  if ! keytool \
    -genkeypair \
    -keystore "$keystore_path" \
    -storepass tamashii-smoke \
    -keypass tamashii-smoke \
    -alias smoke \
    -keyalg RSA \
    -keysize 2048 \
    -validity 1 \
    -dname 'CN=Tamashii CI' >> "$log_path" 2>&1; then
    fail 'keytool failed while creating the temporary Release smoke-test key.' 69
  fi

  local properties_keystore_path="$keystore_path"
  if command -v cygpath >/dev/null 2>&1; then
    properties_keystore_path="$(cygpath -m "$keystore_path")"
  fi
  if ! (
    set -o noclobber
    printf '%s\n' \
      'storePassword=tamashii-smoke' \
      'keyPassword=tamashii-smoke' \
      'keyAlias=smoke' \
      "storeFile=$properties_keystore_path" > "$key_properties_path"
  ); then
    fail 'android/key.properties appeared while creating temporary signing configuration.' 73
  fi
  temporary_key_properties=true
}

if [[ -n "${TAMASHII_FLUTTER:-}" ]]; then
  flutter_cmd=("$TAMASHII_FLUTTER")
elif command -v fvm >/dev/null 2>&1; then
  flutter_cmd=("$(command -v fvm)" flutter)
elif [[ -x "$repo_root/.fvm/flutter_sdk/bin/flutter" ]]; then
  flutter_cmd=("$repo_root/.fvm/flutter_sdk/bin/flutter")
elif [[ -x "$HOME/fvm/default/bin/flutter" ]]; then
  flutter_cmd=("$HOME/fvm/default/bin/flutter")
else
  fail 'FVM Flutter was not found. Install FVM or set TAMASHII_FLUTTER.' 69
fi

if ! device_output="$("${flutter_cmd[@]}" devices 2>&1)"; then
  printf '%s\n' "$device_output" >> "$log_path"
  fail 'flutter devices failed.' 69
fi
printf 'Flutter devices:\n%s\n' "$device_output" >> "$log_path"

if [[ -n "$device_id" ]]; then
  device_target="$(printf '%s\n' "$device_output" | awk -F ' • ' -v expected="$device_id" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    NF >= 3 {
      id = trim($2)
      target = trim($3)
      if (id == expected) {
        print target
        exit
      }
    }
  ')"
  [[ -n "$device_target" ]] || fail "Flutter device '$device_id' was not found." 69
else
  device_record="$(printf '%s\n' "$device_output" | awk -F ' • ' '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    NF >= 3 {
      id = trim($2)
      target = trim($3)
      if (target ~ /^android-/ && fallback == "") {
        fallback = id "\t" target
      }
      if (target == "android-x64") {
        print id "\t" target
        found = 1
        exit
      }
    }
    END {
      if (!found && fallback != "") print fallback
    }
  ')"
  [[ -n "$device_record" ]] ||
    fail 'No supported Android device is available. Start/connect one or pass --device.' 69
  IFS=$'\t' read -r device_id device_target <<< "$device_record"
fi
[[ "$device_target" == android-* ]] ||
  fail "Flutter device '$device_id' targets '$device_target', not Android." 69
printf 'Selected device: %s (%s)\n' "$device_id" "$device_target" >> "$log_path"

define_arguments=(
  '--dart-define=TAMASHII_USE_TEST_TORRENT=true'
  '--dart-define=TAMASHII_ENABLE_NETWORK_POLICY_TEST_HOOK=true'
  "--dart-define=TAMASHII_NETWORK_POLICY_TEST_TIMEOUT_MINUTES=$timeout_minutes"
  "--dart-define=TAMASHII_KEEP_NETWORK_POLICY_TEST_DATA=$keep_on_failure"
)

trap - ERR
set +e
if [[ "$build_mode" == "release" ]]; then
  create_smoke_signing_config_if_needed
  printf '%s\n' \
    'Building the actual Android Release artifact before the Profile integration run.' |
    tee -a "$log_path"
  (
    cd "$repo_root"
    "${flutter_cmd[@]}" build apk --release "${define_arguments[@]}"
  ) 2>&1 | tee -a "$log_path"
  release_status=("${PIPESTATUS[@]}")
  if [[ ${release_status[1]} -ne 0 ]]; then
    fail "Could not write Release-build diagnostics (tee exit code ${release_status[1]})." "${release_status[1]}"
  fi
  if [[ ${release_status[0]} -ne 0 ]]; then
    fail "Flutter Release build failed with exit code ${release_status[0]}." "${release_status[0]}"
  fi
  release_artifact_built=true
  cleanup_signing_config
  test_command=(
    "${flutter_cmd[@]}" drive
    --driver=test_driver/integration_test.dart
    --target=integration_test/network_policy_integration_test.dart
    -d "$device_id"
    --profile
    "${define_arguments[@]}"
  )
else
  test_command=(
    "${flutter_cmd[@]}" test integration_test/network_policy_integration_test.dart
    -d "$device_id"
    "${define_arguments[@]}"
  )
fi

(
  cd "$repo_root"
  "${test_command[@]}"
) 2>&1 | tee -a "$log_path"
test_status=("${PIPESTATUS[@]}")
set -e
trap 'unexpected_failure "$?" "$LINENO"' ERR

if [[ ${test_status[1]} -ne 0 ]]; then
  fail "Could not write Flutter diagnostics (tee exit code ${test_status[1]})." "${test_status[1]}"
fi
test_exit_code="${test_status[0]}"
if [[ $test_exit_code -eq 0 ]]; then
  write_result true 0
else
  write_result false "$test_exit_code" \
    "Flutter integration test failed with exit code $test_exit_code."
fi
exit "$test_exit_code"
