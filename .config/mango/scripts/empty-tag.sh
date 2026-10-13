#!/bin/sh
# Go to the first empty tag, preferring the task tags 6-9 (then any other).
#   empty-tag.sh view   switch to it                  (Super+Ctrl+N)
#   empty-tag.sh move   take the focused window there (Super+Ctrl+Shift+N)
set -eu

tag=$(mmsg get all-monitors | jq -r '
    .monitors[] | select(.active) | [.tags[] | select(.client_count == 0) | .index]
    | (map(select(. >= 6)) + map(select(. < 6))) | first // empty')

if [ -z "$tag" ]; then
    notify-send -a mango "Nenhuma tag vazia" "Todas as 9 tags têm janelas."
    exit 0
fi

case "${1:-view}" in
    move) mmsg dispatch "tag,$tag,0" ;;
    *)    mmsg dispatch "view,$tag,0" ;;
esac
