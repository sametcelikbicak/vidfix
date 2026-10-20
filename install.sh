#!/usr/bin/env bash
# vidfix installer
#   curl -fsSL https://raw.githubusercontent.com/sametcelikbicak/vidfix/v1.0.0/install.sh | bash
set -euo pipefail

VERSION="1.0.0"
REPO="sametcelikbicak/vidfix"
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
TARGET="$BIN_DIR/vidfix"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) die "unsupported operating system: $(uname -s) (macOS and Linux are supported)" ;;
esac

command -v curl >/dev/null 2>&1 || die "curl not found"
command -v tar  >/dev/null 2>&1 || die "tar not found"

TARBALL="vidfix-$VERSION.tar.gz"
BASE="${BASE:-https://github.com/$REPO/releases/download/v$VERSION}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Installing vidfix $VERSION..."

if curl -fsSL "$BASE/$TARBALL" -o "$TMP/$TARBALL" && \
   curl -fsSL "$BASE/$TARBALL.sha256" -o "$TMP/$TARBALL.sha256"; then
  # verify sha256 before installing anything
  if command -v sha256sum >/dev/null 2>&1; then
    GOT="$(sha256sum "$TMP/$TARBALL" | awk '{print $1}')"
  else
    GOT="$(shasum -a 256 "$TMP/$TARBALL" | awk '{print $1}')"
  fi
  WANT="$(awk '{print $1}' "$TMP/$TARBALL.sha256")"
  [ -n "$WANT" ] || die "could not read the sha256 file"
  [ "$GOT" = "$WANT" ] || die "sha256 mismatch (the download may be corrupted)"
  say "  sha256 verified"

  tar -xzf "$TMP/$TARBALL" -C "$TMP"
  SRC="$TMP/vidfix-$VERSION/bin/vidfix"
  [ -f "$SRC" ] || SRC="$(find "$TMP" -name vidfix -type f -path '*/bin/*' | head -1)"
  [ -f "$SRC" ] || die "vidfix script not found inside the release archive"
else
  # no release available: install straight from source
  say "  release archive not found, installing from source..."
  SRC="$TMP/vidfix"
  curl -fsSL "https://raw.githubusercontent.com/$REPO/v$VERSION/bin/vidfix" -o "$SRC" \
    || die "download failed: $BASE"
fi

mkdir -p "$BIN_DIR"
install -m 0755 "$SRC" "$TARGET" 2>/dev/null || { cp "$SRC" "$TARGET"; chmod 0755 "$TARGET"; }

say "  installed: $TARGET"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say ""
     say "  Add it to PATH (zsh):"
     say "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
     say "  Add it to PATH (bash):"
     say "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
     ;;
esac

say ""
say "Done. Usage:"
say "  vidfix check film.mp4      # why will not it play?"
say "  vidfix film.mp4            # convert"
say "  vidfix ./folder            # convert every video in a folder"
