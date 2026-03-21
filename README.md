# ClaudeNewMacSetup

Two-phase macOS setup for full-stack Node.js development (React + Vite). Designed for environments where developers do **not** have admin privileges — an admin runs a privileged script once per machine, then each user runs a separate script to configure their own environment.

## What Gets Installed

### Admin Script (`admin-setup.sh`)

These require admin/sudo privileges and are installed system-wide:

| Tool | Purpose |
|------|---------|
| Xcode Command Line Tools | macOS compiler toolchain (git, make, clang) |
| Homebrew | Package manager for macOS |
| Docker Desktop | Container runtime for databases and services |
| Google Chrome | Web browser for development and testing |
| WebStorm | JetBrains IDE for full-stack JavaScript/TypeScript |
| Node.js (system-level) | Provides npm for the global Claude Code install |
| Claude Code | AI-powered coding assistant (CLI) |

### User Script (`user-setup.sh`)

These are installed per-user with no admin privileges required:

| Tool | Purpose |
|------|---------|
| Homebrew PATH | Adds system Homebrew to the user's shell |
| oh-my-zsh | Zsh framework with git plugin enabled |
| nvm | Node Version Manager — install and switch Node versions |
| Node.js LTS | Latest LTS release via nvm (used for development) |
| Git config | Interactive prompts for user.name and user.email |
| Caffeine | Prevents Mac from sleeping — auto-starts at login, stays on indefinitely |
| Default browser | Sets Google Chrome as the default browser |
| Dock configuration | Sets Dock to Finder, Chrome, WebStorm, and Terminal only |

## Prerequisites

- macOS 13 (Ventura) or later, Apple Silicon or Intel
- One admin account with sudo access
- Target user accounts already created on the Mac

## Usage

### Step 1: Admin Setup (once per machine)

Log in as an admin user and install the Xcode Command Line Tools first (provides `git`, compilers, and other essentials):

```bash
xcode-select --install
```

A macOS dialog will appear — click "Install" and wait for it to complete. Then clone the repo and run the admin script:

```bash
git clone https://github.com/rbdone/ClaudeNewMacSetup.git
cd ClaudeNewMacSetup
chmod +x admin-setup.sh user-setup.sh
./admin-setup.sh
```

**Do NOT use `sudo`** — run the script as a normal admin user. It will prompt for your password when needed. The script installs Homebrew, Docker Desktop, Google Chrome, WebStorm, Node.js, and Claude Code. It will skip Xcode CLT if already installed.

**Running as admin from a non-admin account:** If you're logged in as a non-admin user but know the admin credentials, use `su` to switch to the admin account first. Use the admin's **short username** (no spaces) rather than their full name — find it with `dscl . -list /Users`:

```bash
su - adminusername -c "/path/to/ClaudeNewMacSetup/admin-setup.sh"
```

### Step 2: User Setup (once per user)

Log in as the developer's account and run:

```bash
cd /path/to/ClaudeNewMacSetup
./user-setup.sh
```

**Do NOT use sudo.** This script sets up oh-my-zsh, nvm with Node.js LTS, Git configuration, and configures the Dock — all within the user's home directory.

After the script completes, open a **new terminal** or run `source ~/.zshrc`.

### Step 3: Start Developing

Each user is now ready to scaffold and develop full-stack Node.js applications:

```bash
# Create a new React + Vite project
npm create vite@latest my-app -- --template react-ts
cd my-app
npm install
npm run dev
```

Docker is available for databases and services:

```bash
# Open Docker Desktop from Applications first, then:
docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=dev postgres
```

## Project Structure

```
ClaudeNewMacSetup/
├── README.md            # This file
├── admin-setup.sh       # Admin privileged setup (run once per machine)
├── user-setup.sh        # Per-user setup (run once per developer account)
└── lib/
    └── common.sh        # Shared helper functions (colors, logging, checks)
```

## Idempotency

Both scripts are safe to re-run. They check for existing installations and skip anything already present. Re-running will not overwrite your `.zshrc` or Git configuration.

## Design Notes

- **System Node vs. nvm Node:** A system-level Node.js is installed via Homebrew solely to provide npm for the global Claude Code install. Each user gets their own Node.js via nvm, which they fully control.
- **No global npm packages:** Beyond Claude Code, no npm packages are installed globally. Project dependencies are managed per-project.
- **Databases via Docker:** No databases are installed via Homebrew. Use Docker containers for PostgreSQL, MongoDB, Redis, etc.
- **Homebrew permissions:** The admin script makes Homebrew readable by all users. Non-admin users can use installed binaries but cannot run `brew install` themselves.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `brew: command not found` | Run `eval "$(/opt/homebrew/bin/brew shellenv)"` or open a new terminal |
| `nvm: command not found` | Run `source ~/.zshrc` or open a new terminal |
| `docker: command not found` | Open Docker Desktop from Applications at least once |
| Docker commands fail | Ensure Docker Desktop is running (check menu bar icon) |
| Permission denied errors | Confirm an admin has run `admin-setup.sh` first |
| WebStorm won't open | Right-click > Open (first launch may require macOS Gatekeeper approval) |
| Chrome not set as default browser | Open Chrome > Settings > Default browser, or accept the prompt on first launch |
| Dock shows wrong apps after re-run | The user script resets the Dock each time — this is expected |
| Xcode CLT dialog doesn't appear | Run `xcode-select --install` manually from Terminal |
