#!/bin/bash
# user-setup.sh — Per-user development environment setup
#
# Run this script as a NON-ADMIN user. Do NOT use sudo.
# Usage: ./user-setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

is_macos
ensure_no_sudo

BREW_PREFIX="$(brew_prefix)"
ZSHRC="$HOME/.zshrc"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   macOS Developer Environment — User Setup   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"

INSTALLED=()
SKIPPED=()

# ── Step 1: Homebrew PATH ─────────────────────────────────────────────────

section "Homebrew PATH"

if ! [[ -x "$BREW_PREFIX/bin/brew" ]]; then
    error "Homebrew is not installed at $BREW_PREFIX."
    error "An admin must run admin-setup.sh first."
    exit 1
fi

# Ensure brew is available in this session
eval "$("$BREW_PREFIX/bin/brew" shellenv)"

# Add to .zshrc if not already present
touch "$ZSHRC"
if ! grep -q 'brew shellenv' "$ZSHRC"; then
    info "Adding Homebrew to shell profile..."
    {
        echo ""
        echo "# Homebrew"
        echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
    } >> "$ZSHRC"
    success "Homebrew PATH added to .zshrc."
    INSTALLED+=("Homebrew PATH")
else
    warn "Homebrew PATH already in .zshrc."
    SKIPPED+=("Homebrew PATH")
fi

# ── Step 2: oh-my-zsh ────────────────────────────────────────────────────

section "oh-my-zsh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    warn "oh-my-zsh already installed."
    SKIPPED+=("oh-my-zsh")
else
    info "Installing oh-my-zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "oh-my-zsh installed."
    INSTALLED+=("oh-my-zsh")
fi

# Ensure git plugin is enabled
if [[ -f "$ZSHRC" ]]; then
    if grep -q '^plugins=' "$ZSHRC"; then
        if ! grep -q 'plugins=.*git' "$ZSHRC"; then
            warn "Found plugins= line in .zshrc but 'git' is not listed."
            warn "Please add 'git' to your plugins list in $ZSHRC manually."
        else
            success "git plugin already enabled in oh-my-zsh."
        fi
    else
        info "Adding plugins=(git) to .zshrc..."
        echo 'plugins=(git)' >> "$ZSHRC"
        success "git plugin enabled."
    fi
fi

# ── Step 3: nvm + Node.js LTS ────────────────────────────────────────────

section "nvm + Node.js LTS"

export NVM_DIR="$HOME/.nvm"

if [[ -d "$NVM_DIR" ]]; then
    warn "nvm already installed."
    SKIPPED+=("nvm")
else
    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    success "nvm installed."
    INSTALLED+=("nvm")
fi

# Source nvm for this session
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
fi

info "Installing latest Node.js LTS..."
nvm install --lts
nvm alias default 'lts/*'
success "Node.js LTS installed and set as default."

# ── Step 4: Supabase CLI ──────────────────────────────────────────────────

section "Supabase CLI"

if command_exists supabase; then
    warn "Supabase CLI already installed."
    SKIPPED+=("Supabase CLI")
else
    info "Installing Supabase CLI via npm..."
    npm install -g supabase
    success "Supabase CLI installed."
    INSTALLED+=("Supabase CLI")
fi

# ── Step 5: Claude Code ──────────────────────────────────────────────────

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

# ── Step 6: GitHub CLI (gh) ───────────────────────────────────────────────

section "GitHub CLI (gh)"

if command_exists gh; then
    warn "GitHub CLI already installed."
    SKIPPED+=("GitHub CLI")
