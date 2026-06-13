#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tcblaunch="$repo_root/tcblaunch.exe"
expected_hash="sha256-RjUg4ZWB2pZINLTwexkwNmXccB3jHGrXSO+MvRMz5Ug="

if [ ! -f "$tcblaunch" ]; then
    printf 'error: expected %s\n' "$tcblaunch" >&2
    exit 1
fi

actual_hash="$(nix hash file "$tcblaunch")"
if [ "$actual_hash" != "$expected_hash" ]; then
    printf 'error: tcblaunch.exe hash mismatch\n' >&2
    printf 'expected: %s\n' "$expected_hash" >&2
    printf 'actual:   %s\n' "$actual_hash" >&2
    exit 1
fi

store_path="$(nix store add-file "$tcblaunch")"

printf 'Added tcblaunch.exe to the Nix store:\n%s\n' "$store_path"
