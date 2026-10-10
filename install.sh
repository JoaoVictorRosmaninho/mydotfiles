#!/usr/bin/env bash

set -uo pipefail

# 43PR/dotfiles installer — Void Linux + MangoWC port
#
# Usage:
#   ./install.sh
#   ./install.sh --skip-packages
#
# This script:
#   1. Verifies that the system is Void Linux (xbps + runit)
#   2. Runs a full system upgrade (Void does not support partial upgrades)
#      and installs packages.txt, skipping names it cannot resolve
#   3. Enables the runit services the shell needs (NetworkManager, ...)
#   4. Symlinks this repository's configuration into ~/.config, so the
#      repo is the only copy of each file
#   5. Generates the initial theme

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/.config"
CONFIG_DIR="$HOME/.config"
BACKUP_ROOT="$HOME/.config-backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
PACKAGE_FILE="$REPO_DIR/packages.txt"

SKIP_PACKAGES=0
for arg in "$@"; do
    case "$arg" in
        --skip-packages) SKIP_PACKAGES=1 ;;
        *) printf '\033[1;31m[ERROR]\033[0m Unknown option: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

# Files written by theme.py at runtime. These are copied once (so they
# exist before the first boot), never symlinked.
GENERATED_FILES=(
    "kitty/matugen.conf"
    "mango/colors.conf"
    "alacritty/colors.toml"
    "gtk-3.0/colors.css"
    "gtk-4.0/colors.css"
    "gtk-3.0/settings.ini"
    "gtk-4.0/settings.ini"
    "rofi/colors.rasi"
    "quickshell/Theme.qml"
)

# Not linked: this port keeps the user's login shell (fish).
SKIP_FILES=(
    ".zshrc"
)

# runit services: "name" or "name:replaces" (the replaced one is disabled).
SERVICES=(
    "dbus"
    "polkitd"
    "NetworkManager:dhcpcd"
    "power-profiles-daemon"
)

# --------------------------------------------------
# Colors / output
# --------------------------------------------------