else
    info "Installing GitHub CLI..."
    mkdir -p "$HOME/bin"

    if is_arm64; then
        GH_ARCH="macOS_arm64"
    else
        GH_ARCH="macOS_amd64"
    fi

    # Fetch latest version tag from GitHub API
    GH_VERSION=$(curl -fsSL "https://api.github.com/repos/cli/cli/releases/latest" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')

    if [[ -z "$GH_VERSION" ]]; then
        error "Could not determine latest gh version."
    else
        GH_TAR="/tmp/gh.tar.gz"
        curl -fSL -o "$GH_TAR" "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_${GH_ARCH}.tar.gz"

        tar -xzf "$GH_TAR" -C /tmp
        cp "/tmp/gh_${GH_VERSION}_${GH_ARCH}/bin/gh" "$HOME/bin/gh"
        chmod +x "$HOME/bin/gh"
        rm -rf "$GH_TAR" "/tmp/gh_${GH_VERSION}_${GH_ARCH}"

        success "GitHub CLI installed to ~/bin/gh."
        INSTALLED+=("GitHub CLI")
    fi

    # Ensure ~/bin is in PATH
    if ! echo "$PATH" | grep -q "$HOME/bin"; then
        if ! grep -q 'HOME/bin' "$ZSHRC"; then
            {
                echo ""
                echo "# User local binaries"
                echo 'export PATH="$HOME/bin:$PATH"'
            } >> "$ZSHRC"
        fi
        export PATH="$HOME/bin:$PATH"
    fi
fi

# ── Step 7: WebStorm CLI shortcut ─────────────────────────────────────────

section "WebStorm CLI Shortcut"

WSTORM_BIN="$HOME/bin/wstorm"

if [[ -x "$WSTORM_BIN" ]]; then
    warn "wstorm shortcut already exists."
    SKIPPED+=("wstorm shortcut")
elif [[ -d "/Applications/WebStorm.app" ]]; then
    mkdir -p "$HOME/bin"
    cat > "$WSTORM_BIN" << 'SCRIPT'
#!/bin/bash
open -a "WebStorm" "$@"
SCRIPT
    chmod +x "$WSTORM_BIN"

    # Ensure ~/bin is in PATH
    if ! echo "$PATH" | grep -q "$HOME/bin"; then
        if ! grep -q 'HOME/bin' "$ZSHRC"; then
            {
                echo ""
                echo "# User local binaries"
                echo 'export PATH="$HOME/bin:$PATH"'
            } >> "$ZSHRC"
        fi
        export PATH="$HOME/bin:$PATH"
    fi

    success "wstorm shortcut installed. Usage: wstorm [file or directory]"
    INSTALLED+=("wstorm shortcut")
else
    warn "WebStorm not installed. Skipping wstorm shortcut."
fi

# ── Step 8: Git Configuration ────────────────────────────────────────────

section "Git Configuration"

if [[ -t 0 ]]; then
    # Interactive terminal — prompt for git config
    CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
    CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

    if [[ -z "$CURRENT_NAME" ]]; then
        read -rp "Enter your full name for Git: " GIT_NAME
        if [[ -n "$GIT_NAME" ]]; then
            git config --global user.name "$GIT_NAME"
            success "Git user.name set to: $GIT_NAME"
        fi
    else
        success "Git user.name already set: $CURRENT_NAME"
    fi

    if [[ -z "$CURRENT_EMAIL" ]]; then
        read -rp "Enter your email for Git: " GIT_EMAIL
        if [[ -n "$GIT_EMAIL" ]]; then
            git config --global user.email "$GIT_EMAIL"
            success "Git user.email set to: $GIT_EMAIL"
        fi
    else
        success "Git user.email already set: $CURRENT_EMAIL"
    fi
else
    warn "Non-interactive shell detected. Skipping Git config prompts."
    warn "Run 'git config --global user.name \"Your Name\"' and"
    warn "'git config --global user.email \"you@example.com\"' manually."
fi

# ── Step 9: Caffeine ─────────────────────────────────────────────────────

section "Caffeine"

CAFFEINE_APP="$HOME/Applications/Caffeine.app"

if [[ -d "$CAFFEINE_APP" ]]; then
    warn "Caffeine already installed."
    SKIPPED+=("Caffeine")
else
    info "Downloading Caffeine..."
    mkdir -p "$HOME/Applications"
    CAFFEINE_ZIP="/tmp/Caffeine.zip"
    curl -fSL -o "$CAFFEINE_ZIP" "https://www.caffeine-app.net/download/tahoe/"

    info "Installing Caffeine to ~/Applications..."
    unzip -qo "$CAFFEINE_ZIP" -d "$HOME/Applications/"
    rm -f "$CAFFEINE_ZIP"

    # Remove quarantine attribute to prevent Gatekeeper "damaged" warning
    xattr -dr com.apple.quarantine "$CAFFEINE_APP"
    success "Caffeine installed."
    INSTALLED+=("Caffeine")
fi

# Set Caffeine to activate on launch (stay awake indefinitely) and start at login
defaults write com.lightheadsw.Caffeine SuppressLaunchMessage -bool true
defaults write com.lightheadsw.Caffeine ActivateOnLaunch -bool true

# Add Caffeine to login items so it starts automatically
if ! osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -q "Caffeine"; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"'"$CAFFEINE_APP"'", hidden:true}' 2>/dev/null
    success "Caffeine added to login items."
