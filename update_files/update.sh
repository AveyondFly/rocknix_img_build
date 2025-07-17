#!/bin/bash
#make by G.R.H

. /etc/profile

SHDIR="$(cd $(dirname "$0"); pwd)"
. $SHDIR/functions
hidecursor
ROM_DIR="/storage/roms"
#[ -d "/storage/games-external/roms" ] && ROM_DIR="/storage/games-external/roms"

function Test_Button_A(){
  evtest --query $event_dev $event_type $event_btn_a
}

function Test_Button_B(){
  evtest --query $event_dev $event_type $event_btn_b
}

event_type="EV_KEY"
event_btn_a="BTN_EAST"
event_btn_b="BTN_SOUTH"
event_dev=`readlink -f /dev/input/by-path/platform-*event-joystick`

echo -e "\n" >/dev/tty0
echo " =======================" >/dev/tty0
echo -e "  \033[33mROCK\033[0m\033[37mNIX\033[0m \033[32mMod\033[0m Installer" >/dev/tty0
echo " =======================" >/dev/tty0
echo " Begin installing:" >/dev/tty0
mkdir -p /storage/data &> /dev/null
[ -d /flash/update ] && StartProgress spinner "   - Syncing files... " "cp -rf /flash/update/* /storage/data/ &>/dev/null" >/dev/tty0
[ -f /storage/data/jdk.zip ] && StartProgress spinner "   - Installing j2me sdk files... " "unzip -oq /storage/data/jdk.zip -d /storage &>/dev/null" >/dev/tty0
chmod 755 -R /storage/jdk/*
touch /storage/.done &> /dev/null
cp -f /usr/share/version.conf /storage/.config/version.conf &> /dev/null
chmod 644 /storage/.config/drastic/aarch64/drastic/config/drastic.cf2
chmod 644 /storage/.config/drastic/aarch64/drastic/config/drastic.cfg
chmod 644 /storage/.config/emulationstation/es_settings.cfg
chmod 644 /storage/.config/openbor/master.cfg
chmod 644 /storage/.config/ppsspp/PSP/SYSTEM/controls.ini
chmod 644 /storage/.config/ppsspp/PSP/SYSTEM/ppsspp.ini
chmod 644 /storage/.config/retroarch/retroarch.cfg
chmod 644 /storage/.config/retroarch/retroarch-core-options.cfg
chmod 755 -R /storage/.config/retroarch/config/*
chmod 644 /storage/.config/system/configs/system.cfg
chmod 644 /storage/openbor/master.cfg
chmod 755 -R /storage/remappings/*
if [ ! -f "${ROM_DIR}/neogeo/neogeo.zip" ] && [ -f /storage/data/roms.tar.gz ]; then
	[ -f "${ROM_DIR}/bios/dc/vmu_save_A1.bin" ] && mkdir -p ${ROM_DIR}/dc_tmp && cp ${ROM_DIR}/bios/dc/vmu_save* ${ROM_DIR}/dc_tmp/
	StartProgress spinner "   - Installing roms files....... " "tar -xf /storage/data/roms.tar.gz -C ${ROM_DIR} &>/dev/null" >/dev/tty0
	[ -f "${ROM_DIR}/dc_tmp/vmu_save_A1.bin" ] && cp -f ${ROM_DIR}/dc_tmp/* ${ROM_DIR}/bios/dc/ && rm -rf ${ROM_DIR}/dc_tmp
fi
[ -f /storage/data/datas.zip ] && StartProgress spinner "   - Installing cheat part1...... " "unzip -oq /storage/data/datas.zip -d /storage &>/dev/null" >/dev/tty0
if [ ! -d "${ROM_DIR}/ANBERNIC/cheats/0-中文金手指" ]; then
	[ -f /storage/data/cheats.tar.gz ] && StartProgress spinner "   - Installing cheat part2...... " "tar xf /storage/data/cheats.tar.gz -C ${ROM_DIR}/ANBERNIC/ &>/dev/null" >/dev/tty0
	touch /storage/roms/ANBERNIC/cheats/.done
fi
[ -f /storage/data/themes.zip ] && StartProgress spinner "   - Installing theme files...... " "unzip -oq /storage/data/themes.zip -d /storage/.config/emulationstation &>/dev/null" >/dev/tty0

mkdir -p /storage/cores
[ -f /storage/data/mod_cores.zip ] && StartProgress spinner "   - Installing custom cores...... " "find /storage/data -type f -name "mod_cores*.zip" -print0 | xargs -0 -I {} unzip {} -d /storage/cores &>/dev/null" >/dev/tty0

rm -rf ${ROM_DIR}/ANBERNIC/shaders/*
rm -rf /storage/.tk_* &> /dev/null
StartProgress spinner "   - Setting system parameters... " "/usr/share/cbepx/reset/reset.sh &>/dev/null" >/dev/tty0
echo " Installed successfully." >/dev/tty0
printf "\n " >/dev/tty0
printf "\n==> Please set the system default language:" >/dev/tty0
printf "\n " >/dev/tty0
echo -e "\nPress \033[31mA\033[0m to \033[32mSimple Chinese\033[0m. \033[33mB\033[0m to \033[32mEnglish\033[0m.\n" >/dev/tty0
time_start=$(date --date=`date +'%H:%M:%S'` +%s)
while true
do
   Test_Button_A
   if [ "$?" -eq "10" ]; then
     sed -i -e '/system\.language\=/c system\.language\=zh_CN' /storage/.config/system/configs/system.cfg
     echo -e "\033[31mA\033[0m - \033[32mSimple Chinese\033[0m" >/dev/tty0
     break
   fi
   Test_Button_B
   if [ "$?" -eq "10" ]; then
     sed -i -e '/system\.language\=zh_CN/c system\.language\=en_US' /storage/.config/system/configs/system.cfg
     cp -f /usr/config/modules/gamelist_en.xml /storage/.config/modules/gamelist.xml
     chmod 644 /storage/.config/modules/gamelist.xml
     echo -e "\033[33mB\033[0m - \033[32mEnglish\033[0m" >/dev/tty0
     break
   fi
   time_end=$(date --date=`date +'%H:%M:%S'` +%s) && let "time_time=${time_end} - ${time_start}"
   if [ $time_time -ge 9 ]; then
     echo -e "Timeout $event_dev. Default to \033[32mSimple Chinese\033[0m" >/dev/tty0
     sed -i -e '/system\.language\=/c system\.language\=zh_CN' /storage/.config/system/configs/system.cfg
     break
   fi
done

mv $0 $0_bak

sync
