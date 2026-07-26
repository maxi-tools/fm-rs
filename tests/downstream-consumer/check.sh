#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$repo_root/tests/downstream-consumer/Cargo.toml"
target_dir="$repo_root/target/downstream-consumer"
binary="$target_dir/debug/fm-rs-downstream-consumer"

cargo run --manifest-path "$manifest" --target-dir "$target_dir"

linked_libraries="$(otool -L "$binary")"
if grep -Fq "@rpath/libswift_Concurrency.dylib" <<<"$linked_libraries"; then
    echo "downstream binary still links Swift Concurrency through @rpath" >&2
    exit 1
fi

if ! grep -Fq "/usr/lib/swift/libswift_Concurrency.dylib" <<<"$linked_libraries"; then
    echo "downstream binary does not link the system Swift Concurrency runtime" >&2
    exit 1
fi
