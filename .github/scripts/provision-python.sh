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
# Adds the venv's `bin` directory to GITHUB_PATH for the caller, and sets
# FM_PYTHON and VIRTUAL_ENV for steps that need the interpreter by path
# (maturin-action does).

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
#
# ORDER MATTERS, and prepending in the loop is how it went wrong once. This loop
# ran `for d in /opt/homebrew/bin /usr/local/bin` and prepended each in turn, so
# on a box carrying BOTH installs -- an Apple Silicon Mac that also has an
# x86_64 Homebrew -- /usr/local/bin ended up FIRST. `command -v python3.11`
# below then resolved an x86_64 interpreter, which python-publish.yml hands to
# `maturin -i` while building `target: aarch64-apple-darwin`: an arch mismatch
# on the publish lane, and the resulting wheel tagged for the wrong Python.
#
# So the prefix is chosen ONCE, native first, and only that one is prepended.
# The other stays reachable via the runner's own PATH when it is there.
#
# NATIVE_PREFIX is then load-bearing rather than cosmetic. Prepending the native
# directory is NOT on its own enough: PATH resolution walks the whole path per
# NAME, so a native prefix that ships `python3` but no `python3.11` still lets
# the candidate loop below find an Intel `python3.11` further along. The
# candidate search therefore runs TWICE -- once restricted to the native prefix,
# once over PATH -- so the native prefix is exhausted for every candidate before
# any other directory is considered at all.
NATIVE_PREFIX=""
for d in /opt/homebrew/bin /usr/local/bin; do
  if [[ -d "$d" ]]; then
    NATIVE_PREFIX="$d"
    echo "$d" >> "$GITHUB_PATH"
    PATH="$d:$PATH"
    export PATH
    # Only the first (native) prefix goes in front. Anything after it would
    # only ever shadow the native interpreter on a dual-install box.
    break
  fi
done

# An explicit 3.11 is what the workflows asked for on the hosted image, so it is
# tried first and the machine's own python3 is the fallback. Preferring 3.11
# keeps the local and CI interpreters comparable without requiring it.
#
# TWO SEPARATE PASSES, in this order: the native prefix is exhausted for every
# candidate before PATH is consulted at all. Interleaving them per candidate
# does not work -- the loop would reach the PATH search for `python3.11` before
# it ever offered the native `python3`, and pick the Intel one. `command -v`
# cannot express "only look in this directory", so the native pass checks the
# prefix directly.
select_interpreter() {
  local candidate found
  if [[ -n "$NATIVE_PREFIX" ]]; then
    for candidate in python3.11 python3; do
      if [[ -x "$NATIVE_PREFIX/$candidate" ]]; then
        printf '%s\n' "$NATIVE_PREFIX/$candidate"
        return 0
      fi
    done
  fi
  for candidate in python3.11 python3; do
    if found="$(command -v "$candidate" 2>/dev/null)"; then
      printf '%s\n' "$found"
      return 0
    fi
  done
  return 1
}

PY=""
PY="$(select_interpreter)" || PY=""
[[ -n "$PY" ]] || provision_error "no python3 on this box. This lane needs a machine-provided interpreter; actions/setup-python is not used here because it cannot write its tool cache on these runners."

version="$("$PY" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
major="${version%%.*}"
minor="${version##*.}"
if (( major < MIN_MAJOR || (major == MIN_MAJOR && minor < MIN_MINOR) )); then
  # The wheel tag is `abi3-py3${MIN_MINOR}` (abi3-py310 for MIN_MINOR=10), so
  # the "3" is part of the tag and not something MIN_MINOR supplies. Reading it
  # as a trailing "0" instead renders "py100" and sends whoever reads the
  # message looking for a tag that does not exist.
  provision_error "found python $version at $PY; this crate ships an abi3-py3${MIN_MINOR} wheel and needs >= ${MIN_MAJOR}.${MIN_MINOR}."
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