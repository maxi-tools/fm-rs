#!/usr/bin/env bash
# Provisions a Python for a self-hosted macOS lane, as a per-job venv.
#
# Why this replaces actions/setup-python on this fleet.
# -------------------------------------------------
# On the GitHub-hosted macos-26 image this repo used to run on, setup-python was
# fine: the image ships a writable tool cache and an /Users/runner that the
# runner user owns. On a self-hosted Mac neither is true. The first run of this
# PR on the new pool failed with:
#
#   Check if Python hostedtoolcache folder exist...
#   Creating Python hostedtoolcache folder...
#   ##[error]mkdir: /Users/runner: Permission denied
#
# because setup-python installs into RUNNER_TOOL_CACHE, which on these boxes
# resolves under a path the runner service account cannot create. That is a
# property of the MACHINE, not of the Python version being requested, so no
# setting on the action makes it work -- the answer is to stop using it here.
#
# This is the same call maxi-ml made on its Linux lanes, for the same class of
# reason (setup-python fetches an artifact that does not fit the fleet's
# machines), and the same venv-under-RUNNER_TEMP shape.
#
# WHY A VENV AND NOT A BARE `pip install`. These runners are PERSISTENT. A bare
# `pip install pytest` into the machine's interpreter mutates a box every other
# job on the org's runners shares, and does it again on the next run with
# whatever version resolves that day. RUNNER_TEMP is per-job and is cleaned by
# the runner, so the job is reproducible and the machine is untouched.
#
# Sets FM_PYTHON_BIN_DIR on stdout-adjacent GITHUB_PATH for the caller, and
# FM_PYTHON for steps that need the interpreter by path (maturin-action does).

set -euo pipefail

MIN_MAJOR=3
MIN_MINOR=10   # the wheel is abi3-py310; anything older cannot load it

provision_error() {
  echo "::error::$*  (runner: ${RUNNER_NAME:-unknown})"
  exit 1
}

# Homebrew installs under /opt/homebrew on Apple Silicon and /usr/local on
# Intel, and these runners are invoked with a PATH that does not reliably carry
# either -- the same probe coreml-rs's review workflow uses.
for d in /opt/homebrew/bin /usr/local/bin; do
  if [[ -d "$d" ]]; then
    echo "$d" >> "$GITHUB_PATH"
    PATH="$d:$PATH"
    export PATH
  fi
done

# An explicit 3.11 is what the workflows asked for on the hosted image, so it is
# tried first and the machine's own python3 is the fallback. Preferring 3.11
# keeps the local and CI interpreters comparable without requiring it.
PY=""
for candidate in python3.11 python3; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PY="$(command -v "$candidate")"
    break
  fi
done
[[ -n "$PY" ]] || provision_error "no python3 on this box. This lane needs a machine-provided interpreter; actions/setup-python is not used here because it cannot write its tool cache on these runners."

version="$("$PY" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
major="${version%%.*}"
minor="${version##*.}"
if (( major < MIN_MAJOR || (major == MIN_MAJOR && minor < MIN_MINOR) )); then
  provision_error "found python $version at $PY; this crate ships an abi3-py${MIN_MINOR}0 wheel and needs >= ${MIN_MAJOR}.${MIN_MINOR}."
fi

VENV="${RUNNER_TEMP:?RUNNER_TEMP is unset; this script only runs inside Actions}/fm-venv"
rm -rf "$VENV"
"$PY" -m venv "$VENV"

echo "runner:   ${RUNNER_NAME:-unknown}"
echo "python:   $version ($PY)"
echo "venv:     $VENV"

echo "$VENV/bin" >> "$GITHUB_PATH"
{
  echo "FM_PYTHON=$VENV/bin/python3"
  echo "VIRTUAL_ENV=$VENV"
} >> "$GITHUB_ENV"

"$VENV/bin/python3" -m pip install --quiet --upgrade pip
"$VENV/bin/python3" --version