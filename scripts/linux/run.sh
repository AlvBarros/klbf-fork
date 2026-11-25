#!/bin/sh
# Runs victory.exe under Proton's Wine (vkd3d-proton provides Direct3D 12).
#
#   scripts/linux/run.sh check                       # GPU device check, no game needed
#   scripts/linux/run.sh prebuild /path/to/shaders.rpf
#   scripts/linux/run.sh play /path/to/<the title's exe> [victory run options...]
#
# Settings (environment):
#   PROTON_DIR   Proton install (default: Steam's "Proton 11.0")
#   KLBF_HOME    prefix, cache, saves and logs (default: ~/.local/share/klbf-fork)
#   VICTORY_*    passed through to victory.exe (see README.md)
#   KLBF_D3DCOMPILER  Microsoft's d3dcompiler_47.dll, if not found (see env.sh)
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/scripts/linux/env.sh"
EXE="${KLBF_EXE:-$ROOT/target/x86_64-pc-windows-msvc/release/victory.exe}"

[ -x "$PROTON_DIR/proton" ] || { echo "no Proton at $PROTON_DIR (set PROTON_DIR)" >&2; exit 1; }
[ -f "$EXE" ] || { echo "no $EXE: run scripts/linux/build.sh first" >&2; exit 1; }
mkdir -p "$KLBF_HOME/cache" "$KLBF_HOME/data" "$KLBF_HOME/logs" "$KLBF_HOME/prefix"

# A Windows path for a Linux one (Wine maps / to Z:).
winpath() { printf 'Z:%s' "$(realpath "$1")" | tr / '\\'; }

# First run: let Proton create the prefix and install vkd3d-proton/DXVK into it.
if [ ! -d "$KLBF_HOME/prefix/pfx" ]; then
    echo "creating the Wine prefix (once)..."
    STEAM_COMPAT_DATA_PATH="$KLBF_HOME/prefix" \
    STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam" \
        "$PROTON_DIR/proton" run "$EXE" config >/dev/null 2>&1 || true
fi

# Proton's wine run directly does not apply the d3d12/dxgi overrides by
# itself; without them Wine's built-in d3d12 is used and device creation fails
# ("Invalid parameter"). Microsoft's d3dcompiler_47 too: see env.sh.
klbf_compiler
klbf_overrides
export VICTORY_CACHE_DIR="$(winpath "$KLBF_HOME/cache")"
export VICTORY_DATA_DIR="$(winpath "$KLBF_HOME/data")"
# The built-in skip list holds a shader that hangs the AMD compiler only;
# on other cards nothing is skipped unless VICTORY_SKIP_PIPELINES is set.
export VICTORY_SKIP_PIPELINES="${VICTORY_SKIP_PIPELINES-}"
LOG="$KLBF_HOME/logs/$(date +%Y%m%d-%H%M%S)-${1:-run}.log"

case "$1" in
check)
    mkdir -p "$KLBF_HOME/empty"
    "$WINE" "$EXE" translate --pipelines "$(winpath "$KLBF_HOME/empty")" 2>&1 | tee "$LOG"
    ;;
prebuild)
    [ -n "$2" ] || { echo "usage: $0 prebuild /path/to/shaders.rpf" >&2; exit 2; }
    "$WINE" "$EXE" translate --cache --pipelines --jobs "${JOBS:-8}" "$(winpath "$2")" 2>&1 | tee "$LOG"
    ;;
play)
    [ -n "$2" ] || { echo "usage: $0 play /path/to/<the title's exe> [options]" >&2; exit 2; }
    game=$(winpath "$2"); shift 2
    unset VICTORY_KEYS VICTORY_CAPTURE VICTORY_CAPTURE_FRAMES VICTORY_DUMP_TARGETS
    "$WINE" "$EXE" run "$@" "$game" --execute > "$LOG" 2>&1 || true
    ;;
*)
    sed -n 4,6p "$0" >&2; exit 2
    ;;
esac
echo "log: $LOG"
