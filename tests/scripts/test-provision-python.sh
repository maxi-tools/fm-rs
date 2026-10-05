#!/usr/bin/env bash
# Regression test for the interpreter selection in provision-python.sh.
#
# The bug this pins: prepending the native Homebrew prefix to PATH is NOT
# sufficient. PATH resolution walks the whole path per NAME, so a native prefix
# that ships `python3` but no `python3.11` still lets the candidate loop find an
# Intel `python3.11` further along -- and python-publish.yml hands whatever is
# chosen to `maturin -i` for a `target: aarch64-apple-darwin` build.
#
# The function is extracted from the real script rather than copied, so the test
# fails if the script's logic drifts from what is asserted here.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.github/scripts/provision-python.sh"
[[ -f "$SCRIPT" ]] || { echo "cannot find $SCRIPT"; exit 2; }

# Pull select_interpreter() and its NATIVE_PREFIX dependency out of the script
# without running the script (which provisions a real venv).
eval "$(awk '/^select_interpreter\(\)/,/^}$/' "$SCRIPT")"

[[ "$(type -t select_interpreter)" == function ]] || {
  echo "FAIL: select_interpreter() not found in $SCRIPT"; exit 1; }

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
native="$root/opt/homebrew/bin"
intel="$root/usr/local/bin"
mkdir -p "$native" "$intel"
mk() { printf '#!/bin/sh\nexit 0\n' > "$1"; chmod +x "$1"; }

fail=0
check() {
  local desc="$1" want="$2" got
  got="$(NATIVE_PREFIX="$NPATH" PATH="$TESTPATH" select_interpreter)"
  if [[ "$got" == "$want" ]]; then
    printf '  ok    %s\n' "$desc"
  else
    printf '  FAIL  %s\n        want %s\n        got  %s\n' "$desc" "$want" "$got"
    fail=1
  fi
}

echo "case 1: native has python3, intel has python3.11 -- native python3 must win"
mk "$native/python3"; mk "$intel/python3.11"; mk "$intel/python3"
NPATH="$native"; TESTPATH="$intel:/usr/bin:/bin"
check "native python3 beats a later-path intel python3.11" "$native/python3"

echo "case 2: native has both -- python3.11 preferred, still native"
mk "$native/python3.11"
NPATH="$native"; TESTPATH="$intel:/usr/bin:/bin"
check "native python3.11 wins outright" "$native/python3.11"

echo "case 3: native prefix empty -- ordinary PATH search still works"
NPATH=""; TESTPATH="$intel:/usr/bin:/bin"
check "falls back to PATH when there is no native prefix" "$intel/python3.11"

echo "case 4: nothing anywhere -- non-zero so the caller can error"
NPATH=""; TESTPATH="$root/empty"
mkdir -p "$root/empty"
if ( NPATH="" PATH="$root/empty" select_interpreter ) >/dev/null 2>&1; then
  echo "  FAIL  expected non-zero exit when no interpreter exists"
  fail=1
else
  echo "  ok    returns non-zero when no interpreter exists"
fi

[[ $fail == 0 ]] && echo "PASS" || echo "FAILURES"
exit $fail