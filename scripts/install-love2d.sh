#!/usr/bin/env bash
# Install Love2D on macOS from the official GitHub release.
#
# Why not brew? The Homebrew cask was deprecated (scheduled for disable
# 2026-09-01) because Love2D's binary is not notarized by Apple. This script
# downloads the same bytes directly, strips the Gatekeeper quarantine
# attribute, and installs a CLI wrapper on PATH — so the install keeps working
# after the brew cask is gone.
#
# Usage:
#   scripts/install-love2d.sh           # install or reinstall to match .love-version
#   scripts/install-love2d.sh --check   # verify current install; exit 0 if correct
#
# Idempotent: safe to run repeatedly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/.love-version"
APP_PATH="/Applications/love.app"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/love"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "error: $VERSION_FILE missing. Cannot determine target Love2D version." >&2
  exit 1
fi
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

MODE="install"
if [[ "${1:-}" == "--check" ]]; then
  MODE="check"
fi

OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  echo "error: this script is macOS-only. On Linux/Windows, install Love2D via your platform's package manager or from love2d.org." >&2
  exit 1
fi

# Detect an existing install's version.
installed_version=""
if [[ -x "$APP_PATH/Contents/MacOS/love" ]]; then
  installed_version="$("$APP_PATH/Contents/MacOS/love" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
fi

if [[ "$MODE" == "check" ]]; then
  if [[ "$installed_version" == "$VERSION" ]]; then
    echo "ok: Love2D $VERSION installed at $APP_PATH"
    exit 0
  fi
  echo "mismatch: want $VERSION, have '${installed_version:-none}'"
  exit 1
fi

if [[ "$installed_version" == "$VERSION" && -x "$BIN_PATH" ]]; then
  echo "Love2D $VERSION already installed at $APP_PATH and CLI wrapper at $BIN_PATH."
  echo "(Use --check to verify, or delete the app + wrapper to force reinstall.)"
  exit 0
fi

# Warn about brew-installed cask collision.
if command -v brew >/dev/null 2>&1; then
  if brew list --cask 2>/dev/null | grep -qx 'love'; then
    echo "warning: 'love' cask is currently installed via Homebrew."
    echo "  Recommended: run 'brew uninstall --cask love' first to avoid two copies."
    echo "  Continuing with install from love2d.org; the existing /Applications/love.app will be replaced."
    echo
  fi
fi

URL="https://github.com/love2d/love/releases/download/${VERSION}/love-${VERSION}-macos.zip"
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

echo "Downloading Love2D $VERSION..."
echo "  $URL"
if ! curl -fL --progress-bar -o "$TMPDIR/love.zip" "$URL"; then
  echo "error: download failed. Verify the version '$VERSION' exists at:" >&2
  echo "  https://github.com/love2d/love/releases" >&2
  exit 1
fi

echo "Unzipping..."
unzip -q "$TMPDIR/love.zip" -d "$TMPDIR"

EXTRACTED_APP=""
for candidate in "$TMPDIR/love.app" "$TMPDIR"/*/love.app; do
  if [[ -d "$candidate" ]]; then
    EXTRACTED_APP="$candidate"
    break
  fi
done
if [[ -z "$EXTRACTED_APP" ]]; then
  echo "error: love.app not found in the extracted zip. Zip contents:" >&2
  ls -la "$TMPDIR" >&2
  exit 1
fi

if [[ -d "$APP_PATH" ]]; then
  echo "Replacing existing $APP_PATH..."
  rm -rf "$APP_PATH"
fi
echo "Installing to $APP_PATH..."
mv "$EXTRACTED_APP" "$APP_PATH"

echo "Stripping Gatekeeper quarantine attribute..."
xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true

mkdir -p "$BIN_DIR"
cat > "$BIN_PATH" <<EOF
#!/usr/bin/env bash
exec "$APP_PATH/Contents/MacOS/love" "\$@"
EOF
chmod +x "$BIN_PATH"
echo "CLI wrapper installed at $BIN_PATH"

case ":$PATH:" in
  *":$BIN_DIR:"*)
    echo
    echo "$BIN_DIR is already on PATH. Verify with: love --version"
    ;;
  *)
    echo
    echo "NOTE: $BIN_DIR is not on your PATH."
    echo "Add this line to ~/.zshrc (or equivalent) and restart your shell:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo "Or invoke directly for now: $BIN_PATH --version"
    ;;
esac
