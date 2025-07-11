#!/bin/bash
# make by G.R.H

. /etc/profile

SHDIR=`cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P`

if [ -z "$1" ]; then
        mpv  --really-quiet --image-display-duration=6000 "$SHDIR/res/cheats.png" &
        tar xf /storage/data/cheats.tar.gz -C /storage/roms/ANBERNIC/ &>/dev/null
        touch /storage/roms/ANBERNIC/cheats/.done
        pkill -f mpv
        mpv  --really-quiet --image-display-duration=3 "$SHDIR/res/done.png"
else
        tar xf /storage/data/cheats.tar.gz -C /storage/roms/ANBERNIC/ &>/dev/null
        touch /storage/roms/ANBERNIC/cheats/.done
fi
sync
pkill -f mpv
exit 0

