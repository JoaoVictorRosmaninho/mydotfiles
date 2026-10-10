#!/usr/bin/env bash

set -uo pipefail

# Dotfiles installer — Void Linux (glibc, runit) + MangoWC + Quickshell
#
# Usage:
#   ./install.sh              full machine: repos, system, shell and personal apps
#   ./install.sh --minimal    desktop shell only (packages.txt), no personal apps
#   ./install.sh --skip-packages   only system files, services, user and links
#   ./install.sh --vur        also enable the VUR repo (system/xbps.d/vur.conf)
#
# Idempotent: every step checks the current state first, so re-running it
# (e.g. after moving the repo) only does what is missing.
#
#   1. Checks (Void, sudo, not root)
#   2. xbps repositories (mirror, nonfree, multilib, optional VUR)
#   3. Full system upgrade, then packages.txt (+ packages-apps.txt)
#   4. System files (greetd, "Mango (D-Bus)" session) — previous versions backed up
#   5. runit services
#   6. User: groups, login shell (fish)
#   7. Symlinks ~/dotfiles/.config/* -> ~/.config/* (originals backed up)
#   8. fish plugins (fisher), initial theme
#
# Afterwards run ./check.sh to verify the result.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/.config"
SYS="$REPO_DIR/system"
CONFIG_DIR="$HOME/.config"
BACKUP_ROOT="$HOME/.config-backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

SKIP_PACKAGES=0
MINIMAL=0
ENABLE_VUR=0
for arg in "$@"; do
    case "$arg" in
        --skip-packages) SKIP_PACKAGES=1 ;;
        --minimal)       MINIMAL=1 ;;
        --vur)           ENABLE_VUR=1 ;;
        -h|--help)       sed -n '5,25p' "$0"; exit 0 ;;
        *) printf '\033[1;31m[ERROR]\033[0m Unknown option: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

PACKAGE_FILES=("$REPO_DIR/packages.txt")
[[ "$MINIMAL" -eq 0 ]] && PACKAGE_FILES+=("$REPO_DIR/packages-apps.txt")

# Copied once (so they exist before the first run), never symlinked: they are
# rewritten at runtime — by theme.py, by the opacity script, or by fish itself
# (fish replaces fish_variables atomically, which would break a symlink).
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
    "fish/fish_variables"
)

# Not linked: this setup keeps fish as the login shell.
SKIP_FILES=(
    ".zshrc"
)

# runit services: "name" or "name:replaces" (the replaced one is disabled
# only after the new one is enabled). Services that are not installed are skipped.
SERVICES_SHELL=(
    "dbus"
    "elogind"
    "polkitd"
    "NetworkManager:dhcpcd"
    "power-profiles-daemon"
    "greetd"
)
SERVICES_APPS=(
    "socklog-unix"
    "nanoklogd"
    "cronie"
    "cupsd"
    "docker"
    "sshd"
    "syncthing"
    "tailscaled"
    "grub-btrfs"
)

# Supplementary groups for the user (only groups that exist are added).
USER_GROUPS=(wheel audio video storage input power socklog docker lpadmin)

LOGIN_SHELL="/usr/bin/fish"

# --------------------------------------------------
# Output helpers
# --------------------------------------------------

