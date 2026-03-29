#!/usr/bin/env bash
set -euo pipefail

# BLANK_SFD and PATCHER can be set by the caller (e.g. Nix wrapper).
# Fall back to discovering them relative to this script's location.
if [[ -z "${BLANK_SFD:-}" || -z "${PATCHER:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    BLANK_SFD="${BLANK_SFD:-$PACKAGE_DIR/share/NerdFontsSymbolsNerdFontBlank.sfd}"
    PATCHER="${PATCHER:-$PACKAGE_DIR/bin/nerd-font-patcher}"
fi
BLANK_EM=2048

usage() {
    echo "Usage: nerd-font-patcher-symbols [-o OUTPUT_DIR] [-n NAME] SOURCE_FONT"
    echo ""
    echo "Build a symbols-only Nerd Font TTF scaled to match a monospaced source font."
    echo ""
    echo "Arguments:"
    echo "  SOURCE_FONT    Path to a monospaced font (OTF/TTF) to probe metrics from"
    echo ""
    echo "Options:"
    echo "  -o DIR         Output directory (default: current directory)"
    echo "  -n NAME        Font name for output file and metadata (e.g. SymbolsNerdFontIosevkata)"
    echo "  -h, --help     Show this help message"
    exit "${1:-0}"
}

OUTPUT_DIR="."
FONT_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) OUTPUT_DIR="$2"; shift 2 ;;
        -n) FONT_NAME="$2"; shift 2 ;;
        -h|--help) usage 0 ;;
        -*) echo "Error: Unknown option: $1" >&2; usage 1 ;;
        *)
            if [[ -n "${SOURCE_FONT:-}" ]]; then
                echo "Error: Unexpected argument: $1" >&2
                usage 1
            fi
            SOURCE_FONT="$1"; shift
            ;;
    esac
done

if [[ -z "${SOURCE_FONT:-}" ]]; then
    echo "Error: SOURCE_FONT is required" >&2
    usage 1
fi

if [[ ! -f "$SOURCE_FONT" ]]; then
    echo "Error: Source font not found: $SOURCE_FONT" >&2
    exit 1
fi

if [[ ! -f "$BLANK_SFD" ]]; then
    echo "Error: Blank SFD not found: $BLANK_SFD" >&2
    exit 1
fi

# Probe the source font's cell width, EM, and vertical metrics
echo "Probing source font: $SOURCE_FONT"
read -r SRC_WIDTH SRC_EM SRC_TYPO_ASCENT SRC_TYPO_DESCENT < <(
    python3 - "$SOURCE_FONT" <<'PYEOF'
import fontforge, sys
f = fontforge.open(sys.argv[1])
g = f[ord('M')]
print(g.width, f.em, f.os2_typoascent, f.os2_typodescent)
f.close()
PYEOF
)
echo "  Source: cell width=$SRC_WIDTH, EM=$SRC_EM, typo ascent=$SRC_TYPO_ASCENT, descent=$SRC_TYPO_DESCENT"

# Scale to blank SFD's EM
SCALED_WIDTH=$(python3 -c "print(int(round($SRC_WIDTH * $BLANK_EM / $SRC_EM)))")
SCALED_ASCENT=$(python3 -c "print(int(round($SRC_TYPO_ASCENT * $BLANK_EM / $SRC_EM)))")
SCALED_DESCENT=$(python3 -c "print(int(round($SRC_TYPO_DESCENT * $BLANK_EM / $SRC_EM)))")
echo "  Scaled to EM=$BLANK_EM: width=$SCALED_WIDTH, ascent=$SCALED_ASCENT, descent=$SCALED_DESCENT"

# Build patcher arguments
PATCHER_ARGS=(
    "$BLANK_SFD"
    --cell "0:${SCALED_WIDTH}:${SCALED_DESCENT}:${SCALED_ASCENT}"
    --complete
    -ext ttf
    --outputdir "$OUTPUT_DIR"
)
if [[ -n "$FONT_NAME" ]]; then
    PATCHER_ARGS+=(--name "$FONT_NAME")
fi

# Run the patcher
mkdir -p "$OUTPUT_DIR"
echo "Running nerd-font-patcher..."
"$PATCHER" "${PATCHER_ARGS[@]}"

echo "Done. Output in $OUTPUT_DIR/"
ls -la "$OUTPUT_DIR/"*.ttf 2>/dev/null || true
