<p align="center"><img src="docs/klbf/logo.svg" width="120" alt="KLBF Lab"></p>
<h1 align="center">KLBF Lab — Linux / NVIDIA fork</h1>
<p align="center">
  <img src="https://img.shields.io/badge/base-KLBF%20Lab%2035-1f46c8" alt="base: KLBF Lab 35">
  <img src="https://img.shields.io/badge/host-Linux%20%2B%20Proton-555" alt="host: Linux + Proton">
  <img src="https://img.shields.io/badge/GPU-NVIDIA%20RTX%204070-555" alt="GPU: NVIDIA RTX 4070">
  <img src="https://img.shields.io/badge/license-GPL--3.0-555" alt="GPL-3.0">
</p>

A fork of [KLBF Lab](https://github.com/PastiiJay/klbf-lab) (a GDK compatibility layer that runs the Xbox Series X|S build of the game on a PC) for one machine: **Linux under Proton, with an NVIDIA card**. KLBF Lab is built and tested on Windows with an AMD Radeon; this fork adds a Linux build and launcher, and takes fixes from KLBF Lab and the other open forks when they help on this setup.

The upstream README, with KLBF Lab's own results on its AMD machine, is kept as [README.klbf.md](README.klbf.md).

No game files are included. You need your own legally obtained copy.

## The machine

| | |
|---|---|
| GPU | NVIDIA GeForce RTX 4070, 12 GB (driver 595.71, proprietary) |
| CPU | Intel Core i5-14400F (AVX2) |
| RAM | 32 GB |
| OS | Arch Linux, kernel 6.18 LTS |
| Runs through | Proton 11.0 (Wine + vkd3d-proton for Direct3D 12) |
| Built with | Rust 1.98.1 and [cargo-xwin](https://github.com/rust-cross/cargo-xwin), cross-compiled for `x86_64-pc-windows-msvc` |

What vkd3d-proton reports on this card: shader model 6.6–6.8, mesh shaders, DXR 1.1 ("DX Ultimate"); 32-lane waves.

## Status (2026-11-25)

| | Status | Notes |
|---|---|---|
| Build on Linux | ✅ | `scripts/linux/build.sh` |
| Starts under Proton, Direct3D 12 device created | ✅ | `scripts/linux/run.sh check` |
| Wine/vkd3d-proton pipeline library (shader cache kept between runs) | ✅ | from KLBF Lab (gmankab, upstream VIctory#347) |
| Runtime compute shaders (indirect clamp, card compare, FFX) | ✅ with Microsoft's `d3dcompiler_47.dll` | Wine's own compiler rejects them, and without the clamp every indirect draw is dropped; the scripts install Microsoft's DLL into the prefix (see below) |
| Test suite under Proton (`scripts/linux/test.sh`) | ✅ 534 of 541 | the 7 left: 3 need `dxil.dll`; 2 start `cargo`/`git` inside Wine; vkd3d-proton accepts unsigned DXIL; Wine's `ws2_32` lacks `WSAConnectByList` |
| In game | ⏳ not run yet | results will go here |

Taken from other forks:

- **Constant ambient light** (from [Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD)): the game's ray-traced indirect light does not run, which leaves shadowed areas black and foliage magenta. Right after the pass that should resolve it, its output is replaced by a constant, darkened in creases from the depth buffer. `VICTORY_AMBIENT=<level>` (0.6 by default; Belobug found ~0.07 bluish right at night, ~0.3 warm at dusk), `VICTORY_AMBIENT_TINT=r,g,b`, `VICTORY_AMBIENT_SHADE=strength,radius`, `VICTORY_AMBIENT=off` for the game's own output. Builds and runs on the GPU in the tests; not yet seen in game.
- **No blending on integer render targets** (pgm1207 and Arvi23, Belobug's PR #45): the game leaves blending on for an `R8_UINT` world target; vkd3d-proton refuses that pipeline ("using integer format is not supported") and its draws were lost. A test on the GPU checks the refusal and that the fixed state is accepted.
- **Helper lanes in pixel shaders** (Belobug f520772 / upstream VIctory 0601955, Belobug 03629f3, test from VIctory-dexnom 921d8d3): a helper lane's `v_readfirstlane` takes its own value, so the console's first-lane loops cannot spin to their limit at triangle edges; quad permutations in pixel shaders read through quad reads, which reach helper lanes. On this card the quad-read test passes with or without the second fix (the line artifacts it cures were seen on AMD); both are kept as spec-correct. The `IsHelperLane` the first one emits is checked to build and draw through vkd3d-proton.

What differs from KLBF Lab on this setup:

- **The AMD shader skip is off.** KLBF Lab skips shader `39f0e9aeb156a61c` because AMD's compiler never finishes it; the Linux launcher sets `VICTORY_SKIP_PIPELINES` empty unless you set it yourself, so nothing is skipped on NVIDIA.
- **Wave size:** KLBF Lab's per-half-wave handling of the console's 32-lane programs is only for 64-lane hosts. It switches itself off on NVIDIA, which runs 32-lane waves.
- **AMD FSR** (`--console series-s`) needs AMD's FidelityFX SDK DLLs (see [README.klbf.md](README.klbf.md#run)). FSR runs on NVIDIA, but loading those DLLs under Wine is untested here.

## Build (Linux)

Needs `rustup`, Steam with Proton 11.0 installed, and `cargo install --locked cargo-xwin`. No system LLVM or sudo is needed: the script uses Rust's own LLVM tools.

```sh
scripts/linux/build.sh
```

The first build downloads the Microsoft CRT and Windows SDK files through cargo-xwin (Microsoft's license applies).

## Run (Linux)

```sh
scripts/linux/run.sh check                                    # Direct3D 12 device check, no game needed
scripts/linux/run.sh prebuild "/path/to/game/shaders.rpf"     # optional: pre-build pipelines once
scripts/linux/run.sh play "/path/to/game/<the title's exe>"   # play
scripts/linux/run.sh play "/path/to/game/<the title's exe>" --console series-s
```

The prefix, shader cache, saves and logs live in `~/.local/share/klbf-fork` (`KLBF_HOME` to change it); each run writes a log in `logs/`. `PROTON_DIR` picks another Proton (for example `Proton - Experimental` for a newer vkd3d-proton). `VICTORY_*` settings from [README.klbf.md](README.klbf.md#run) pass through, e.g. `VICTORY_LATE_WAIT=1 scripts/linux/run.sh play ...`.

Plug the controller in before starting. With `--console series-s` the start screen stays black: press **A** (or **Enter** with the window focused).

**Microsoft's `d3dcompiler_47.dll` is required.** The layer compiles a few compute shaders at run time with `D3DCompile`; Wine's built-in compiler rejects them (no `Load4`/`Interlocked*` on `RWByteAddressBuffer`) and ignores their `RootSignature`. The scripts install Microsoft's DLL into the prefix and prefer it: they take `KLBF_D3DCOMPILER=/path/to/d3dcompiler_47.dll`, or `~/.local/share/klbf-fork/d3dcompiler_47.dll`, or find one shipped with an installed Steam game. It cannot be included in this repository. Without it the scripts print a warning.

## Test (Linux)

```sh
scripts/linux/test.sh                    # whole suite, built for Windows and run under Proton's wine
scripts/linux/test.sh -p victory-gpu     # one crate (the Direct3D 12 tests run on the GPU through vkd3d-proton)
```

Plain `cargo test` cannot build the Windows-only crates on Linux; `test.sh` sets `scripts/linux/wine-runner.sh` as the runner for the Windows target only, so Windows machines still run tests natively.

Note for anyone running Proton's `wine` by hand: it needs `WINEDLLOVERRIDES="d3d12,d3d12core,dxgi,d3d11=n,b"`, or Wine's built-in Direct3D 12 is used and the device fails with "Invalid parameter". The launcher sets it.

## Windows

The Windows instructions are unchanged from KLBF Lab: see [README.klbf.md](README.klbf.md#run).

## Credits

This fork is [KLBF Lab](https://github.com/PastiiJay/klbf-lab) by PastiiJay and its contributors, which started from [VIctory](https://github.com/Marvisak/VIctory) by Marvisak and the [fxceless/victory-fork](https://github.com/fxceless/victory-fork) (see [README.klbf.md](README.klbf.md) and [README.fxceless.md](README.fxceless.md)). It is GPL-3.0 like them and keeps their copyright notices. Fixes taken from other projects are credited in their commit messages.

Product names are only used to say what this works with; they belong to their owners. This fork is not affiliated with them.
