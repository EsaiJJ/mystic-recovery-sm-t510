#!/usr/bin/env bash
#
# Mystic Recovery - source build and packaging script
#
# Usage:
#   ./build_mystic.sh install-deps
#   ./build_mystic.sh sync
#   ./build_mystic.sh brand
#   ./build_mystic.sh build
#   ./build_mystic.sh package
#   ./build_mystic.sh all
#
# Environment:
#   MYSTIC_SRC=/path/to/pbrp-source      default: $HOME/mystic-src
#   JOBS=8                               default: nproc
#   SKIP_DISK_CHECK=1                    bypass the 80 GiB free-space guard
#   MYSTIC_ACCENT_HEX=7C4DFF             brand accent colour
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="${MYSTIC_ROOT:-$SCRIPT_DIR}"
SRC="${MYSTIC_SRC:-$HOME/mystic-src}"
DEVICE_REL="device/samsung/gta3xlwifi"
PRODUCT="gta3xlwifi"
LUNCH_TARGET="mystic_gta3xlwifi-eng"
MANIFEST_URL="${PBRP_MANIFEST:-https://github.com/PitchBlackRecoveryProject/manifest_pb}"
MANIFEST_BRANCH="${PBRP_BRANCH:-android-12.1}"
JOBS="${JOBS:-$(nproc --all 2>/dev/null || echo 4)}"
ACCENT="${MYSTIC_ACCENT_HEX:-7C4DFF}"
VERSION="${MYSTIC_VERSION:-1.0}"
DIST="$ROOT/dist"
DEVICE_OUT="$SRC/out/target/product/$PRODUCT"
REQUIRED_FREE_KB=$((80 * 1024 * 1024))

export LC_ALL=C
export PATH="$HOME/bin:$PATH"

if [[ -d /usr/lib/jvm/java-11-openjdk-amd64 && -z "${JAVA_HOME:-}" ]]; then
    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
    export PATH="$JAVA_HOME/bin:$PATH"
fi

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '\nwarning: %s\n' "$*" >&2; }
die()  { printf '\nerror: %s\n' "$*" >&2; exit 1; }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

disk_check() {
    mkdir -p "$(dirname "$SRC")"
    local avail_kb
    avail_kb="$(df -Pk "$(dirname "$SRC")" | awk 'NR==2 {print $4}')"
    [[ -n "$avail_kb" ]] || die "could not read free disk space"
    if (( avail_kb < REQUIRED_FREE_KB )); then
        printf 'Free space: %s\n' "$(df -h "$(dirname "$SRC")" | awk 'NR==2 {print $4}')"
        if [[ "${SKIP_DISK_CHECK:-0}" != "1" ]]; then
            die "at least 80 GiB free is required for a full AOSP 12/PBRP build (set SKIP_DISK_CHECK=1 to override)"
        fi
        warn "proceeding despite low disk space because SKIP_DISK_CHECK=1"
    fi
}

install_deps() {
    log "Installing host packages"
    local apt_cmd=(apt-get)
    if [[ $EUID -ne 0 ]]; then
        command -v sudo >/dev/null 2>&1 || die "sudo is required to install packages"
        apt_cmd=(sudo apt-get)
    fi

    "${apt_cmd[@]}" update
    "${apt_cmd[@]}" install -y --no-install-recommends \
        bc bison build-essential ca-certificates ccache curl file flex \
        g++-multilib gcc-multilib git gnupg gperf libelf-dev liblz4-tool \
        libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop openjdk-11-jdk \
        pngcrush python3 python3-pil rsync schedtool squashfs-tools unzip \
        xsltproc zip zlib1g-dev

    if ! command -v repo >/dev/null 2>&1; then
        log "Installing the repo launcher into $HOME/bin"
        mkdir -p "$HOME/bin"
        curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
        chmod +x "$HOME/bin/repo"
    fi

    command -v repo >/dev/null 2>&1 || die "repo is still not on PATH; add $HOME/bin to PATH"
    echo "Host dependencies installed."
    echo "Use Java 11 for the AOSP 12 build (this script selects it automatically when present)."
}

sync_sources() {
    need_cmd repo
    need_cmd git
    need_cmd rsync
    disk_check

    log "Synchronizing PBRP $MANIFEST_BRANCH into $SRC"
    mkdir -p "$SRC"
    cd "$SRC"

    if [[ ! -d .repo ]]; then
        repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --no-clone-bundle
    fi

    repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags

    log "Adding local device tree manifest"
    mkdir -p .repo/local_manifests
    cp "$ROOT/local_manifests/mystic.xml" .repo/local_manifests/mystic.xml
    repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags "$DEVICE_REL"

    log "Overlaying Mystic device configuration"
    mkdir -p "$SRC/$DEVICE_REL"
    rsync -a --exclude 'prebuilt/' "$ROOT/$DEVICE_REL/" "$SRC/$DEVICE_REL/"

    [[ -f "$SRC/$DEVICE_REL/prebuilt/kernel" ]] || \
        die "missing $SRC/$DEVICE_REL/prebuilt/kernel (device tree sync failed?)"
    [[ -f "$SRC/$DEVICE_REL/prebuilt/recovery_dtbo" ]] || \
        die "missing $SRC/$DEVICE_REL/prebuilt/recovery_dtbo"

    echo "Sources ready: $SRC"
}

