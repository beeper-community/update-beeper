#!/bin/bash
# install.sh - Install update-beeper scripts
#
# Quick installation (pipes directly to bash):
#   curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/install.sh | bash
#
# Safer two-step installation (recommended - allows script review):
#   curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/install.sh -o /tmp/install.sh
#   less /tmp/install.sh  # Review the script before running
#   bash /tmp/install.sh
#
# Or clone and run (safest - full source inspection):
#   git clone https://github.com/beeper-community/update-beeper.git
#   cd update-beeper
#   ./install.sh
#
# Verify checksums (optional but recommended for remote installs):
#   curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/checksums.sha256 -o /tmp/checksums.sha256
#   cd ~/.local/bin && sha256sum -c /tmp/checksums.sha256 --ignore-missing

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Error handler
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

REPO="https://raw.githubusercontent.com/beeper-community/update-beeper/master"
INSTALL_DIR="${HOME}/.local/bin"

echo -e "${BLUE}🐝 Installing update-beeper...${NC}"
echo ""

# Check dependencies
command -v curl &>/dev/null || error_exit "curl is required but not installed"

# Create install directory if needed
mkdir -p "$INSTALL_DIR" || error_exit "Failed to create $INSTALL_DIR"

# Check if we're running from a cloned repo or via curl
if [[ -f "update-beeper" ]] && [[ -f "beeper-version" ]]; then
    # Local install from cloned repo
    echo "   Installing from local files..."
    cp update-beeper "$INSTALL_DIR/" || error_exit "Failed to copy update-beeper"
    cp beeper-version "$INSTALL_DIR/" || error_exit "Failed to copy beeper-version"
else
    # Remote install via curl
    echo "   Downloading update-beeper..."
    curl -fsSL "$REPO/update-beeper" -o "$INSTALL_DIR/update-beeper" || error_exit "Failed to download update-beeper"

    echo "   Downloading beeper-version..."
    curl -fsSL "$REPO/beeper-version" -o "$INSTALL_DIR/beeper-version" || error_exit "Failed to download beeper-version"
fi

# Make executable
chmod +x "$INSTALL_DIR/update-beeper" || error_exit "Failed to make update-beeper executable"
chmod +x "$INSTALL_DIR/beeper-version" || error_exit "Failed to make beeper-version executable"

echo ""
echo -e "${GREEN}✓ Installed successfully!${NC}"
echo ""
echo "   Scripts installed to: $INSTALL_DIR"
echo ""

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${YELLOW}⚠ $INSTALL_DIR is not in your PATH${NC}"
    echo ""
    echo "   Add this to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
else
    echo "   Commands available:"
    echo "     update-beeper    - Update Beeper to latest version"
    echo "     beeper-version   - Check version status"
fi

echo ""
echo -e "${BLUE}Optional: Set up automatic updates${NC}"
echo ""
echo "   # Copy systemd user files"
echo "   mkdir -p ~/.config/systemd/user"
echo "   curl -fsSL $REPO/systemd/update-beeper-user.service -o ~/.config/systemd/user/update-beeper.service"
echo "   curl -fsSL $REPO/systemd/update-beeper-user.timer -o ~/.config/systemd/user/update-beeper.timer"
echo ""
echo "   # Enable the timer"
echo "   systemctl --user daemon-reload"
echo "   systemctl --user enable --now update-beeper.timer"
echo ""
