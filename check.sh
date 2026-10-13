#!/usr/bin/env bash

# Verifies that this machine matches the dotfiles. Read-only: never changes anything.
# Run it inside the graphical session (some checks need mango / Quickshell running).
#
# Usage: ./check.sh            exit code = number of failed checks
#        ./check.sh --minimal  ignore personal apps/services (packages-apps.txt)

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/.config"
CONFIG_DIR="$HOME/.config"
MINIMAL=0
[[ "${1:-}" == "--minimal" ]] && MINIMAL=1

# Single source of truth: reuse the lists declared in install.sh.
# Only array declarations are extracted (one-line or multi-line); nothing else
# from install.sh is ever evaluated.
LISTS=$(awk '
    /^(GENERATED_FILES|SKIP_FILES|SERVICES_SHELL|SERVICES_APPS|USER_GROUPS)=\(/ {
        print; if ($0 ~ /\)[[:space:]]*$/) next; inside = 1; next
    }
    inside { print; if ($0 ~ /^\)/) inside = 0 }
' "$REPO_DIR/install.sh")
if printf '%s\n' "$LISTS" | grep -vqE '^([A-Z_]+=\(.*|[[:space:]]*"[^"$`]*"|[[:space:]]*#.*|\)|[[:space:]]*)$'; then
    echo "check.sh: unexpected content while reading lists from install.sh" >&2; exit 99
fi
eval "$LISTS"
eval "$(grep -E '^LOGIN_SHELL=' "$REPO_DIR/install.sh")"

# mango -p errors to tolerate (none: the config is clean). Regex, e.g. "foo|bar".
KNOWN_MANGO_ERRORS="^$"

PASS=0; WARN=0; FAIL=0
ok()   { PASS=$((PASS + 1)); printf '  \033[1;32m✔\033[0m %s\n' "$1"; }
warn() { WARN=$((WARN + 1)); printf '  \033[1;33m!\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[1;31m✘\033[0m %s\n' "$1"; }
title() { printf '\n\033[1;35m%s\033[0m\n' "$1"; }

