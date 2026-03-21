#!/bin/bash
# admin-setup.sh — Admin privileged setup for macOS developer workstations
#
# Run this script ONCE per machine as an admin user (do NOT use sudo).
# Usage: ./admin-setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

is_macos

# Must NOT run as root — Homebrew refuses to run as root
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    error "Do NOT run this script with sudo. Run as a normal admin user."
    error "Usage: ./admin-setup.sh"
    exit 1
fi

# Verify the user has admin privileges (member of the admin group)
if ! groups | grep -qw admin; then
    error "This script requires an admin user account."
    error "Current user '$(whoami)' is not in the admin group."
    exit 1
fi

# Prompt for sudo password upfront and keep it alive
require_sudo

BREW_PREFIX="$(brew_prefix)"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   macOS Developer Workstation — Admin Setup  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"

INSTALLED=()
SKIPPED=()

# ── Step 1: Xcode Command Line Tools ───────────────────────────────────────

section "Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
    warn "Xcode Command Line Tools already installed."
    SKIPPED+=("Xcode CLT")
else
    info "Installing Xcode Command Line Tools..."
    info "A dialog will appear — click 'Install' to proceed."
    xcode-select --install 2>/dev/null || true

    # Poll until installation completes or timeout after 10 minutes
    SECONDS=0
    TIMEOUT=600
    while ! xcode-select -p &>/dev/null; do
        if (( SECONDS >= TIMEOUT )); then
            error "Timed out waiting for Xcode CLT installation."
            error "Please install manually: xcode-select --install"
            exit 1
        fi
        sleep 5
    done
    success "Xcode Command Line Tools installed."
    INSTALLED+=("Xcode CLT")
fi

# ── Step 2: Homebrew ───────────────────────────────────────────────────────

section "Homebrew"

if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
    warn "Homebrew already installed at $BREW_PREFIX."
    SKIPPED+=("Homebrew")
else
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    success "Homebrew installed."
    INSTALLED+=("Homebrew")
fi

# Ensure non-admin users can read and execute Homebrew binaries
info "Setting Homebrew permissions for non-admin users..."
sudo chmod -R a+rX "$BREW_PREFIX"

# Fix zsh compinit insecure directory warnings
# compinit flags directories/files not owned by root or the current user.
# Since Homebrew is owned by the admin who installed it, other users
# will see "insecure directories" warnings. Chown to root fixes this.
info "Fixing zsh completion directory ownership..."
sudo chown -R root:admin "$BREW_PREFIX/share/zsh"
sudo chmod -R go-w "$BREW_PREFIX/share/zsh"
# Also fix symlink targets (completions files in Cellar and completions dirs)
sudo chown root:admin "$BREW_PREFIX/completions/zsh/"* 2>/dev/null || true
find "$BREW_PREFIX/Cellar" -path "*/share/zsh/site-functions/*" -exec sudo chown root:admin {} \; 2>/dev/null || true

# Make brew available in this session
eval "$("$BREW_PREFIX/bin/brew" shellenv)"

# ── Step 3: Docker Desktop ────────────────────────────────────────────────

section "Docker Desktop"

if [[ -d "/Applications/Docker.app" ]]; then
    warn "Docker Desktop already installed."
    SKIPPED+=("Docker Desktop")
else
    info "Downloading Docker Desktop..."

    if is_arm64; then
        DOCKER_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    else
        DOCKER_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
    fi

    DOCKER_DMG="/tmp/Docker.dmg"
    curl -fSL -o "$DOCKER_DMG" "$DOCKER_URL"

    info "Installing Docker Desktop..."
    hdiutil attach "$DOCKER_DMG" -quiet -mountpoint /Volumes/Docker
    sudo cp -R "/Volumes/Docker/Docker.app" /Applications/
    hdiutil detach /Volumes/Docker -quiet
    rm -f "$DOCKER_DMG"

    success "Docker Desktop installed."
    info "NOTE: Each user must open Docker Desktop from Applications at least once."
    INSTALLED+=("Docker Desktop")
fi

# ── Step 4: Google Chrome ─────────────────────────────────────────────────

section "Google Chrome"

if [[ -d "/Applications/Google Chrome.app" ]]; then
    warn "Google Chrome already installed."
    SKIPPED+=("Google Chrome")