fi

# Launch Caffeine now (it will activate immediately due to ActivateOnLaunch)
info "Launching Caffeine..."
open -a "$CAFFEINE_APP"
success "Caffeine is running — Mac will stay awake indefinitely."

# ── Step 10: Set Chrome as Default Browser ────────────────────────────────

section "Default Browser"

if [[ -d "/Applications/Google Chrome.app" ]]; then
    info "Setting Google Chrome as the default browser..."
    info "A system dialog may appear — click 'Use Chrome' to confirm."
    open -a "Google Chrome" --args --make-default-browser
    success "Chrome launched. Accept the prompt to set it as default."
    INSTALLED+=("Chrome default browser")
else
    warn "Google Chrome not installed. Skipping default browser setup."
fi

# ── Step 11: Configure Dock ───────────────────────────────────────────────

section "Dock Configuration"

info "Setting Dock to show only Finder, Chrome, WebStorm, and Terminal..."

# Remove all existing Dock items (Finder is always present and cannot be removed)
defaults write com.apple.dock persistent-apps -array

# Add Google Chrome
if [[ -d "/Applications/Google Chrome.app" ]]; then
    defaults write com.apple.dock persistent-apps -array-add \
        "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Google Chrome.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
fi

# Add WebStorm
if [[ -d "/Applications/WebStorm.app" ]]; then
    defaults write com.apple.dock persistent-apps -array-add \
        "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/WebStorm.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
fi

# Add Terminal
defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/System/Applications/Utilities/Terminal.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"

# Restart Dock to apply changes
killall Dock

success "Dock configured with Finder, Chrome, WebStorm, and Terminal."
INSTALLED+=("Dock configuration")

# ── Step 12: Verification ────────────────────────────────────────────────

section "Verification"

check_tool() {
    local name="$1"
    local cmd="$2"

    if eval "$cmd" &>/dev/null; then
        local version
        version=$(eval "$cmd" 2>/dev/null | head -1)
        echo -e "  ${GREEN}✓${NC} ${name}: ${version}"
    else
        echo -e "  ${RED}✗${NC} ${name}: not found"
    fi
}

echo -e "${BOLD}Installed tools:${NC}"
check_tool "Node.js" "node --version"
check_tool "npm" "npm --version"
check_tool "nvm" "nvm --version"
check_tool "Git" "git --version"
check_tool "Supabase CLI" "supabase --version"
check_tool "GitHub CLI" "gh --version"
check_tool "Zsh" "zsh --version"

# Docker may not be running
if command_exists docker; then
    if docker info &>/dev/null 2>&1; then
        check_tool "Docker" "docker --version"
    else
        echo -e "  ${YELLOW}!${NC} Docker: installed but Docker Desktop is not running"
        echo -e "    Open Docker Desktop from Applications to start it."
    fi
else
    echo -e "  ${RED}✗${NC} Docker: not found (admin must run admin-setup.sh)"
fi

check_tool "Claude Code" "claude --version"

if [[ -d "/Applications/Google Chrome.app" ]]; then
    echo -e "  ${GREEN}✓${NC} Google Chrome: installed"
else
    echo -e "  ${RED}✗${NC} Google Chrome: not found (admin must run admin-setup.sh)"
fi

if [[ -d "/Applications/WebStorm.app" ]]; then
    echo -e "  ${GREEN}✓${NC} WebStorm: installed"
else
    echo -e "  ${RED}✗${NC} WebStorm: not found (admin must run admin-setup.sh)"
fi

# ── Summary ──────────────────────────────────────────────────────────────

section "User Setup Complete"

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
info "Open a new terminal or run 'source ~/.zshrc' to apply all changes."
echo ""
