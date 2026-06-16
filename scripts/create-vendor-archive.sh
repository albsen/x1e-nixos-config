#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tcblaunch="$repo_root/tcblaunch.exe"
archive="$repo_root/vendor/dependencies.tar.gz.enc"
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

mkdir -p "$(dirname -- "$archive")"

if [ -n "${VENDOR_ARCHIVE_PASSWORD:-}" ]; then
    password="$VENDOR_ARCHIVE_PASSWORD"
else
    read -rsp 'Archive password: ' password
    printf '\n'
    read -rsp 'Confirm password: ' password_confirm
    printf '\n'

    if [ "$password" != "$password_confirm" ]; then
        printf 'error: passwords do not match\n' >&2
        exit 1
    fi
fi

if [ -z "$password" ]; then
    printf 'error: password must not be empty\n' >&2
    exit 1
fi

tar -czf - -C "$repo_root" tcblaunch.exe \
    | openssl enc -aes-256-cbc -pbkdf2 -salt -out "$archive" -pass fd:3 3<<<"$password"

printf 'Created local encrypted archive:\n%s\n' "$archive"
