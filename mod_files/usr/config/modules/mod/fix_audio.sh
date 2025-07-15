#!/bin/bash

. /etc/profile
. /etc/os-release

amixer -c 0 -M cset name="${DEVICE_PLAYBACK_PATH}" ${DEVICE_PLAYBACK_PATH_SPK}
