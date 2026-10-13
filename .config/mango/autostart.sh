#!/bin/sh
# ~/.config/mango/autostart.sh — started once by autostart.conf
#
# The session must be started with `dbus-run-session mango` (the "Mango (D-Bus)"
# entry in the greeter, see system/wayland-sessions/). Every process then shares
# one session bus, which tray icons, notifications and the keyring depend on.

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    echo "autostart.sh: no D-Bus session bus; log in with the 'Mango (D-Bus)' session" >&2
    command -v notify-send >/dev/null && (sleep 5; notify-send -u critical "Sem D-Bus de sessão" \
        "Faça login pela sessão 'Mango (D-Bus)' — tray, notificações e keyring dependem dela.") &
fi

# 1. Export the compositor environment to D-Bus activated services (portals, ...)
dbus-update-activation-environment --all

# 2. Audio (no systemd user units on Void): wireplumber must start last.
#    Before the portals: xdg-desktop-portal-wlr connects to PipeWire at startup
#    and exits if it is not up (no screenshots / screen sharing then).
if ! pgrep -x pipewire >/dev/null; then
    pipewire &
    sleep 1
    pipewire-pulse &
    sleep 1
    wireplumber &
    sleep 1
fi

# 3. Portals (not D-Bus activated reliably on Void without systemd)
# (pgrep -x only sees the first 15 chars of a process name, hence -f)
pgrep -f '^/usr/libexec/xdg-desktop-portal-wlr' >/dev/null || /usr/libexec/xdg-desktop-portal-wlr &
sleep 1
pgrep -f '^/usr/libexec/xdg-desktop-portal$' >/dev/null || /usr/libexec/xdg-desktop-portal &

# 4. Saved monitor layout from Settings > Display
[ -x "$HOME/.config/quickshell/state/display.sh" ] && sh "$HOME/.config/quickshell/state/display.sh"

# 5. Wallpaper daemon (restores the last wallpaper by itself)
pgrep -x awww-daemon >/dev/null || awww-daemon &

# 6. Idle: lock after 10 min, screen off after 15 min (back on with any input),
#    and always lock before suspending. Apps holding an idle inhibitor (video,
#    calls) postpone it. sleep_monitor keeps the window layout intact.
if command -v swayidle >/dev/null && ! pgrep -x swayidle >/dev/null; then
    swayidle -w \
        timeout 600 'qs ipc call lock lock' \
        timeout 900 'mmsg dispatch "sleep_monitor,.*"' \
            resume 'mmsg dispatch "wakeup_monitor,.*"' \
        before-sleep 'qs ipc call lock lock' &
fi

# 7. Quickshell: bar (with system tray), notifications, OSDs, menus, lock screen
pgrep -x qs >/dev/null || qs >"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell.log" 2>&1 &
