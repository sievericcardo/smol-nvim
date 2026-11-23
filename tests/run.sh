#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/nvim-smol-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

export XDG_DATA_HOME="$TMP/data"
export XDG_STATE_HOME="$TMP/state"
export XDG_CACHE_HOME="$TMP/cache"
export XDG_CONFIG_HOME="$TMP/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"

# Discover lockpick binaries when the caller did not provide them.
maybe_bin() {
  local candidate
  for candidate in "$@"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if [[ -z "${SMOL_TEST_LOCKPICK:-}" ]]; then
  SMOL_TEST_LOCKPICK="$(
    maybe_bin \
      "$ROOT/../lockpick/target/release/lockpick" \
      "$HOME/Documents/GitHub/lockpick/target/release/lockpick" \
      "$(command -v lockpick 2>/dev/null || true)" || true
  )"
  export SMOL_TEST_LOCKPICK
fi

if [[ -z "${SMOL_TEST_LSP:-}" ]]; then
  SMOL_TEST_LSP="$(
    maybe_bin \
      "$ROOT/../lockpick/target/release/lockpick-lsp" \
      "$HOME/Documents/GitHub/lockpick/target/release/lockpick-lsp" \
      "$(command -v lockpick-lsp 2>/dev/null || true)" || true
  )"
  export SMOL_TEST_LSP
fi

if [[ -n "${SMOL_TEST_LOCKPICK:-}" ]]; then
  echo "using lockpick:     $SMOL_TEST_LOCKPICK"
else
  echo "lockpick CLI not found; skipping CLI integration checks"
fi
if [[ -n "${SMOL_TEST_LSP:-}" ]]; then
  echo "using lockpick-lsp: $SMOL_TEST_LSP"
else
  echo "lockpick-lsp not found; skipping LSP integration checks"
fi

nvim --headless --clean \
  -u "$ROOT/tests/minimal_init.lua" \
  -l "$ROOT/tests/smoke.lua"
