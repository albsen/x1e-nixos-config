#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tcblaunch="$repo_root/tcblaunch.exe"
archive="$repo_root/vendor/dependencies.tar.gz.enc"
expected_hash="sha256-RjUg4ZWB2pZINLTwexkwNmXccB3jHGrXSO+MvRMz5Ug="

if [ ! -f "$archive" ]; then
    printf 'error: missing local encrypted archive: %s\n' "$archive" >&2
    exit 1
fi

if [ -n "${VENDOR_ARCHIVE_PASSWORD:-}" ]; then
    password="$VENDOR_ARCHIVE_PASSWORD"
else
    read -rsp 'Archive password: ' password
    printf '\n'
fi

if [ -z "$password" ]; then
    printf 'error: password must not be empty\n' >&2
    exit 1
fi

openssl enc -d -aes-256-cbc -pbkdf2 -in "$archive" -pass fd:3 3<<<"$password" \
    | tar -xzf - -C "$repo_root"

actual_hash="$(nix hash file "$tcblaunch")"
if [ "$actual_hash" != "$expected_hash" ]; then
    rm -f "$tcblaunch"
    printf 'error: restored tcblaunch.exe hash mismatch; removed restored file\n' >&2
    printf 'expected: %s\n' "$expected_hash" >&2
    printf 'actual:   %s\n' "$actual_hash" >&2
    exit 1
fi

printf 'Restored tcblaunch.exe:\n%s\n' "$tcblaunch"