else
    info "Downloading Google Chrome..."

    CHROME_DMG="/tmp/GoogleChrome.dmg"
    curl -fSL -o "$CHROME_DMG" "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"

    info "Installing Google Chrome..."
    hdiutil attach "$CHROME_DMG" -quiet -mountpoint /Volumes/GoogleChrome
    sudo cp -R "/Volumes/GoogleChrome/Google Chrome.app" /Applications/
    hdiutil detach /Volumes/GoogleChrome -quiet
    rm -f "$CHROME_DMG"

    success "Google Chrome installed."
    INSTALLED+=("Google Chrome")
fi

# ── Step 5: WebStorm ──────────────────────────────────────────────────────

section "WebStorm"

if [[ -d "/Applications/WebStorm.app" ]]; then
    warn "WebStorm already installed."
    SKIPPED+=("WebStorm")
else
    info "Downloading WebStorm..."

    # Fetch the latest download URL from JetBrains API
    if is_arm64; then
        WEBSTORM_URL=$(curl -fsSL "https://data.services.jetbrains.com/products/releases?code=WS&latest=true&type=release" \
            | grep -o '"mac_arm64":{[^}]*}' \
            | grep -o '"link":"[^"]*"' \
            | head -1 \
            | cut -d'"' -f4)
    else
        WEBSTORM_URL=$(curl -fsSL "https://data.services.jetbrains.com/products/releases?code=WS&latest=true&type=release" \
            | grep -o '"mac":{[^}]*}' \
            | grep -o '"link":"[^"]*"' \
            | head -1 \
            | cut -d'"' -f4)
    fi

    if [[ -z "$WEBSTORM_URL" ]]; then
        error "Could not determine WebStorm download URL."
        error "Please download manually from https://www.jetbrains.com/webstorm/download/"
    else
        WEBSTORM_DMG="/tmp/WebStorm.dmg"
        curl -fSL -o "$WEBSTORM_DMG" "$WEBSTORM_URL"

        info "Installing WebStorm..."
        hdiutil attach "$WEBSTORM_DMG" -quiet -mountpoint /Volumes/WebStorm

        # The app name in the DMG may include a version number
        WEBSTORM_APP=$(find /Volumes/WebStorm -maxdepth 1 -name "WebStorm*.app" -print -quit)
        if [[ -n "$WEBSTORM_APP" ]]; then
            sudo cp -R "$WEBSTORM_APP" "/Applications/WebStorm.app"
            success "WebStorm installed."
            INSTALLED+=("WebStorm")
        else
            error "Could not find WebStorm.app in the mounted DMG."
        fi

        hdiutil detach /Volumes/WebStorm -quiet
        rm -f "$WEBSTORM_DMG"
    fi
fi

# ── Step 6: Node.js (system-level via Homebrew) ───────────────────────────

section "Node.js (system-level for Claude Code)"

if brew list node &>/dev/null; then
    warn "Node.js already installed via Homebrew."
    SKIPPED+=("Node.js (system)")
else
    info "Installing Node.js via Homebrew..."
    brew install node
    success "Node.js installed."
    INSTALLED+=("Node.js (system)")
fi

# ── Step 7: Supabase CLI ─────────────────────────────────────────────────

section "Supabase CLI"

if command_exists supabase; then
    warn "Supabase CLI already installed."
    SKIPPED+=("Supabase CLI")
else
    info "Installing Supabase CLI..."
    brew install supabase/tap/supabase
    success "Supabase CLI installed."
    INSTALLED+=("Supabase CLI")
fi

# ── Step 8: Claude Code ──────────────────────────────────────────────────

section "Claude Code"

if command_exists claude; then
    warn "Claude Code already installed."
    SKIPPED+=("Claude Code")
else
    info "Installing Claude Code via npm..."
    npm install -g @anthropic-ai/claude-code

    info "Installing Claude Code native build..."
    claude install
    success "Claude Code installed."
    INSTALLED+=("Claude Code")
fi

# ── Summary ──────────────────────────────────────────────────────────────

section "Admin Setup Complete"

if [[ ${#INSTALLED[@]} -gt 0 ]]; then
    echo -e "${GREEN}Installed:${NC}"
    for item in "${INSTALLED[@]}"; do
        echo -e "  ${GREEN}✓${NC} $item"
    done
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Already installed (skipped):${NC}"
    for item in "${SKIPPED[@]}"; do
        echo -e "  ${YELLOW}–${NC} $item"
    done
fi

echo ""
info "Next step: Have each user run ./user-setup.sh from their own account."
info "Do NOT use sudo for the user script."
echo ""
