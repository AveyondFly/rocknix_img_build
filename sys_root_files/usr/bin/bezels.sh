#!/bin/sh

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2019-present SumavisionQ5 (https://github.com/SumavisionQ5)
# Modifications by Shanti Gilbert (https://github.com/shantigilbert)

PLATFORM="$1"

ROMNAME=$(basename "${2%.*}")
RACONFIG="/storage/.config/retroarch/retroarch.cfg"
OPACITY="1.000000"
AR_INDEX="23"
BEZELDIR="/storage/roms/bezels"
INIFILE="/storage/.config/system/bezels/settings.ini"
BEZESET="/storage/.config/system/configs/system.cfg"

# Determine whether to turn on bezels
if grep -q "global.bezel=-custom-" $BEZESET ; then
    exit 0
elif grep -q "global.bezel=无" $BEZESET || grep -q "global.bezel=NONE" $BEZESET ; then
    sed -i '/input_overlay_enable = "/d' $RACONFIG
    echo "input_overlay_enable = \""false"\"" >> $RACONFIG
    exit 0
fi

# Obtain device type
if [ -e "/sys/firmware/devicetree/base/model" ]; then
    MY_DEVICE="$(tr -d '\0' </sys/firmware/devicetree/base/model 2>/dev/null)"
else
    MY_DEVICE="$(tr -d '\0' </sys/class/dmi/id/sys_vendor 2>/dev/null) $(tr -d '\0' </sys/class/dmi/id/product_name 2>/dev/null)"
fi
MY_DEVICE="$(echo ${MY_DEVICE} | sed -e "s#[/]#-#g")"

function fscale() {
  for pl in $1
  do
    sed -i '/'"${pl}"'\.integerscale=/d' $BEZESET
    echo ""${pl}".integerscale=1" >> $BEZESET
  done
}

cp -f $BEZESET /storage/.config/system/configs/system.bezel
sed -i '/'.*'.ratio=/d' $BEZESET
echo "global.ratio=core" >> $BEZESET
sed -i '/input_overlay_enable = "/d' $RACONFIG
echo "input_overlay_enable = \""true"\"" >> $RACONFIG
for emu in famicom fds nes nesh sfc snes snesh
do
    echo "${emu}.ratio=8/7" >> $BEZESET
done
sync

# we make sure the platform is all lowercase
PLATFORM=${PLATFORM,,}

case $PLATFORM in
 "arcade"|"fba"|"fbn"|"hbmame"|"neogeo"|"mame"|cps*)
  PLATFORM="arcade"
  ;;
 "gb"|"gbh"|"gbc"|"gbch"|"ngp"|"ngpc"|"gamegear"|"ggh"|"famicom"|"fds"|"nes"|"nesh"|"sfc"|"snes"|"snesh")
  case ${MY_DEVICE} in
      Anbernic\ RG351M)
      fscale "gb gbh gbc gbch gamegear ggh ngp ngpc"
      ;;
      ODROID-GO\ Advance\ Black\ Edition)
      fscale "gb gbh gbc gbch gamegear ggh ngp ngpc"
      ;;
      ODROID-GO\ Super)
      fscale "ngp ngpc famicom fds nes nesh"
      ;;
      Powkiddy\ x55)
      fscale "gb gbh gbc gbch gamegear ggh"
      ;;
      Powkiddy\ RGB10\ MAX\ 3)
      fscale "ngp ngpc"
      ;;
      Anbernic\ RG552)
      fscale "gb gbh gbc gbch gamegear ggh famicom fds nes nesh"
      ;;
      Anbernic\ RG503)
      sync
      ;;
      *)
      fscale "gb gbh gbc gbch gamegear ggh ngp ngpc famicom fds nes nesh"
      ;;
  esac
  ;;
  "default")
  if [ -f "/storage/.config/bezels_enabled" ]; then
  clear_bezel
  sed -i '/input_overlay = "/d' $RACONFIG
  rm "/storage/.config/bezels_enabled"
  fi
   exit 0
  ;;
  "RETROPIE")
  # fbterm does not need bezels
  exit 0
  ;;
esac

 if [ ! -f "/storage/.config/bezels_enabled" ]; then
   touch /storage/.config/bezels_enabled
 fi

# bezelmap.cfg in $BEZELDIR/ is to share bezels between arcade clones and parent. 
BEZELMAP="/storage/.config/system/bezels/arcademap.cfg"
BZLNAME=$(sed -n "/"$PLATFORM"_"$ROMNAME" = /p" "$BEZELMAP")
BZLNAME="${BZLNAME#*\"}"
BZLNAME="${BZLNAME%\"*}"
OVERLAYDIR1=$(find $BEZELDIR/$PLATFORM -maxdepth 1 -iname "$ROMNAME*.cfg" | sort -V | head -n 1)
[ ! -z "$BZLNAME" ] && OVERLAYDIR2=$(find $BEZELDIR/$PLATFORM -maxdepth 1 -iname "$BZLNAME*.cfg" | sort -V | head -n 1)
OVERLAYDIR3="$BEZELDIR/$PLATFORM/default.cfg"

