#!/bin/sh
# ~/.config/mango/autostart.sh — started once by autostart.conf

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)"
fi

# 1. Export the session environment to D-Bus activated services
dbus-update-activation-environment --all
dbus-update-activation-environment DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY XDG_CURRENT_DESKTOP MANGO_INSTANCE_SIGNATURE

# 2. Restart portals so they pick up the bus above
killall -9 xdg-desktop-portal xdg-desktop-portal-wlr 2>/dev/null
/usr/libexec/xdg-desktop-portal-wlr &
sleep 1
/usr/libexec/xdg-desktop-portal &

# 3. Audio (no systemd user units on Void): wireplumber must start last
killall -9 pipewire wireplumber pipewire-pulse 2>/dev/null
pipewire &
sleep 1
pipewire-pulse &
sleep 1
wireplumber &

# 4. Saved monitor layout from Settings > Display
[ -x "$HOME/.config/quickshell/state/display.sh" ] && sh "$HOME/.config/quickshell/state/display.sh"

# 5. Wallpaper daemon (restores the last wallpaper by itself)
pgrep -x awww-daemon >/dev/null || awww-daemon &

# 6. Quickshell: bar, notifications, OSDs, menus, lock screen.
#    Only one notification daemon can own the bus, so make sure the old ones are gone.
pkill -x waybar 2>/dev/null
pkill -x swaync 2>/dev/null
pkill -x qs 2>/dev/null
sleep 1
qs >"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell.log" 2>&1 &
