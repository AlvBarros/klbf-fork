#!/bin/sh
# Builds victory.exe (a Windows program) on Linux with cargo-xwin.
#
# No system LLVM is needed: Rust's own llvm-tools stand in for llvm-lib and
# rust-lld for lld-link, through links in $KLBF_HOME/bin.
#
#   scripts/linux/build.sh            # release build
#   scripts/linux/build.sh --features diagnostics
#
# Needs: rustup, and `cargo install --locked cargo-xwin` (it downloads the
# Microsoft CRT and Windows SDK headers/libraries on first use, under
# Microsoft's license).
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
KLBF_HOME="${KLBF_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/klbf-fork}"
TARGET=x86_64-pc-windows-msvc

cd "$ROOT"
command -v cargo-xwin >/dev/null || {
    echo "cargo-xwin is missing: cargo install --locked cargo-xwin" >&2
    exit 1
}
rustup target add "$TARGET" >/dev/null
rustup component add llvm-tools >/dev/null
TOOLS="$(rustc --print sysroot)/lib/rustlib/$(rustc -vV | sed -n 's/^host: //p')/bin"
mkdir -p "$KLBF_HOME/bin"
ln -sf "$TOOLS/llvm-ar" "$KLBF_HOME/bin/llvm-lib"
ln -sf "$TOOLS/llvm-ar" "$KLBF_HOME/bin/llvm-ar"
ln -sf "$TOOLS/rust-lld" "$KLBF_HOME/bin/lld-link"

PATH="$KLBF_HOME/bin:$PATH" cargo xwin build --release --locked -p victory --target "$TARGET" "$@"
echo "built: $ROOT/target/$TARGET/release/victory.exe"
