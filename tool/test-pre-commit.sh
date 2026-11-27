#!/usr/bin/env bash
set -euo pipefail

hook="$(git rev-parse --show-toplevel)/.githooks/pre-commit"
temp_root="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
scratch="$(mktemp -d "$temp_root/tamashii-hook.XXXXXXXX")"
[[ "$scratch" == "$temp_root"/tamashii-hook.* ]]
trap 'cd "$temp_root" && rm -rf -- "$scratch"' EXIT
cd "$scratch"
git init -q
mkdir bin
cat > bin/fvm <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'dart format')
    [[ "$3" == './test file.dart' && "$#" == 3 ]]
    printf 'void main() {}\n' > "$3"
    ;;
  'flutter analyze')
    [[ "$3" == '--no-pub' && "${FAIL_ANALYSIS:-}" != yes ]]
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x bin/fvm
export PATH="$scratch/bin:$PATH"

file='test file.dart'
printf 'void main(){}\n' > "$file"
git add -- "$file"
bash "$hook"
[[ "$(git show ":$file")" == 'void main() {}' ]]

printf 'unstaged edit\n' >> "$file"
if bash "$hook"; then
  echo 'The hook accepted a partially staged Dart file.' >&2
  exit 1
fi
[[ "$(git show ":$file")" == 'void main() {}' ]]
[[ "$(tail -n 1 "$file")" == 'unstaged edit' ]]

git checkout -- "$file"
if FAIL_ANALYSIS=yes bash "$hook"; then
  echo 'The hook accepted a failed analyzer check.' >&2
  exit 1
fi
