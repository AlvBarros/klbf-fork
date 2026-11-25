# Shared Wine/Proton set-up for run.sh and wine-runner.sh (sourced, not run).
#
# Sets KLBF_HOME, PROTON_DIR, WINEPREFIX, WINEDEBUG, WINEDLLOVERRIDES and WINE,
# and makes sure the prefix uses Microsoft's d3dcompiler_47.dll.
#
# Why d3dcompiler_47: the layer compiles a few compute shaders at run time
# with D3DCompile (the indirect-argument clamp, its worker, the card compare,
# the FFX upscale). Wine's built-in compiler rejects them (no Load4 or
# Interlocked* on RWByteAddressBuffer) and ignores their RootSignature
# attribute; without the clamp every ExecuteIndirect is dropped. Microsoft's
# DLL cannot be shipped here: give it as KLBF_D3DCOMPILER=/path/to/it, put it
# at $KLBF_HOME/d3dcompiler_47.dll, or let this look in your Steam games.

KLBF_HOME="${KLBF_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/klbf-fork}"
PROTON_DIR="${PROTON_DIR:-$HOME/.steam/steam/steamapps/common/Proton 11.0}"
export WINEPREFIX="$KLBF_HOME/prefix/pfx"
export WINEDEBUG="${WINEDEBUG:--all}"
# vkd3d-proton's own pipeline cache, kept out of the working directory.
export VKD3D_SHADER_CACHE_PATH="${VKD3D_SHADER_CACHE_PATH:-$KLBF_HOME/vkd3d-cache}"
mkdir -p "$VKD3D_SHADER_CACHE_PATH"
WINE="$PROTON_DIR/files/bin/wine"

# True for a Microsoft build of the DLL (Wine's own says "Wine builtin DLL").
klbf_is_ms_compiler() {
    [ -f "$1" ] && ! grep -q 'Wine builtin DLL' "$1" && grep -q 'D3DCompile' "$1"
}

klbf_find_compiler() {
    [ -n "$KLBF_D3DCOMPILER" ] && { echo "$KLBF_D3DCOMPILER"; return; }
    [ -f "$KLBF_HOME/d3dcompiler_47.dll" ] && { echo "$KLBF_HOME/d3dcompiler_47.dll"; return; }
    for lib in "$HOME/.local/share/Steam/steamapps/common" "$HOME/.steam/steam/steamapps/common"; do
        [ -d "$lib" ] && find "$lib" -iname d3dcompiler_47.dll -ipath '*win64*' 2>/dev/null
    done | grep -viE '/proton|/files/lib' | while read -r f; do
        klbf_is_ms_compiler "$f" && { echo "$f"; break; }
    done
}

klbf_compiler() {
    sys32="$WINEPREFIX/drive_c/windows/system32/d3dcompiler_47.dll"
    if ! klbf_is_ms_compiler "$sys32"; then
        src=$(klbf_find_compiler)
        if [ -n "$src" ] && klbf_is_ms_compiler "$src"; then
            cp "$src" "$KLBF_HOME/d3dcompiler_47.dll" 2>/dev/null || true
            cp "$src" "$sys32"
            echo "klbf: Microsoft d3dcompiler_47.dll installed in the prefix (from $src)" >&2
        else
            echo "klbf: WARNING: no Microsoft d3dcompiler_47.dll found; with Wine's own," >&2
            echo "      indirect draws are dropped. Set KLBF_D3DCOMPILER=/path/to/d3dcompiler_47.dll" >&2
            return
        fi
    fi
    KLBF_EXTRA_OVERRIDES="d3dcompiler_47=n"
}

klbf_overrides() {
    o="d3d12,d3d12core,dxgi,d3d11=n,b"
    [ -n "$KLBF_EXTRA_OVERRIDES" ] && o="$o;$KLBF_EXTRA_OVERRIDES"
    export WINEDLLOVERRIDES="$o${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
}
