#!/usr/bin/env bash
# vidfix end-to-end tests - uses generated fixtures only, no external files
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIDFIX="$ROOT/bin/vidfix"
INSTALLER="$ROOT/install.sh"
FFMPEG="${FFMPEG:-ffmpeg}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()  { printf '  PASS  %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }

assert_contains() {
  case "$1" in
    *"$2"*) ok "$3" ;;
    *)      bad "$3 (expected to contain '$2')" ;;
  esac
}

assert_eq() {
  if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (expected '$1', got '$2')"; fi
}

assert_file() {
  if [ -e "$1" ]; then ok "$2"; else bad "$2 (missing: $1)"; fi
}

assert_no_file() {
  if [ ! -e "$1" ]; then ok "$2"; else bad "$2 (should not exist: $1)"; fi
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

command -v "$FFMPEG" >/dev/null 2>&1 || { echo "ffmpeg is required, skipping"; exit 1; }
[ -x "$VIDFIX" ] || { echo "vidfix not found: $VIDFIX"; exit 1; }
VERSION="$(grep -m1 '^VERSION=' "$VIDFIX" | cut -d'"' -f2)"
[ -n "$VERSION" ] || { echo "could not read VERSION from $VIDFIX"; exit 1; }

echo "vidfix test suite"
echo

# --- fixtures ----------------------------------------------------------------
echo "fixtures"
"$FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i testsrc2=size=1920x1080:rate=30:duration=2 \
  -f lavfi -i "sine=frequency=440:duration=2" \
  -c:v libx264 -profile:v high422 -pix_fmt yuv422p -c:a aac "$TMP/bad.mp4"
"$FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i testsrc2=size=1280x720:rate=30:duration=2 \
  -c:v libx264 -pix_fmt yuv420p "$TMP/good.mp4"
"$FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i testsrc2=size=640x480:rate=30:duration=1 \
  -c:v libx264 -pix_fmt yuv420p "$TMP/silent.mp4"
echo "  generated bad.mp4 (4:2:2 + audio), good.mp4 (4:2:0), silent.mp4 (no audio)"
echo

BEFORE="$(sha256_of "$TMP/bad.mp4")"

# --- diagnostics -------------------------------------------------------------
echo "check: problematic file"
OUT="$("$VIDFIX" check "$TMP/bad.mp4" 2>&1)" && RC=0 || RC=$?
assert_contains "$OUT" "4:2:2" "check flags the 4:2:2 chroma problem"
assert_contains "$OUT" "Problems" "check lists the problems"
assert_eq "$RC" "1" "check exits 1 when problems are found"

echo
echo "check: normal file"
OUT="$("$VIDFIX" check "$TMP/good.mp4" 2>&1)" && RC=0 || RC=$?
assert_contains "$OUT" "NO PROBLEMS FOUND" "check reports a healthy file"
assert_eq "$RC" "0" "check exits 0 when no problems are found"

echo
echo "check: missing file"
"$VIDFIX" check "$TMP/nope.mp4" >/dev/null 2>&1 && RC=0 || RC=$?
assert_eq "$RC" "1" "check fails on a missing file"

# --- conversion --------------------------------------------------------------
echo
echo "convert: 720p preset"
"$VIDFIX" "$TMP/bad.mp4" --out "$TMP/out.mp4" --preset 720p >/dev/null 2>&1
assert_file "$TMP/out.mp4" "output file was created"
DIMS="$("$FFMPEG" -hide_banner -i "$TMP/out.mp4" 2>&1 | grep -m1 'Video:' | grep -oE '[0-9]{3,5}x[0-9]{3,5}' | head -1)"
assert_eq "$DIMS" "1280x720" "output is 1280x720"
PIX="$("$FFMPEG" -hide_banner -i "$TMP/out.mp4" 2>&1 | grep -m1 'Video:' | grep -oE 'yuv[a-z0-9]+' | head -1)"
case "$PIX" in
  yuv420p|yuvj420p) ok "output is 4:2:0 (yuv420p)" ;;
  *) bad "output is not 4:2:0: $PIX" ;;
