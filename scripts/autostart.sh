#!/bin/sh

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# 1. Pega o endereço que o dbus-run-session gerou e injeta no ambiente do Portal e da Waybar
dbus-update-activation-environment --all
dbus-update-activation-environment DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
#idbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

# 2. Reinicia os portais para eles "lerem" o novo endereço
# 2. Reinicia os serviços para garantir que agora eles usem o barramento ativo
killall -9 xdg-desktop-portal xdg-desktop-portal-wlr waybar wireplumber 2>/dev/null
pgrep swaync | xargs kill -9
/usr/libexec/xdg-desktop-portal-wlr &
sleep 1
/usr/libexec/xdg-desktop-portal &

# 3. Inicia o subsistema de áudio
# 3. Inicia o subsistema de áudio de forma sequencial
killall -9 pipewire wireplumber pipewire-pulse 2>/dev/null
pipewire &
sleep 1
pipewire-pulse &
sleep 1
wireplumber & # O Wireplumber DEVE ser o último e ter o pipewire pronto


# 4. Inicia a Waybar (Agora o Tray vai funcionar porque o ambiente DBus está pronto)
waybar &
swaync &
