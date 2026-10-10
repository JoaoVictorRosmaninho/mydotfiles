#!/bin/bash
# 
cliphist list | wofi -p "Select the copy content" --dmenu | cliphist decode | wl-copy