in_list() { local n="$1" g; shift; for g in "$@"; do [[ "$n" == "$g" ]] && return 0; done; return 1; }
# Oldest live process with one of these names (zombies skipped: after a crash
# Quickshell restarts itself as "quickshell" and leaves a defunct "qs" behind).
live_pid() { ps -eo pid=,stat=,comm= | awk -v re="^($1)$" '$2 !~ /Z/ && $3 ~ re {print $1; exit}'; }
bus_of() { tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p'; }

# --------------------------------------------------
title "Session / D-Bus"
# --------------------------------------------------

MANGO_PID=$(pgrep -xo mango || true)
QS_PID=$(live_pid "qs|quickshell")

if [[ -z "$MANGO_PID" ]]; then
    warn "mango is not running — session checks skipped (run inside the session)"
else
    ok "mango running (pid $MANGO_PID)"
    MANGO_BUS=$(bus_of "$MANGO_PID")
    if [[ -n "$MANGO_BUS" ]]; then
        ok "mango has a session bus (started via dbus-run-session)"
    else
        fail "mango has no DBUS_SESSION_BUS_ADDRESS — log in with the 'Mango (D-Bus)' session"
    fi

    # at-spi runs its own private bus with --config-file; ignore it.
    N_BUSES=$(pgrep -u "$USER" -a dbus-daemon | grep -- '--session' | grep -vc -- '--config-file' || true)
    if [[ "$N_BUSES" -eq 1 ]]; then
        ok "exactly 1 session bus"
    else
        fail "$N_BUSES session buses running (expected 1) — apps are split across buses"
    fi

    for p in "qs|quickshell" nm-applet syncthingtray pipewire wireplumber; do
        pid=$(live_pid "$p")
        [[ -z "$pid" ]] && { warn "$p is not running"; continue; }
        if [[ -n "${MANGO_BUS:-}" && "$(bus_of "$pid")" == "$MANGO_BUS" ]]; then
            ok "$p is on the session bus"
        else
            fail "$p is on a different D-Bus than mango"
        fi
    done
fi

if [[ -n "$QS_PID" ]]; then
    ok "Quickshell running (pid $QS_PID)"
    NOTIF=$(dbus-send --session --print-reply --dest=org.freedesktop.Notifications /org/freedesktop/Notifications \
        org.freedesktop.Notifications.GetServerInformation 2>/dev/null | grep -m1 -oE '"[^"]*"' | tr -d '"')
    [[ "$NOTIF" == "quickshell" ]] && ok "notification server is Quickshell" \
        || fail "notification server is '${NOTIF:-none}', expected quickshell"

    TRAY=$(dbus-send --session --print-reply --dest=org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
        org.freedesktop.DBus.Properties.Get string:org.kde.StatusNotifierWatcher string:RegisteredStatusNotifierItems 2>/dev/null \
        | grep -c 'string "' || true)
    [[ "$TRAY" -gt 0 ]] && ok "system tray has $TRAY item(s)" || warn "system tray is empty (no StatusNotifierItem registered)"
else
    [[ -n "$MANGO_PID" ]] && fail "Quickshell (qs) is not running — see ~/.cache/quickshell.log"
fi

# --------------------------------------------------
title "mango config"
# --------------------------------------------------

MANGO_OUT=$(mango -c "$CONFIG_DIR/mango/config.conf" -p 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
NEW_ERRORS=$(printf '%s\n' "$MANGO_OUT" | grep '\[ERROR\]' | grep -vE "$KNOWN_MANGO_ERRORS" || true)
if [[ -z "$NEW_ERRORS" ]]; then
    ok "mango -p: no new errors"
else
    fail "mango -p reports errors:"; printf '      %s\n' "$NEW_ERRORS"
fi

# Every ~/.config path used by binds/autostart must exist.
while read -r path; do
    real="${path/#\~/$HOME}"; real="${real/#\$HOME/$HOME}"
    case "$real" in */quickshell/state/*) continue ;; esac   # created at runtime
    [[ -e "$real" ]] && ok "exists: $path" || fail "missing file used by mango config: $path"
done < <(grep -hoE '(~|\$HOME|/home/[a-z_]+)/\.config/[A-Za-z0-9_./-]+\.(sh|py)' "$SRC"/mango/*.conf "$SRC"/mango/autostart.sh | sort -u)

# Every command spawned by binds/autostart must be installed.
while read -r cmd; do
    real="${cmd/#\~/$HOME}"
    command -v "$real" >/dev/null 2>&1 || [[ -x "$real" ]] && ok "command: $cmd" || fail "command not found: $cmd"
done < <(grep -hE '^(exec-once|exec|bind[a-z]*) *=' "$SRC"/mango/*.conf \
    | sed -nE 's/^exec(-once)? *= *([^ ]+).*/\2/p; s/^bind[a-z]* *=[^,]*,[^,]*, *spawn(_shell)? *, *([^ ,;|&]+).*/\2/p' \
    | grep -vE '^(f=|pgrep)' | sort -u)

# --------------------------------------------------
title "Dotfile links"
# --------------------------------------------------

BAD_LINKS=0
while IFS= read -r -d '' src; do
    rel="${src#"$SRC"/}"
    in_list "$rel" "${SKIP_FILES[@]}" && continue
    dest="$CONFIG_DIR/$rel"
    if in_list "$rel" "${GENERATED_FILES[@]}"; then
        [[ -f "$dest" && ! -L "$dest" ]] || { fail "generated file missing (or a symlink): ~/.config/$rel"; BAD_LINKS=$((BAD_LINKS + 1)); }
        continue
    fi
    if [[ ! -L "$dest" || "$(readlink -f "$dest")" != "$(readlink -f "$src")" ]]; then
        fail "not linked to the repo: ~/.config/$rel"
        BAD_LINKS=$((BAD_LINKS + 1))
    fi
done < <(find "$SRC" \( -type f -o -type l \) -print0)
[[ "$BAD_LINKS" -eq 0 ]] && ok "all repo files are linked into ~/.config"

BROKEN=$(find "$CONFIG_DIR" -maxdepth 4 -xtype l -lname "$REPO_DIR/*" 2>/dev/null)
[[ -z "$BROKEN" ]] && ok "no broken symlinks into the repo" \
    || { fail "broken symlinks (file removed from repo?):"; printf '      %s\n' $BROKEN; }

# --------------------------------------------------
title "System"
# --------------------------------------------------

PKG_FILES=("$REPO_DIR/packages.txt")
[[ "$MINIMAL" -eq 0 ]] && PKG_FILES+=("$REPO_DIR/packages-apps.txt")
MISSING_PKGS=()
while read -r pkg; do
    xbps-query "$pkg" >/dev/null 2>&1 || MISSING_PKGS+=("$pkg")
done < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "${PKG_FILES[@]}" | grep -v '^[[:space:]]*$' | sort -u)
[[ "${#MISSING_PKGS[@]}" -eq 0 ]] && ok "all packages installed" \
    || warn "${#MISSING_PKGS[@]} package(s) not installed: ${MISSING_PKGS[*]}"

SERVICES=("${SERVICES_SHELL[@]}")
[[ "$MINIMAL" -eq 0 ]] && SERVICES+=("${SERVICES_APPS[@]}")
for entry in "${SERVICES[@]}"; do
    svc="${entry%%:*}"; replaces=""; [[ "$entry" == *:* ]] && replaces="${entry#*:}"
    [[ -d "/etc/sv/$svc" ]] || { warn "service $svc not installed"; continue; }
    [[ -e "/var/service/$svc" ]] && ok "service $svc enabled" || fail "service $svc not enabled"
    [[ -n "$replaces" && -e "/var/service/$replaces" ]] && fail "service $replaces still enabled (replaced by $svc)"
done

for f in /usr/share/wayland-sessions/mango-dbus.desktop:system/wayland-sessions/mango-dbus.desktop \
         /etc/greetd/config.toml:system/greetd/config.toml; do
    dst="${f%%:*}"; src="$REPO_DIR/${f#*:}"
    cmp -s "$src" "$dst" && ok "$dst matches the repo" || fail "$dst differs from the repo (run ./install.sh --skip-packages)"
done

for svdir in "$REPO_DIR"/system/sv/*/; do
    [[ -d "$svdir" ]] || continue
    name="$(basename "$svdir")"
    while IFS= read -r -d '' f; do
        rel="${f#"$svdir"}"
        sed "s/@USER@/$USER/g" "$f" | cmp -s - "/etc/sv/$name/$rel" \
            && ok "/etc/sv/$name/$rel matches the repo" \
            || fail "/etc/sv/$name/$rel differs from the repo (run ./install.sh --skip-packages)"
    done < <(find "$svdir" -type f -print0)
done

MISSING_GROUPS=()
for g in "${USER_GROUPS[@]}"; do
    getent group "$g" >/dev/null || continue
    id -nG "$USER" | tr ' ' '\n' | grep -qx "$g" || MISSING_GROUPS+=("$g")
done
[[ "${#MISSING_GROUPS[@]}" -eq 0 ]] && ok "user is in all groups: ${USER_GROUPS[*]}" \
    || fail "$USER is missing groups: ${MISSING_GROUPS[*]}"

[[ "$(getent passwd "$USER" | cut -d: -f7)" == "$LOGIN_SHELL" ]] && ok "login shell is $LOGIN_SHELL" \
    || fail "login shell is not $LOGIN_SHELL"

# --------------------------------------------------
title "Repository"
# --------------------------------------------------

if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
    warn "uncommitted changes in $REPO_DIR"
else
    ok "working tree clean"
fi
AHEAD=$(git -C "$REPO_DIR" rev-list --count '@{u}..HEAD' 2>/dev/null || echo "?")
[[ "$AHEAD" == "0" ]] && ok "all commits pushed to $(git -C "$REPO_DIR" rev-parse --abbrev-ref '@{u}')" \
    || warn "$AHEAD commit(s) not pushed"

printf '\n\033[1m%d ok, %d warning(s), %d failure(s)\033[0m\n' "$PASS" "$WARN" "$FAIL"
exit "$FAIL"
