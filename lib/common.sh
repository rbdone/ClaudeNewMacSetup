#!/bin/bash
# common.sh — Shared helper functions for setup scripts

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Logging ─────────────────────────────────────────────────────────────────

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[SKIP]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

section() {
    echo ""
    echo -e "${BOLD}━━━ $* ━━━${NC}"
    echo ""
}

# ── Checks ──────────────────────────────────────────────────────────────────

command_exists() {
    command -v "$1" &>/dev/null
}

is_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        error "This script only runs on macOS."
        exit 1
    fi
}

is_arm64() {
    [[ "$(uname -m)" == "arm64" ]]
}

brew_prefix() {
    if is_arm64; then
        echo "/opt/homebrew"
    else
        echo "/usr/local"
    fi
}

require_sudo() {
    if ! sudo -n true 2>/dev/null; then
        info "This script requires admin privileges. You may be prompted for your password."
        sudo -v
    fi
    # Keep sudo alive for the duration of the script
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

ensure_no_sudo() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        error "Do NOT run this script with sudo. It is designed for non-admin users."
        error "Usage: ./user-setup.sh"
        exit 1
    fi
}
