#!/bin/sh
# Cargo runner: starts a Windows test (or program) under Proton's wine, with
# the same prefix and Direct3D 12 set-up as run.sh. Used by test.sh through
# CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUNNER (only on Linux; Windows runs
# tests natively).
. "$(dirname "$0")/env.sh"
[ -d "$WINEPREFIX" ] || {
    echo "no Wine prefix yet: run scripts/linux/run.sh check once" >&2
    exit 1
}
klbf_compiler
klbf_overrides
exec "$WINE" "$@"
