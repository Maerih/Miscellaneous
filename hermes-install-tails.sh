
#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================================
# TAILSPILOT - Persistent Hermes Agent for Tails OS
# ==========================================================

HOME_DIR="/home/amnesia"
PERSIST="$HOME_DIR/Persistent"
UNLOCKED="/live/persistence/TailsData_unlocked"
DOTFILES="$UNLOCKED/dotfiles"

ROOT="$PERSIST/Hermes"
INSTALL_DIR="$ROOT/hermes-agent"
HERMES_HOME="$ROOT/data"
BIN_DIR="$ROOT/bin"
INSTALLER="$ROOT/install-hermes.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
fail() { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

echo
echo "=========================================="
echo "       TAILSPILOT HERMES INSTALLER"
echo "=========================================="
echo

# 1. Check existing Persistent Storage

[[ -d "$PERSIST" && -w "$PERSIST" ]] ||
    fail "Persistent Storage is missing, locked, or not writable."

[[ -d "$UNLOCKED" ]] ||
    fail "Tails Persistent Storage is not unlocked."

TEST="$(mktemp "$PERSIST/.test.XXXXXX")" ||
    fail "Cannot write to Persistent Storage."
rm -f "$TEST"

ok "Existing Persistent Storage is available."

# 2. Check Tails Dotfiles persistence

[[ -d "$DOTFILES" && -w "$DOTFILES" ]] ||
    fail "Enable the Dotfiles feature in Tails Persistent Storage, reboot, unlock storage, and rerun this script."

ok "Tails Dotfiles persistence is available."

# 3. Check prerequisites

for cmd in curl git tar sha256sum; do
    command -v "$cmd" >/dev/null ||
        fail "Missing required command: $cmd"
done

# 4. Prepare persistent directories

mkdir -p "$ROOT" "$INSTALL_DIR" "$HERMES_HOME" "$BIN_DIR"

chmod 700 "$ROOT" "$HERMES_HOME"

export HERMES_HOME
export PATH="$HOME_DIR/.local/bin:$PATH"

# 5. Download official installer

info "Downloading official Hermes installer..."

curl -fL --proto '=https' --tlsv1.2 \
    "https://hermes-agent.nousresearch.com/install.sh" \
    -o "$INSTALLER"

[[ -s "$INSTALLER" ]] ||
    fail "Installer download failed."

# 6. Install Hermes into Persistent Storage

info "Installing Hermes Agent..."

bash "$INSTALLER" \
    --dir "$INSTALL_DIR" \
    --hermes-home "$HERMES_HOME" \
    --non-interactive

# 7. Locate the official Hermes launcher

SOURCE_LAUNCHER="$HOME_DIR/.local/bin/hermes"

[[ -e "$SOURCE_LAUNCHER" ]] ||
    fail "Official Hermes launcher was not created."

# Copy the actual launcher into Persistent Storage.
# This avoids depending on the volatile ~/.local/bin.

cp -L "$SOURCE_LAUNCHER" "$BIN_DIR/hermes"
chmod 700 "$BIN_DIR/hermes"

ok "Persistent Hermes launcher created."

# 8. Create the normal 'hermes' command wrapper

cat > "$BIN_DIR/hermes" <<'WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/amnesia/Persistent/Hermes"

[[ -d "$ROOT/hermes-agent" ]] ||
    { echo "Hermes installation is unavailable."; exit 1; }

[[ -d "$ROOT/data" ]] ||
    { echo "Hermes data directory is unavailable."; exit 1; }

export HERMES_HOME="$ROOT/data"

# Invoke the official installed launcher.
exec "$ROOT/cli/hermes-original" "$@"
WRAPPER

# Preserve the official launcher separately.
mkdir -p "$ROOT/cli"
cp -L "$SOURCE_LAUNCHER" "$ROOT/cli/hermes-original"
chmod 700 "$ROOT/cli/hermes-original"

chmod 700 "$BIN_DIR/hermes"

# 9. Configure persistent shell PATH

BASHRC="$DOTFILES/.bashrc"
touch "$BASHRC"

if ! grep -q "TAILSPILOT_HERMES_PATH" "$BASHRC"; then
    cat >> "$BASHRC" <<'SHELLCONFIG'

# TAILSPILOT_HERMES_PATH
if [ -d "$HOME/Persistent/Hermes/bin" ]; then
    export HERMES_HOME="$HOME/Persistent/Hermes/data"
    export PATH="$HOME/Persistent/Hermes/bin:$PATH"
fi
SHELLCONFIG
fi

ok "Persistent shell PATH configured."

# 10. Configure current terminal immediately

export HERMES_HOME="$HERMES_HOME"
export PATH="$BIN_DIR:$PATH"

# 11. Verify

info "Verifying Hermes command..."

"$BIN_DIR/hermes" --version ||
    fail "Hermes command verification failed."

echo
echo "=========================================="
echo "          INSTALLATION COMPLETE"
echo "=========================================="
echo
ok "Command: hermes"
ok "Install: $INSTALL_DIR"
ok "Data:    $HERMES_HOME"
ok "Binary:  $BIN_DIR/hermes"
ok "PATH:    persistent through Tails Dotfiles"
echo
echo "Try these commands:"
echo
echo "  hermes"
echo "  hermes model"
echo "  hermes tools"
echo "  hermes doctor"
echo
echo "The 'hermes' command will be available"
echo "automatically in new terminals after reboot."
echo
echo "Unlock Persistent Storage at every boot."
echo "=========================================="