clear_bezel() { 
		sed -i '/aspect_ratio_index = "/d' $RACONFIG
		sed -i '/custom_viewport_width = "/d' $RACONFIG
		sed -i '/custom_viewport_height = "/d' $RACONFIG
		sed -i '/custom_viewport_x = "/d' $RACONFIG
		sed -i '/custom_viewport_y = "/d' $RACONFIG
		sed -i '/video_scale_integer = "/d' $RACONFIG
		sed -i '/input_overlay_opacity = "/d' $RACONFIG
		sed -i '/video_viewport_bias_x = "/d' $RACONFIG
		sed -i '/video_viewport_bias_y = "/d' $RACONFIG
		echo 'video_scale_integer = "false"' >> $RACONFIG
		echo 'input_overlay_opacity = "1.000000"' >> $RACONFIG
		}

set_bezel() {
# $OPACITY: input_overlay_opacity
# $AR_INDEX: aspect_ratio_index
# $1: custom_viewport_width 
# $2: custom_viewport_height
# $3: ustom_viewport_x
# $4: custom_viewport_y
# $5: video_scale_integer
# $6: video_scale 
        
        clear_bezel
        sed -i '/input_overlay_opacity = "/d' $RACONFIG
        sed -i "1i input_overlay_opacity = \"$OPACITY\"" $RACONFIG
        sed -i "2i aspect_ratio_index = \"$AR_INDEX\"" $RACONFIG
        sed -i "3i custom_viewport_width = \"$1\"" $RACONFIG
        sed -i "4i custom_viewport_height = \"$2\"" $RACONFIG
        sed -i "5i custom_viewport_x = \"$3\"" $RACONFIG
        sed -i "6i custom_viewport_y = \"$4\"" $RACONFIG
        sed -i "7i video_scale_integer = \"$5\"" $RACONFIG
        sed -i "8i video_viewport_bias_x = \"0\"" $RACONFIG
        sed -i "9i video_viewport_bias_y = \"1\"" $RACONFIG

}

check_overlay_dir() {

# The bezel will be searched and used in following order:
# 1.$OVERLAYDIR1 will be used, if it does not exist, then
# 2.$OVERLAYDIR2 will be used, if it does not exist, then
# 3.$OVERLAYDIR2 platform default bezel as "$BEZELDIR/"$PLATFORM"/default.cfg\" will be used.
# 4.Default bezel at "$BEZELDIR/default.cfg\" will be used.
	
	sed -i '/input_overlay = "/d' $RACONFIG
		
	if [ -f "$OVERLAYDIR1" ]; then
		echo "input_overlay = \""$OVERLAYDIR1"\"" >> $RACONFIG
	elif [ -f "$OVERLAYDIR2" ]; then
		echo "input_overlay = \""$OVERLAYDIR2"\"" >> $RACONFIG
	elif [ -f "$OVERLAYDIR3" ]; then
		echo "input_overlay = \""$OVERLAYDIR3"\"" >> $RACONFIG
	else
		echo "input_overlay = \"$BEZELDIR/default.cfg\"" >> $RACONFIG
	fi
}

if [ -f "/storage/.config/retroarch/Dark.txt" ]; then
    OPACITY="0.300000"
fi
check_overlay_dir "$PLATFORM"
clear_bezel
sed -i '/input_overlay_opacity = "/d' $RACONFIG
sed -i "1i input_overlay_opacity = \"$OPACITY\"" $RACONFIG
#sed -i '/input_overlay_enable_autopreferred = "/d' $RACONFIG
#echo 'input_overlay_enable_autopreferred = "false"' >> $RACONFIG

# Set according to the grh_parameter
if [ -f "$OVERLAYDIR3" ]; then
    . $OVERLAYDIR3 &>/dev/null
    if [[ $grh_parameter -eq 1 ]]; then
        case ${grh_integerscale} in
            1)
                grh_integerscale="true"
            ;;
            *)
                grh_integerscale="false"
            ;;
        esac
        sed -i '/'.*'.ratio=/d' $BEZESET
        sed -i '/'.*'.integerscale=/d' $BEZESET
        echo "${PLATFORM}.ratio=${grh_ratio}" >> $BEZESET
        echo "${PLATFORM}.integerscale=${grh_integerscale}" >> $BEZESET
        set_bezel ${grh_custom_viewport_width} ${grh_custom_viewport_height} ${grh_custom_viewport_x} ${grh_custom_viewport_y} ${grh_integerscale}
    fi
fi

# If we disable bezel in setting.ini for certain platform, we just delete bezel config.
Bezel=$(sed -n "/"$PLATFORM"_Bezel = /p" $INIFILE)
Bezel="${Bezel#*\"}"
Bezel="${Bezel%\"*}"
if [ "$Bezel" = "OFF" ]; then
sed -i '/input_overlay = "/d' $RACONFIG
fi

# Note:
# 1. Different handheld platforms have different bezels, they may need different viewport value even for same platform.
#	So, I think this script should be stored in $BEZELDIR/ or some place wich can be modified by users.
# 2. For Arcade games, I created a bezelmap.cfg in $BEZELDIR/ in order to share bezels between arcade clones and parent. 
#	In fact, ROMs of other platforms can share certain bezel if you write mapping relationship in bezelmap.cfg.
# 3. I modified es_systems.cfg to set $1 as platfrom for all platfrom.
#	For some libretro core such as <command>/usr/bin/sx05reRunEmu.sh LIBRETRO scummvm %ROM%</command>, $1 not right platform value,
#	you may need some tunings on them.
# 4. I am a Linux noob, so the codes are a mess. Sorry for that:)
