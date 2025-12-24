#!/bin/sh


if pgrep -x "wofi" > /dev/null
then
	killall wofi
else
	wofi --no-actions --allow-images --show drun
fi