esac
assert_contains "$("$FFMPEG" -hide_banner -i "$TMP/out.mp4" 2>&1 | grep -m1 'Audio:')" "aac" "output audio is AAC"

echo
echo "convert: file without audio stays without audio"
"$VIDFIX" "$TMP/silent.mp4" --out "$TMP/silent_out.mp4" >/dev/null 2>&1
AUDIO_STREAMS="$("$FFMPEG" -hide_banner -i "$TMP/silent_out.mp4" 2>&1 | grep -c 'Audio: ' || true)"
assert_eq "$AUDIO_STREAMS" "0" "no audio stream was invented"

echo
echo "convert: source file is never modified"
assert_eq "$(sha256_of "$TMP/bad.mp4")" "$BEFORE" "source file checksum unchanged"

echo
echo "convert: existing output is skipped"
"$VIDFIX" "$TMP/bad.mp4" --out "$TMP/out.mp4" --preset 720p 2>&1 | grep -q "SKIPPED" \
  && ok "existing output is skipped" || bad "existing output was not skipped"

echo
echo "convert: --force overwrites"
"$VIDFIX" "$TMP/bad.mp4" --out "$TMP/out.mp4" --preset 720p --force >/dev/null 2>&1 \
  && ok "--force overwrites the output" || bad "--force failed"

echo
echo "convert: folder mode"
mkdir -p "$TMP/folder" && cp "$TMP/bad.mp4" "$TMP/folder/one.mp4"
"$VIDFIX" "$TMP/folder" >/dev/null 2>&1
assert_file "$TMP/folder/one_fixed.mp4" "folder mode produced an output"

echo
echo "convert: --out-dir"
mkdir -p "$TMP/od"
"$VIDFIX" "$TMP/bad.mp4" --out-dir "$TMP/od" >/dev/null 2>&1
assert_file "$TMP/od/bad_fixed.mp4" "--out-dir honoured"

echo
echo "convert: --dry-run writes nothing"
"$VIDFIX" "$TMP/bad.mp4" --out "$TMP/dry.mp4" --dry-run >/dev/null 2>&1
assert_no_file "$TMP/dry.mp4" "dry-run did not write a file"

echo
echo "cli: --version and --help"
"$VIDFIX" --version >/dev/null 2>&1 && ok "--version exits 0" || bad "--version failed"
"$VIDFIX" --help >/dev/null 2>&1 && ok "--help exits 0" || bad "--help failed"

# --- installer ---------------------------------------------------------------
echo
echo "installer: verifies sha256 and installs"
PKG="$TMP/pkg"
NAME="vidfix-$VERSION"
mkdir -p "$PKG/$NAME/bin"
cp "$VIDFIX" "$PKG/$NAME/bin/"
cp "$INSTALLER" "$PKG/$NAME/"
tar -czf "$PKG/$NAME.tar.gz" -C "$PKG" "$NAME"
(cd "$PKG" && sha256_of "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
if BASE="file://$PKG" PREFIX="$TMP/prefix" bash "$INSTALLER" >/dev/null 2>&1; then
  ok "installer completed successfully"
else
  bad "installer failed"
fi
assert_file "$TMP/prefix/bin/vidfix" "installer placed the binary"
"$TMP/prefix/bin/vidfix" --version >/dev/null 2>&1 && ok "installed binary runs" || bad "installed binary failed"

echo
echo "installer: rejects a corrupted download"
echo "0000000000000000000000000000000000000000000000000000000000000000  $NAME.tar.gz" \
  > "$PKG/$NAME.tar.gz.sha256"
BASE="file://$PKG" PREFIX="$TMP/prefix2" bash "$INSTALLER" >/dev/null 2>&1 && RC=0 || RC=$?
assert_eq "$RC" "1" "installer exits non-zero on sha256 mismatch"
assert_no_file "$TMP/prefix2/bin/vidfix" "nothing was installed after a failed verification"

echo
echo "---"
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
