# Mystic Recovery for Samsung Galaxy Tab A 10.1 (SM-T510 / gta3xlwifi)

Mystic Recovery is a source-built rebrand of
[PitchBlack Recovery Project](https://github.com/PitchBlackRecoveryProject)
for the Samsung Galaxy Tab A 10.1" 2019 Wi-Fi tablet (Exynos 7904).

This repository contains only the device configuration, rebrand automation,
build wrapper and packaging logic. The recovery engine itself is compiled
from the official PBRP `android-12.1` sources.

## Status

Scaffold and build automation are complete; **no image in this repository has
been built or tested on hardware yet**. Treat every build as experimental and
keep a known-good recovery/backup available.

## Device facts used here

| Item | Value |
| --- | --- |
| Model | SM-T510 |
| Codename | `gta3xlwifi` |
| SoC | Exynos 7904, reported by stock firmware as `exynos7885` / `universal7885` |
| Architecture | 32-bit recovery userspace (`armeabi-v7a`, Cortex-A53) |
| Display | 1200 x 1920 |
| Boot image | kernel base `0x10000000`, page size 2048, header v1 |
| Recovery partition | 45 MiB (`0x02D00000`) |
| Prebuilt kernel / DTBO | from `gta3xlwifi-dev/android_device_samsung_gta3xlwifi_twrp` |

The base tree contains some values copied from another Samsung device
(`Galaxy A14` MTP name and a 1080x2408 screen). Those are corrected here.
Do not change `TARGET_SOC` to `exynos7904`; the stock kernel and bootloader
use the `exynos7885`/`universal7885` names.

## Host requirements

- Ubuntu 22.04 or 24.04 (or a compatible Debian host).
- At least **100 GiB free disk**; the build script refuses to start below
  80 GiB unless `SKIP_DISK_CHECK=1`.
- 16 GiB RAM recommended, plus swap.
- Java 11 for the AOSP 12 tree (the build script selects it when installed).
- `repo`, `git`, `rsync`, `python3`, and the normal AOSP build packages.

The helper can install Ubuntu packages and the `repo` launcher:

```bash
./build_mystic.sh install-deps
```

It installs `repo` into `$HOME/bin`; ensure that directory is on `PATH`.

## Building

Choose a source directory on a large filesystem:

```bash
export MYSTIC_SRC=/srv/android/mystic-pbrp
export JOBS=16

./build_mystic.sh sync
./build_mystic.sh brand
./build_mystic.sh build
./build_mystic.sh package
```

Or run the whole sequence:

```bash
./build_mystic.sh all
```

What each mode does:

- `sync`: `repo init`/`repo sync` the PBRP `android-12.1` manifest, fetch the
  `gta3xlwifi` base tree via `local_manifests/mystic.xml`, and overlay this
  repository's device files over it.
- `brand`: rewrite user-facing PBRP/PitchBlack strings and tool paths, change
  the accent colour from `#0090CA` to `#7C4DFF`, rename
  `vendor/utils/PBRP` to `vendor/utils/Mystic`, and regenerate the splash,
  logo, about and PBRP button images using Pillow.
- `build`: `lunch mystic_gta3xlwifi-eng`, then `mka recoveryimage` and
  `mka pbrp`.
- `package`: copy `recovery.img`, create an Odin `.tar`/`.tar.md5`, keep the
  flashable ZIP, and write `dist/SHA256SUMS`.

Expected outputs:

```text
out/target/product/gta3xlwifi/recovery.img
out/target/product/gta3xlwifi/Mystic-gta3xlwifi-*.zip
dist/Mystic-Recovery-gta3xlwifi-1.0.img
dist/Mystic-Recovery-gta3xlwifi-1.0.tar
dist/Mystic-Recovery-gta3xlwifi-1.0.tar.md5
dist/Mystic-Recovery-gta3xlwifi-1.0-flashable.zip
```

`mka recoveryimage` alone only produces `recovery.img`. The flashable ZIP is
produced by `mka pbrp` and contains the PBRP/Mystic tools payload that is
installed to `/sdcard/Mystic/tools`.

## Flashing

1. Unlock the SM-T510 bootloader and enable USB debugging.
2. Back up anything important. Flashing recovery can wipe data.
3. Download mode: power off, then hold **Volume Down + Power** and connect USB.
4. In Odin, load `dist/Mystic-Recovery-gta3xlwifi-1.0.tar` in **AP**.
5. Disable **Auto Reboot**, flash, then boot directly into recovery with
   **Volume Up + Power**.
6. Optional: flash `dist/Mystic-Recovery-gta3xlwifi-1.0-flashable.zip` from
   recovery to install the Mystic tools payload.

If recovery does not boot, re-flash a known-good recovery immediately and
capture the Odin/recovery log before changing anything else.

## Branding details

- Visible name: **Mystic Recovery**.
- Accent: **`#7C4DFF`**.
- User data path for themes, fonts and tools: **`/sdcard/Mystic`**.
- Flashable ZIP prefix: **`Mystic-`**.
- Safe rebrand mode leaves internal identifiers (`PB_*`, `pbrp` make targets,
  `ro.pb.*`, resource filenames) unchanged so the PBRP engine keeps working.
- Copyright/license lines are preserved.

Review or re-check branding on a synchronized tree:

```bash
./scripts/mystic-rebrand.sh --root "$MYSTIC_SRC" --dry-run
./scripts/mystic-rebrand.sh --root "$MYSTIC_SRC" --check
```

Image generation requires Pillow (`python3-pil`, installed by
`install-deps`). Use `--no-assets` if you want to keep the original theme
images.

## Repository layout

```text
build_mystic.sh                         build/sync/brand/package wrapper
device/samsung/gta3xlwifi/              BoardConfig, product, fstab, mkbootimg
local_manifests/mystic.xml              base gta3xlwifi tree
scripts/mystic-rebrand.sh               branding wrapper
scripts/mystic_rebrand.py               safe text/XML rebrand worker
scripts/mystic_assets.py                Pillow splash/logo/button generator
.github/workflows/build-mystic.yml      lint + self-hosted build workflow
```

## Known limitations

- Encryption support is intentionally disabled until the correct keymaster,
  keydata and metadata configuration is verified for this tablet.
- Vendor/data/product partition sizes are not asserted beyond the recovery
  image limit; do not add guessed sizes.
- PBRP `android-12.1` with the `twrp-11` device tree has not been validated on
  hardware in this repository.
- GitHub-hosted runners do not have enough disk for a full AOSP build. The
  build job expects a self-hosted runner with at least 100 GiB free.

## Legal

PBRP, TWRP and the Android build system are distributed under their respective
open-source licenses (Apache-2.0 and GPL where applicable). This repository
keeps those notices intact. You are responsible for complying with the
licenses of every component you build and redistribute, and for any warranty,
bootloader-unlock or data-loss consequences of flashing experimental software.