info()    { printf '\n\033[1;34m[INFO]\033[0m %s\n' "$1"; }
success() { printf '\n\033[1;32m[DONE]\033[0m %s\n' "$1"; }
warning() { printf '\n\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error()   { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; }

# --------------------------------------------------
# Checks
# --------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

# shellcheck disable=SC1091
[[ -f /etc/os-release ]] && source /etc/os-release

if [[ "${ID:-}" != "void" ]] || ! command -v xbps-install >/dev/null 2>&1; then
    error "This installer is intended for Void Linux (xbps)."
    error "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is required."
    exit 1
fi

if [[ ! -d "$SRC" ]]; then
    error "No .config directory found at $SRC"
    exit 1
fi

info "Detected distribution: ${PRETTY_NAME:-Void Linux}"

# --------------------------------------------------
# Packages
# --------------------------------------------------

UNKNOWN_PACKAGES=()

if [[ "$SKIP_PACKAGES" -eq 1 ]]; then
    info "Skipping package installation (--skip-packages)."
elif [[ ! -f "$PACKAGE_FILE" ]]; then
    warning "packages.txt not found; skipping packages."
else
    mapfile -t PACKAGES < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$PACKAGE_FILE" | grep -v '^[[:space:]]*$')

    info "Upgrading the system first (xbps-install -Su)..."
    sudo xbps-install -Su xbps || warning "Could not update xbps itself."
    if ! sudo xbps-install -Su; then
        error "System upgrade failed. Fix it and re-run, or use --skip-packages."
        exit 1
    fi

    FOUND_PACKAGES=()
    for pkg in "${PACKAGES[@]}"; do
        if xbps-query -R "$pkg" >/dev/null 2>&1; then
            FOUND_PACKAGES+=("$pkg")
        else
            UNKNOWN_PACKAGES+=("$pkg")
        fi
    done

    if [[ "${#FOUND_PACKAGES[@]}" -gt 0 ]]; then
        info "Installing packages..."
        if sudo xbps-install -S "${FOUND_PACKAGES[@]}"; then
            success "Packages installed."
        else
            warning "xbps reported an error installing one or more packages. Continuing anyway."
        fi
    fi

    if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
        warning "Not found in the repos: ${UNKNOWN_PACKAGES[*]}"
        warning "Check the name with 'xbps-query -Rs <name>', then fix packages.txt."
    fi
fi

# --------------------------------------------------
# runit services
# --------------------------------------------------

info "Enabling runit services..."

for entry in "${SERVICES[@]}"; do
    svc="${entry%%:*}"
    replaces=""
    [[ "$entry" == *:* ]] && replaces="${entry#*:}"

    if [[ ! -d "/etc/sv/$svc" ]]; then
        warning "Service $svc is not installed; skipping."
        continue
    fi
    if [[ -e "/var/service/$svc" ]]; then
        info "Service $svc already enabled."
        continue
    fi
    # Enable the new service first so a failure never leaves e.g. no network.
    if ! sudo ln -s "/etc/sv/$svc" /var/service/; then
        warning "Failed to enable $svc."
        continue
    fi
    success "Service $svc enabled."
    if [[ -n "$replaces" && -e "/var/service/$replaces" ]]; then
        info "Disabling $replaces (replaced by $svc)..."
        sudo rm -f "/var/service/$replaces"
    fi
done

# --------------------------------------------------
# Login session with a single D-Bus session bus
# --------------------------------------------------
#
# Greeters start `mango` without a session bus, so every autostarted app
# autolaunches a private one (tray icons, notifications and the keyring then
# never see each other). "Mango (D-Bus)" runs `dbus-run-session mango`.
# Separate file name, so mangowc package updates never overwrite it.

SESSION_SRC="$REPO_DIR/system/wayland-sessions/mango-dbus.desktop"
SESSION_DST="/usr/share/wayland-sessions/mango-dbus.desktop"
if [[ -f "$SESSION_SRC" ]] && ! cmp -s "$SESSION_SRC" "$SESSION_DST" 2>/dev/null; then
    info "Installing the 'Mango (D-Bus)' login session..."
    if sudo install -Dm644 "$SESSION_SRC" "$SESSION_DST"; then
        success "Session installed: pick 'Mango (D-Bus)' in the greeter."
    else
        warning "Failed to install $SESSION_DST"
    fi
fi

# --------------------------------------------------
# Link dotfiles (symlinked — the repo is the only copy)
# --------------------------------------------------

info "Linking dotfiles..."

mkdir -p "$CONFIG_DIR"

in_list() {
    local needle="$1" g
    shift
    for g in "$@"; do
        [[ "$needle" == "$g" ]] && return 0
    done
    return 1
}

LINK_FAILED=0
LINKED_COUNT=0
BACKED_UP_COUNT=0

while IFS= read -r -d '' src; do
    rel="${src#"$SRC"/}"

    in_list "$rel" "${GENERATED_FILES[@]}" && continue
    in_list "$rel" "${SKIP_FILES[@]}" && continue

    dest="$CONFIG_DIR/$rel"
    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        # Already a symlink (e.g. re-running install.sh) — repoint it in
        # case the repo was moved or cloned to a new path.
        ln -sfn "$src" "$dest"
    elif [[ -e "$dest" ]]; then
        # A real file is in the way: back it up, then replace with a link.
        mkdir -p "$BACKUP_DIR/config/$(dirname "$rel")"
        mv "$dest" "$BACKUP_DIR/config/$rel"
        BACKED_UP_COUNT=$((BACKED_UP_COUNT + 1))
        ln -s "$src" "$dest"
    else
        ln -s "$src" "$dest"
    fi

    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        LINKED_COUNT=$((LINKED_COUNT + 1))
    else
        LINK_FAILED=1
        error "Failed to link $rel"
    fi
done < <(find "$SRC" \( -type f -o -type l \) -not -path '*/.git/*' -print0)

# Generated files: copy once so configs that `source`/`import`/`@import`
# them don't fail to parse before the first `theme apply` runs.
for g in "${GENERATED_FILES[@]}"; do
    [[ -f "$SRC/$g" ]] || continue
    dest="$CONFIG_DIR/$g"
    if [[ ! -e "$dest" || -L "$dest" ]]; then
        [[ -L "$dest" ]] && rm -f "$dest"
        mkdir -p "$(dirname "$dest")"
        cp "$SRC/$g" "$dest"
    fi
done

if [[ "$LINK_FAILED" -eq 1 ]]; then
    error "One or more files failed to link. See errors above."
else
    success "Dotfiles linked ($LINKED_COUNT file(s))."
fi

if [[ "$BACKED_UP_COUNT" -gt 0 ]]; then
    info "Replaced $BACKED_UP_COUNT existing file(s) with symlinks; originals saved to:"
    printf '  %s\n' "$BACKUP_DIR"
fi

# Alacritty: pull in the generated colors without owning the whole config.
ALACRITTY_CFG="$CONFIG_DIR/alacritty/alacritty.toml"
if [[ -f "$ALACRITTY_CFG" ]] && ! grep -q 'alacritty/colors.toml' "$ALACRITTY_CFG"; then
    info "Adding generated colors import to alacritty.toml..."
    mkdir -p "$BACKUP_DIR/config/alacritty"
    cp "$ALACRITTY_CFG" "$BACKUP_DIR/config/alacritty/alacritty.toml"
    if grep -q '^\[general\]' "$ALACRITTY_CFG"; then
        warning "alacritty.toml already has a [general] section; add this line to it manually:"
        printf '  import = ["~/.config/alacritty/colors.toml"]\n'
    else
        { printf '[general]\nimport = ["~/.config/alacritty/colors.toml"]\nlive_config_reload = true\n\n'
          cat "$ALACRITTY_CFG"; } > "$ALACRITTY_CFG.new" && mv "$ALACRITTY_CFG.new" "$ALACRITTY_CFG"
    fi
fi

# --------------------------------------------------
# User directories / permissions
# --------------------------------------------------

mkdir -p "$HOME/Pictures/Wallpapers" "$CONFIG_DIR/quickshell/state"
success "Pictures/Wallpapers created."

# Symlinks' own permission bits are irrelevant; chmod the repo's real files.
find "$SRC" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;
success "Script permissions configured."

# --------------------------------------------------
# Initial theme (generates the files the configs include)
# --------------------------------------------------

if command -v python3 >/dev/null 2>&1; then
    info "Generating initial theme..."
    python3 "$CONFIG_DIR/43pr/bin/theme.py" apply \
        || warning "Initial theme generation failed."
else
    warning "python3 not found; skipping initial theme generation."
fi

# --------------------------------------------------
# Finish
# --------------------------------------------------

printf '\n'
printf '\033[1;32m========================================\033[0m\n'
printf '\033[1;32m     43PR MangoWC Setup Ready (Void)    \033[0m\n'
printf '\033[1;32m========================================\033[0m\n'
printf '\n'
printf 'Configuration: %s (symlinked to %s)\n' "$CONFIG_DIR" "$SRC"
[[ "$BACKED_UP_COUNT" -gt 0 ]] && printf 'Backup:        %s\n' "$BACKUP_DIR"

if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
    warning "Unresolved packages (install manually): ${UNKNOWN_PACKAGES[*]}"
fi

warning "Log out and back in choosing the 'Mango (D-Bus)' session for the changes to fully take effect."
success "Installation complete!"
