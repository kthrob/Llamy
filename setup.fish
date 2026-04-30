#!/usr/bin/env fish
# setup.fish — install llamy and its dependencies
#
# Run from the repository root:
#   fish setup.fish

# ── helpers ───────────────────────────────────────────────────────────────────

function info
    echo (set_color cyan)"[setup]"(set_color normal) $argv
end
function ok
    echo (set_color green)"[setup] ✓"(set_color normal) $argv
end
function warn
    echo (set_color yellow)"[setup] !"(set_color normal) $argv
end
function err
    echo (set_color red)"[setup] ✗"(set_color normal) $argv >&2
end
function header
    echo ""
    echo (set_color --bold)"── $argv"(set_color normal)
end
function die
    err $argv
    exit 1
end

# ── 0. sanity: must be run from the repo root ─────────────────────────────────

header "Checking repo"

if not test -f ./llamy.fish
    die "llamy.fish not found in current directory. Run setup.fish from the repo root."
end
ok "llamy.fish found"

# ── 1. Homebrew ───────────────────────────────────────────────────────────────

header "Homebrew"

if not command -q brew
    info "Homebrew not found — installing..."
    /bin/bash -c (curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
    # Add brew to PATH for Apple Silicon if needed
    if test -f /opt/homebrew/bin/brew
        eval (/opt/homebrew/bin/brew shellenv)
    end
    if not command -q brew
        die "Homebrew installation failed. Please install manually: https://brew.sh"
    end
    ok "Homebrew installed"
else
    info "Homebrew found — checking for updates..."
    brew update --quiet
    ok "Homebrew up to date ("(brew --version | head -1)")"
end

# ── 2. Python 3 ───────────────────────────────────────────────────────────────

header "Python 3"

# uv manages its own Python, but open-webui's build steps may need a system python3
if not command -q python3
    info "python3 not found — installing via Homebrew..."
    brew install python
    if not command -q python3
        die "python3 installation failed."
    end
    ok "python3 installed ("(python3 --version)")"
else
    set pyver (python3 --version 2>&1)
    ok "python3 already installed ($pyver)"
    # Upgrade if installed via brew
    if brew list python &>/dev/null
        info "Upgrading python via Homebrew..."
        brew upgrade python --quiet
        ok "python3 up to date"
    end
end

# ── 3. uv ─────────────────────────────────────────────────────────────────────

header "uv"

if not command -q uv
    info "uv not found — installing via Homebrew..."
    brew install uv
    if not command -q uv
        die "uv installation failed."
    end
    ok "uv installed ("(uv --version)")"
else
    set uv_current (uv --version)
    info "uv already installed ($uv_current) — checking for upgrade..."
    brew upgrade uv --quiet 2>/dev/null
    ok "uv up to date ("(uv --version)")"
end

# ── 4. Ollama ─────────────────────────────────────────────────────────────────

header "Ollama"

if not command -q ollama
    info "Ollama not found — installing via Homebrew..."
    brew install ollama
    if not command -q ollama
        die "Ollama installation failed."
    end
    ok "Ollama installed ("(ollama --version 2>&1 | head -1)")"
else
    set ol_current (ollama --version 2>&1 | head -1)
    info "Ollama already installed ($ol_current) — checking for upgrade..."
    brew upgrade ollama --quiet 2>/dev/null
    ok "Ollama up to date ("(ollama --version 2>&1 | head -1)")"
end

# ── 5. OrbStack (optional — skip if already installed outside Homebrew) ───────

header "OrbStack"

if not command -q orb
    if brew list --cask orbstack &>/dev/null
        ok "OrbStack already installed via Homebrew"
    else
        info "OrbStack not detected — installing via Homebrew Cask..."
        brew install --cask orbstack
        if not command -q orb
            warn "OrbStack may need a manual launch to complete setup. Visit https://orbstack.dev if needed."
        else
            ok "OrbStack installed"
        end
    end
else
    ok "OrbStack already installed ("(orb version 2>/dev/null | head -1)")"
    info "Checking for OrbStack upgrade..."
    brew upgrade --cask orbstack --quiet 2>/dev/null
    ok "OrbStack up to date"
end

# ── 6. Install llamy.fish ─────────────────────────────────────────────────────

header "Installing llamy"

if test -n "$__fish_config_dir"
    set FISH_FUNCTIONS "$__fish_config_dir/functions"
else
    set FISH_FUNCTIONS "$HOME/.config/fish/functions"
end
mkdir -p $FISH_FUNCTIONS

set DEST "$FISH_FUNCTIONS/llamy.fish"

cp ./llamy.fish $DEST
or die "Failed to copy llamy.fish to $DEST"

chmod +x $DEST
or die "Failed to chmod $DEST"

ok "llamy.fish installed → $DEST"

if fish -c "type -q llamy"
    ok "llamy command is available in Fish"
else
    die "llamy is not discoverable in Fish after install. Check your fish function path and rerun setup."
end

# ── 7. Warm the uvx cache (optional but makes first offline run faster) ───────

header "Warming uvx / open-webui cache"

info "Pre-fetching open-webui into the uvx cache (this may take a minute)..."
if uvx --python 3.11 --with pip open-webui@latest --help > /dev/null 2>&1
    ok "open-webui cached — offline launches will work immediately"
else
    warn "Cache warm-up failed (network issue?). First run of 'llamy' will require internet."
end

# ── done ──────────────────────────────────────────────────────────────────────

echo ""
echo (set_color --bold)(set_color green)"  All done!"(set_color normal)
echo ""
echo "  Open a new terminal (or run "(set_color cyan)"source ~/.config/fish/config.fish"(set_color normal)") and:"
echo ""
echo "    "(set_color --bold)"llamy --help"(set_color normal)"          see all commands"
echo "    "(set_color --bold)"llamy --set-default"(set_color normal)"   pick your default model"
echo "    "(set_color --bold)"llamy"(set_color normal)"                 launch Ollama + Open WebUI"
echo ""