info()    { printf '\n\033[1;34m[INFO]\033[0m %s\n' "$1"; }
success() { printf '\n\033[1;32m[DONE]\033[0m %s\n' "$1"; }
warning() { printf '\n\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error()   { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; }
section() { printf '\n\033[1;35m==> %s\033[0m\n' "$1"; }

WARNINGS=()
remember() { WARNINGS+=("$1"); warning "$1"; }

# Installs a system file with sudo when it differs; the old one is kept as
# <file>.bak-<timestamp>.
install_system_file() {
    local src="$1" dst="$2" mode="${3:-644}"
    [[ -f "$src" ]] || return 0
    if cmp -s "$src" "$dst" 2>/dev/null; then
        info "Up to date: $dst"
        return 0
    fi
    [[ -e "$dst" ]] && sudo cp -a "$dst" "$dst.bak-$TIMESTAMP"
    if sudo install -Dm"$mode" "$src" "$dst"; then
        success "Installed $dst"
    else
        remember "Failed to install $dst"
    fi
}

read_packages() {
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$@" | grep -v '^[[:space:]]*$' | sort -u
}

# --------------------------------------------------
# 1. Checks
# --------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

# shellcheck disable=SC1091
[[ -f /etc/os-release ]] && source /etc/os-release
if [[ "${ID:-}" != "void" ]] || ! command -v xbps-install >/dev/null 2>&1; then
    error "This installer is intended for Void Linux (xbps). Detected: ${PRETTY_NAME:-unknown}"
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

info "Void Linux detected. Repo: $REPO_DIR"
[[ "$MINIMAL" -eq 1 ]] && info "Minimal mode: desktop shell only."

# --------------------------------------------------
# 2-3. Repositories and packages
# --------------------------------------------------

UNKNOWN_PACKAGES=()

if [[ "$SKIP_PACKAGES" -eq 1 ]]; then
    section "Packages (skipped: --skip-packages)"
else
    section "xbps repositories"
    install_system_file "$SYS/xbps.d/00-repository-main.conf" /etc/xbps.d/00-repository-main.conf
    if [[ "$ENABLE_VUR" -eq 1 ]]; then
        install_system_file "$SYS/xbps.d/vur.conf" /etc/xbps.d/vur.conf
    fi
    if [[ "$MINIMAL" -eq 0 ]]; then
        # nonfree (steam, ...) and multilib (32-bit libs) are packages that drop
        # their own repo files into /usr/share/xbps.d.
        sudo xbps-install -Sy void-repo-nonfree void-repo-multilib \
            || remember "Could not enable the nonfree/multilib repositories."
    fi

    section "System upgrade"
    # Void does not support partial upgrades: without a full -Su first, Qt
    # packages (quickshell) fail with "unresolvable shlib libQt_6_PRIVATE_API".
    sudo xbps-install -Syu xbps || remember "Could not update xbps itself."
    if ! sudo xbps-install -Syu; then
        error "System upgrade failed. Fix it and re-run, or use --skip-packages."
        exit 1
    fi

    section "Packages"
    mapfile -t PACKAGES < <(read_packages "${PACKAGE_FILES[@]}")
    MISSING=()
    for pkg in "${PACKAGES[@]}"; do
        xbps-query "$pkg" >/dev/null 2>&1 && continue
        if xbps-query -R "$pkg" >/dev/null 2>&1; then
            MISSING+=("$pkg")
        else
            UNKNOWN_PACKAGES+=("$pkg")
        fi
    done

    if [[ "${#MISSING[@]}" -eq 0 ]]; then
        success "All ${#PACKAGES[@]} packages already installed."
    else
        info "Installing ${#MISSING[@]} package(s)..."
        sudo xbps-install -Sy "${MISSING[@]}" \
            || remember "xbps reported an error installing packages; re-run to retry."
    fi
    if [[ "${#UNKNOWN_PACKAGES[@]}" -gt 0 ]]; then
        remember "Not found in any configured repo (see the end of packages-apps.txt): ${UNKNOWN_PACKAGES[*]}"
    fi
fi

# --------------------------------------------------
# 4. System files
# --------------------------------------------------

section "System files"

# "Mango (D-Bus)" login session: `dbus-run-session mango`, so the whole session
# shares one session bus (tray, notifications, keyring). Separate file name, so
# mangowc package updates never overwrite it.
install_system_file "$SYS/wayland-sessions/mango-dbus.desktop" /usr/share/wayland-sessions/mango-dbus.desktop

# Hand-made runit services (not shipped by any package), e.g. syncthing running
# as the desktop user. Templates: @USER@ is replaced with the current user.
for svdir in "$SYS"/sv/*/; do
    [[ -d "$svdir" ]] || continue
    name="$(basename "$svdir")"
    while IFS= read -r -d '' f; do
        rel="${f#"$svdir"}"
        tmp="$(mktemp)"
        sed "s/@USER@/$USER/g" "$f" > "$tmp"
        install_system_file "$tmp" "/etc/sv/$name/$rel" 755
        rm -f "$tmp"
    done < <(find "$svdir" -type f -print0)
done

if [[ -d /etc/greetd ]]; then
    install_system_file "$SYS/greetd/config.toml" /etc/greetd/config.toml
else
    info "greetd not installed; skipping its config."
fi

# --------------------------------------------------
# 5. runit services
# --------------------------------------------------

section "runit services"

SERVICES=("${SERVICES_SHELL[@]}")
[[ "$MINIMAL" -eq 0 ]] && SERVICES+=("${SERVICES_APPS[@]}")

for entry in "${SERVICES[@]}"; do
    svc="${entry%%:*}"
    replaces=""
    [[ "$entry" == *:* ]] && replaces="${entry#*:}"

    if [[ ! -d "/etc/sv/$svc" ]]; then
        info "Service $svc is not installed; skipping."
        continue
    fi
    if [[ -e "/var/service/$svc" ]]; then
        info "Service $svc already enabled."
    elif sudo ln -s "/etc/sv/$svc" /var/service/; then
        # Enable the new service first so a failure never leaves e.g. no network.
        success "Service $svc enabled."
    else
        remember "Failed to enable service $svc."
        continue
    fi
    if [[ -n "$replaces" && -e "/var/service/$replaces" ]]; then
        info "Disabling $replaces (replaced by $svc)..."
        sudo rm -f "/var/service/$replaces"
    fi
done

# --------------------------------------------------
# 6. User: groups and login shell
# --------------------------------------------------

section "User"

ADD_GROUPS=()
for g in "${USER_GROUPS[@]}"; do
    getent group "$g" >/dev/null || continue
    id -nG "$USER" | tr ' ' '\n' | grep -qx "$g" || ADD_GROUPS+=("$g")
done
if [[ "${#ADD_GROUPS[@]}" -gt 0 ]]; then
    if sudo usermod -aG "$(IFS=,; echo "${ADD_GROUPS[*]}")" "$USER"; then
        success "Added $USER to: ${ADD_GROUPS[*]} (effective after the next login)."
    else
        remember "Could not add $USER to: ${ADD_GROUPS[*]}"
    fi
else
    info "Groups already set."
fi

if [[ -x "$LOGIN_SHELL" ]]; then
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" == "$LOGIN_SHELL" ]]; then
        info "Login shell already $LOGIN_SHELL."
    elif chsh -s "$LOGIN_SHELL"; then
        success "Login shell changed to $LOGIN_SHELL."
    else
        remember "Could not change the login shell to $LOGIN_SHELL."
    fi
else
    remember "$LOGIN_SHELL not installed; login shell left unchanged."
fi

# --------------------------------------------------
# 7. Link dotfiles (symlinked — the repo is the only copy)
# --------------------------------------------------

section "Dotfiles"

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
        # Already a symlink — repoint it in case the repo was moved.
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

# Generated files: copy once so configs that `source`/`import` them parse
# before the first `theme apply`.
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
    remember "One or more files failed to link. See errors above."
else
    success "Dotfiles linked ($LINKED_COUNT file(s))."
fi
if [[ "$BACKED_UP_COUNT" -gt 0 ]]; then
    info "Replaced $BACKED_UP_COUNT existing file(s) with symlinks; originals saved to $BACKUP_DIR"
fi

mkdir -p "$HOME/Pictures/Wallpapers" "$CONFIG_DIR/quickshell/state"

# Symlinks' own permission bits are irrelevant; chmod the repo's real files.
find "$SRC" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;

# --------------------------------------------------
# 8. fish plugins and theme
# --------------------------------------------------

section "fish plugins and theme"

if command -v fish >/dev/null 2>&1 && [[ -f "$CONFIG_DIR/fish/fish_plugins" ]]; then
    # Plugin files are not versioned (fisher rewrites them); fish_plugins is.
    # Bootstrap fisher when missing (official one-liner), then sync the plugins.
    if fish -c 'type -q fisher' 2>/dev/null; then
        info "fisher already installed."
    else
        info "Installing fisher..."
        fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; and fisher install jorgebucaran/fisher' >/dev/null 2>&1 \
            || remember "Could not install fisher (network?)."
    fi
    fish -c 'type -q fisher; and fisher update' >/dev/null 2>&1 \
        && success "fish plugins synced with fish_plugins." \
        || remember "fisher update failed (network?). Run: fish -c 'fisher update'"
fi

if command -v python3 >/dev/null 2>&1; then
    python3 "$CONFIG_DIR/43pr/bin/theme.py" apply >/dev/null \
        && success "Theme generated." \
        || remember "Initial theme generation failed."
else
    remember "python3 not found; theme not generated."
fi

# --------------------------------------------------
# Finish
# --------------------------------------------------

printf '\n\033[1;32m========================================\033[0m\n'
printf '\033[1;32m   Void + MangoWC + Quickshell ready    \033[0m\n'
printf '\033[1;32m========================================\033[0m\n\n'
printf 'Configuration: %s (symlinked to %s)\n' "$CONFIG_DIR" "$SRC"
[[ "$BACKED_UP_COUNT" -gt 0 ]] && printf 'Backup:        %s\n' "$BACKUP_DIR"

if [[ "${#WARNINGS[@]}" -gt 0 ]]; then
    printf '\n\033[1;33mWarnings:\033[0m\n'
    printf '  - %s\n' "${WARNINGS[@]}"
fi

printf '\nNext steps:\n'
printf "  1. Log out and log in choosing the 'Mango (D-Bus)' session (F3 in tuigreet).\n"
printf '  2. Run ./check.sh inside the session to verify everything.\n'
