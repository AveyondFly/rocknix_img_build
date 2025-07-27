#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2019-present Shanti Gilbert (https://github.com/shantigilbert)
# Copyright (C) 2021-present 351ELEC (https://github.com/351ELEC)
# Copyright (C) 2023 JELOS (https://github.com/JustEnoughLinuxOS)

# OpenBOR only works with Pak files, if you have an extracted game you will need to create a pak first.

OB=${2}
[[ -z ${OB} ]] && OB=OpenBOR

pakname=$(basename "$1")
pakname="${pakname%.*}"

CONFIGDIR="/storage/openbor"
PAKS="${CONFIGDIR}/Paks"
SAVES="${CONFIGDIR}/Saves"

# Make sure the folders exists
  mkdir -p "${CONFIGDIR}"
  mkdir -p "${PAKS}"
  mkdir -p "${SAVES}"

# Check if master.cfg exists
  if [ ! -f "${CONFIGDIR}/master.cfg" ]; then
    cp -f "/usr/config/openbor/master.cfg" "${CONFIGDIR}/"
  fi

# Clear PAKS folder to avoid getting the launcher on next run
  rm -rf ${PAKS}/*

# make a symlink to the pak
  ln -sf "$1" "${PAKS}"

# only create symlink to master.cfg if its the first time running the pak
if [ ! -f "${SAVES}/${pakname}.cfg" ]; then
	if [ ${OB} = "OpenBOR_ff" ]; then
		ln -sf "${CONFIGDIR}/masterff.cfg" "${SAVES}/${pakname}.cfg"
	else
		ln -sf "${CONFIGDIR}/master.cfg" "${SAVES}/${pakname}.cfg"
	fi
fi

# We start the fake keyboard
gptokeyb -c /usr/config/gptokeyb/openbor.gptk ${OB} &

# Run OpenBOR in the config folder
  cd "${CONFIGDIR}"
  ${OB}

# We stop the fake keyboard
  killall gptokeyb &
