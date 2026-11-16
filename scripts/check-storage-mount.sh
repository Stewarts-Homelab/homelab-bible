#!/usr/bin/env bash
# Read-only check of an exact mount point and its filesystem UUID.
set -u

if [[ $# -ne 2 || ${1:-} != /* || -z ${2:-} ]]; then
  printf 'Usage: %s ABSOLUTE_MOUNT_POINT EXPECTED_FILESYSTEM_UUID\n' "$0" >&2
  exit 64
fi

target=$1
expected_uuid=$2

if ! command -v findmnt >/dev/null 2>&1; then
  printf 'findmnt is required (util-linux).\n' >&2
  exit 69
fi

if ! result=$(findmnt --noheadings --raw --output UUID --mountpoint "$target"); then
  printf 'No exact mount was verified at %s. Check the mount namespace and findmnt errors.\n' "$target" >&2
  exit 1
fi

if [[ -z $result || $result == *$'\n'* ]]; then
  printf 'Filesystem UUID is missing or ambiguous at %s. Inspect the mount and device before writing.\n' "$target" >&2
  exit 2
fi

if [[ $result != "$expected_uuid" ]]; then
  printf 'Filesystem UUID differs from the expected value at %s. Stop before writing.\n' "$target" >&2
  exit 3
fi

printf 'Verified exact mount and expected filesystem UUID at %s.\n' "$target"
