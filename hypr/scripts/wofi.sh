#!/bin/sh

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
	export DBUS_SESSION_BUS_ADDRESS=$(pgrep -u $USER -n dbus-daemon | xargs -I{} cat /proc/{}/environ | tr '\0' '\n' | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-)
fi

echo "DBUS_SESSION_BUS_ADDRESS -> $DBUS_SESSION_BUS_ADDRESS" > /tmp/wofi_log

if pgrep -x "wofi" > /dev/null
then
	killall wofi
else
	wofi --no-actions --allow-images --show drun
fi