brand_sources() {
    log "Applying Mystic branding"
    "$ROOT/scripts/mystic-rebrand.sh" --root "$SRC" --accent "$ACCENT"
}

prepare_pb_devices() {
    # vendor/pb/config/common.mk reads this cache file at make time.
    if ! curl -fsSL \
        "https://raw.githubusercontent.com/PitchBlackRecoveryProject/vendor_utils/pb/pb_devices.json" \
        -o /tmp/pb_devices.json; then
        warn "could not download /tmp/pb_devices.json; maintainer field will be empty"
    fi
}

build_recovery() {
    disk_check

    log "Building recovery image and flashable ZIP"
    prepare_pb_devices

    (
        cd "$SRC"
        set +u
        # shellcheck disable=SC1091
        source build/envsetup.sh
        if ! lunch "$LUNCH_TARGET"; then
            warn "lunch $LUNCH_TARGET failed; trying mystic_gta3xlwifi-userdebug"
            lunch mystic_gta3xlwifi-userdebug
        fi
        mka recoveryimage -j"$JOBS"
        mka pbrp -j"$JOBS"
    )

    local img="$DEVICE_OUT/recovery.img"
    [[ -f "$img" ]] || die "recovery image not found: $img"

    local size max
    size="$(stat -c %s "$img")"
    max=$((0x02D00000))
    if (( size > max )); then
        die "recovery.img is $size bytes, larger than the 45 MiB recovery partition ($max)"
    fi
    printf 'recovery.img: %s bytes (%s)\n' "$size" "$(du -h "$img" | awk '{print $1}')"
}

package_outputs() {
    log "Packaging Odin and ZIP artifacts"
    local img="$DEVICE_OUT/recovery.img"
    [[ -f "$img" ]] || die "recovery image not found: $img"

    mkdir -p "$DIST"
    local base="Mystic-Recovery-${PRODUCT}-${VERSION}"
    local tar_name="${base}.tar"
    local img_name="${base}.img"

    cp -f "$img" "$DIST/$img_name"

    local tmp
    tmp="$(mktemp -d)"
    cp -f "$img" "$tmp/recovery.img"
    (
        cd "$tmp"
        tar -H ustar -cf "$DIST/$tar_name" recovery.img
    )
    rm -rf "$tmp"

    # Odin .tar.md5 is a tar archive with the MD5 text appended, not a
    # standalone checksum file.
    cp -f "$DIST/$tar_name" "$DIST/$tar_name.md5"
    (
        cd "$DIST"
        md5sum "$tar_name" >> "$tar_name.md5"
    )

    local zipfile
    zipfile="$(find "$DEVICE_OUT" -maxdepth 1 -type f -name 'Mystic-*.zip' -print -quit || true)"
    if [[ -z "$zipfile" ]]; then
        zipfile="$(find "$DEVICE_OUT" -maxdepth 1 -type f -name 'PBRP-*.zip' -print -quit || true)"
    fi
    if [[ -n "$zipfile" ]]; then
        cp -f "$zipfile" "$DIST/${base}-flashable.zip"
    else
        warn "flashable ZIP not found in $DEVICE_OUT (run ./build_mystic.sh build first)"
    fi

    (
        cd "$DIST"
        sha256sum "$img_name" "$tar_name" "$tar_name.md5" > SHA256SUMS
        if [[ -f "${base}-flashable.zip" ]]; then
            sha256sum "${base}-flashable.zip" >> SHA256SUMS
        fi
    )

    log "Artifacts in $DIST"
    ls -lh "$DIST"
}

usage() {
    cat <<'EOF'
Usage: ./build_mystic.sh <mode>

Modes:
  install-deps   install Ubuntu/Debian host packages and the repo launcher
  sync           repo init/sync PBRP, add gta3xlwifi tree, overlay Mystic config
  brand          apply Mystic branding to a synchronized tree
  build          build recoveryimage and the PBRP/Mystic flashable ZIP
  package        create recovery.img, Odin .tar/.tar.md5 and ZIP copies in dist/
  all            sync + brand + build + package

Environment:
  MYSTIC_SRC       source tree (default: $HOME/mystic-src)
  JOBS             parallel build jobs (default: nproc)
  SKIP_DISK_CHECK  set to 1 to bypass the 80 GiB free-space guard
  MYSTIC_ACCENT_HEX  accent colour without # (default: 7C4DFF)
EOF
}

case "${1:-all}" in
    install-deps) install_deps ;;
    sync)         sync_sources ;;
    brand)        brand_sources ;;
    build)        build_recovery ;;
    package)      package_outputs ;;
    all)
        sync_sources
        brand_sources
        build_recovery
        package_outputs
        ;;
    -h|--help|help) usage ;;
    *) usage; exit 2 ;;
esac
