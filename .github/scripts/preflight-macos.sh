#!/usr/bin/env bash
# Runs before every macOS lane in this repo, on a PERSISTENT self-hosted Mac.
#
# Why this exists: the lanes moved off GitHub-hosted `macos-26` onto
# `[self-hosted, macOS, ARM64]` (see the header in ci.yml). That pool is 15
# boxes today and none of them is pinned to a macOS version, so the failure mode
# the hosted image used to make impossible is back: a job that lands on a box
# whose OS cannot provide FoundationModels.framework dies somewhere deep in the
# linker with a message about a missing framework or a deployment target, and
# the log points at the code rather than at the runner.
#
# So the version check that `macos-26` encoded in its label is done here, in the
# job, where it can name the box and the version it actually found. A box that
# drifts below 26 fails in the first few seconds with the measurement attached.
#
# Exit 0 on a capable box; exit 1 (loudly) on anything else. Deliberately not a
# warning: a Mac lane that runs against the wrong OS produces a green check for
# a build nobody made.

set -euo pipefail

readonly REQUIRED_MAJOR=26

fail() {
  echo "::error::$*"
  exit 1
}

# --- platform ---------------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || fail "expected macOS, got $(uname -s). A [self-hosted, macOS, ARM64] lane landed on the wrong OS."

# `uname -m` under Rosetta reports x86_64, so ask the hardware instead when the
# translation layer is in play -- an arm64 host running an x86_64 shell can still
# build an aarch64 target, but a genuine Intel box cannot, and the runner label
# claims ARM64. Translate instead of failing when Rosetta is the reason.
arch="$(uname -m)"
if [[ "$arch" == "x86_64" ]] && sysctl -in sysctl.proc_translated 2>/dev/null | grep -q 1; then
  arch="arm64"
fi
[[ "$arch" == "arm64" ]] || fail "expected Apple Silicon (arm64), got $arch. The runner label says ARM64; the box does not match its own labels."

# --- macOS version ----------------------------------------------------------
# Compared as a NUMBER, not as a string: "26.10" sorts before "26.9" lexically,
# and this fleet is at 26.5.x / 26.6.x / 27.0.x, so a string compare would one day
# read 26.10 as older than 26.6 and reject a capable box.
version="$(sw_vers -productVersion)"
major="${version%%.*}"
[[ "$major" =~ ^[0-9]+$ ]] || fail "could not parse a macOS major version out of sw_vers -productVersion: '$version'"

echo "runner:   ${RUNNER_NAME:-unknown} (${arch})"
echo "host:     ${RUNNER_ENVIRONMENT:-self-hosted}"
echo "macOS:    ${version}"

if (( major < REQUIRED_MAJOR )); then
  fail "this box runs macOS ${version}; fm-rs needs ${REQUIRED_MAJOR}.0 or newer for FoundationModels.framework. Move the box forward, or re-scope this repo's FM_RS_MACOS_RUNS_ON variable to a pool that is at ${REQUIRED_MAJOR}."
fi

# --- the framework itself ---------------------------------------------------
# The version check above is necessary but not sufficient: an OS can report 26
# and still be missing the framework if it was installed before the update, or
# if the SDK/framework pair is broken. xcrun resolves against the active Xcode
# rather than a guessed path, which is also the only honest way to report WHICH
# toolchain is about to build.
if ! xcrun --show-sdk-path >/dev/null 2>&1; then
  fail "xcrun could not resolve an SDK on this box. Xcode is required to build fm-rs; check xcode-select -p."
fi

sdk_path="$(xcrun --show-sdk-path)"
sdk_version="$(xcrun --show-sdk-version)"
echo "sdk:      ${sdk_path} (${sdk_version})"

framework="$(xcrun --show-sdk-path)/System/Library/Frameworks/FoundationModels.framework"
if [[ ! -d "$framework" ]]; then
  fail "FoundationModels.framework is not present in the SDK at ${sdk_path}. The box reports macOS ${version} and the SDK reports ${sdk_version}, so this is an incomplete install rather than an OS too old -- check /Applications/Xcode.app."
fi

echo "preflight ok: FoundationModels.framework present, deployment target ${MACOSX_DEPLOYMENT_TARGET:-unset}"