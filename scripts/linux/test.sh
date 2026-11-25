#!/bin/sh
# Runs the test suite on Linux: built for Windows with cargo-xwin and run
# under Proton's wine (scripts/linux/wine-runner.sh), so the Windows-only
# crates and the Direct3D 12 tests run on this machine's GPU through
# vkd3d-proton. Plain `cargo test` on Linux cannot build the workspace.
#
#   scripts/linux/test.sh                        # every crate
#   scripts/linux/test.sh -p victory-gpu         # one crate
#   scripts/linux/test.sh -p victory-gpu -- shadow   # filter, as with cargo test
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
KLBF_HOME="${KLBF_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/klbf-fork}"
TARGET=x86_64-pc-windows-msvc

# Same toolchain set-up as build.sh (LLVM stand-ins, target).
"$ROOT/scripts/linux/build.sh" --quiet >/dev/null
[ -d "$KLBF_HOME/prefix/pfx" ] || "$ROOT/scripts/linux/run.sh" check >/dev/null

cd "$ROOT"
case " $* " in *" -p "*|*" --package "*) scope= ;; *) scope=--workspace ;; esac
CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUNNER="$ROOT/scripts/linux/wine-runner.sh" \
CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$ROOT/target/linux-test}" \
PATH="$KLBF_HOME/bin:$PATH" \
    exec cargo xwin test --locked --target "$TARGET" $scope "$@"
