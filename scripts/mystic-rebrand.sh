#!/usr/bin/env bash
#
# Apply Mystic Recovery branding to a synchronized PBRP source tree.
#
# Examples:
#   ./scripts/mystic-rebrand.sh --root ~/mystic-src --dry-run
#   ./scripts/mystic-rebrand.sh --root ~/mystic-src --accent 7C4DFF
#   ./scripts/mystic-rebrand.sh --root ~/mystic-src --check
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(pwd)"
ACCENT="${MYSTIC_ACCENT_HEX:-7C4DFF}"
MODE=()
ASSETS=1

usage() {
    cat <<'EOF'
Usage: mystic-rebrand.sh [options]

  --root DIR       Android/PBRP source root (default: current directory)
  --accent HEX     accent colour without # (default: 7C4DFF)
  --dry-run        show files that would change, do not write
  --check          only scan for remaining user-facing PitchBlack/PBRP text
  --no-assets      do not regenerate splash/logo/button images
  -h, --help       show this help

Environment:
  MYSTIC_ACCENT_HEX   default accent colour without #
EOF
}

while (($#)); do
    case "$1" in
        --root)
            [[ $# -ge 2 ]] || { echo "error: --root needs a value" >&2; exit 2; }
            ROOT="$2"
            shift 2
            ;;
        --accent)
            [[ $# -ge 2 ]] || { echo "error: --accent needs a value" >&2; exit 2; }
            ACCENT="$2"
            shift 2
            ;;
        --dry-run|--check)
            MODE+=("$1")
            shift
            ;;
        --no-assets)
            ASSETS=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

ROOT="$(cd -- "$ROOT" && pwd -P)" || {
    echo "error: source root does not exist: $ROOT" >&2
    exit 2
}

if [[ ! -d "$ROOT/bootable/recovery" ]]; then
    echo "error: $ROOT does not contain bootable/recovery" >&2
    echo "       run repo sync first, then point --root at the source tree" >&2
    exit 2
fi

ACCENT="${ACCENT#\#}"
if [[ ! "$ACCENT" =~ ^[0-9A-Fa-f]{6}$ ]]; then
    echo "error: accent must be a six-digit hex RGB value, got: $ACCENT" >&2
    exit 2
fi

echo "Mystic rebrand"
echo "  source: $ROOT"
echo "  accent: #$ACCENT"
echo

python3 "$SCRIPT_DIR/mystic_rebrand.py" --root "$ROOT" --accent "$ACCENT" "${MODE[@]}"

if [[ " ${MODE[*]:-} " != *" --check "* && "$ASSETS" == "1" ]]; then
    asset_args=(--root "$ROOT")
    [[ " ${MODE[*]:-} " == *" --dry-run "* ]] && asset_args+=(--dry-run)
    python3 "$SCRIPT_DIR/mystic_assets.py" "${asset_args[@]}"
fi

if ((${#MODE[@]} == 0)); then
    echo
    echo "Branding applied. Review changes with:"
    echo "  git -C \"$ROOT\" status --short"
    echo "  \"$SCRIPT_DIR/mystic-rebrand.sh\" --root \"$ROOT\" --check"
fi
