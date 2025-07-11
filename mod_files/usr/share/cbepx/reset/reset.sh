#!/bin/bash
#make by G.R.H

. /etc/profile
. /etc/os-release

SHDIR="$(cd $(dirname "$0"); pwd)"
RACFG="/storage/.config/retroarch/retroarch.cfg"
SYSCFG="/storage/.config/system/configs/system.cfg"
ROM_DIR="/storage/roms"

function Set_ra() {
    sed -i -e '/input_enable_hotkey_btn\ \=/c\input_enable_hotkey_btn\ \=\ \"'${1}'\"' ${RACFG}
    sed -i -e '/input_menu_toggle_btn\ \=/c\input_menu_toggle_btn\ \=\ \"'${2}'\"' ${RACFG}
    sed -i -e '/input_exit_emulator_btn\ \=/c\input_exit_emulator_btn\ \=\ \"'${3}'\"' ${RACFG}
    sed -i -e '/input_toggle_fast_forward_btn\ \=/c\input_toggle_fast_forward_btn\ \=\ \"'${4}'\"' ${RACFG}
    sed -i -e '/input_toggle_slowmotion_btn\ \=/c\input_toggle_slowmotion_btn\ \=\ \"'${5}'\"' ${RACFG}
    sed -i -e '/input_rewind_btn\ \=/c\input_rewind_btn\ \=\ \"'${6}'\"' ${RACFG}
    sed -i -e '/input_pause_toggle_btn\ \=/c\input_pause_toggle_btn\ \=\ \"'${7}'\"' ${RACFG}
    sed -i -e '/input_load_state_btn\ \=/c\input_load_state_btn\ \=\ \"'${8}'\"' ${RACFG}
    sed -i -e '/input_save_state_btn\ \=/c\input_save_state_btn\ \=\ \"'${9}'\"' ${RACFG}
    sed -i -e '/input_state_slot_increase_btn\ \=/c\input_state_slot_increase_btn\ \=\ \"'${10}'\"' ${RACFG}
    sed -i -e '/input_state_slot_decrease_btn\ \=/c\input_state_slot_decrease_btn\ \=\ \"'${11}'\"' ${RACFG}
    sed -i -e '/input_screenshot_btn\ \=/c\input_screenshot_btn\ \=\ \"'${12}'\"' ${RACFG}
    sed -i -e '/input_fps_toggle_btn\ \=/c\input_fps_toggle_btn\ \=\ \"'${13}'\"' ${RACFG}
    sed -i -e '/menu_scale_factor\ \=/c\menu_scale_factor\ \=\ \"'${14}'\"' ${RACFG}
    sed -i -e '/menu_widget_scale_factor\ \=/c\menu_widget_scale_factor\ \=\ \"'${15}'\"' ${RACFG}
}

function Set_system() {
    sed -i -e '/zxspectrum.ratio/{r '${SHDIR}'/'${2}'.cfg' -e 'd}' ${SYSCFG}
    sed -i -e '/system.hostname\=/c\system.hostname\='"${1}"'' ${SYSCFG}
    sed -i -e '/boot\=/c\boot\=Emulationstation' ${SYSCFG}
    sed -i -e '/audio.volume\=/c\audio.volume\=60' ${SYSCFG}
    sed -i -e '/rotate.root.password\=/c\rotate.root.password\=0' ${SYSCFG}
    sed -i -e '/samba.enabled\=/c\samba.enabled\=0' ${SYSCFG}
    sed -i -e '/ssh.enabled\=/c\ssh.enabled\=0' ${SYSCFG}
    sed -i -e '/system.autohotkeys\=/c\system.autohotkeys\=0' ${SYSCFG}
    sed -i -e '/system.automount\=/c\system.automount\=1' ${SYSCFG}
    sed -i -e '/system.language\=/c\system.language\=zh_CN' ${SYSCFG}
    sed -i -e '/system.timezone\=/c\system.timezone\=Asia\/Shanghai' ${SYSCFG}
    sed -i -e '/global.retroarch.menu_driver\=/c\global.retroarch.menu_driver\=ozone' ${SYSCFG}
    echo "system.suspendmode=freeze" >>  ${SYSCFG}
    echo "root.password=linux" >> ${SYSCFG}
}

function Set_ra_ext() {
	gamecontrollerdb="/storage/.config/SDL-GameControllerDB/gamecontrollerdb.txt"

	# 通过joyguid获取GUID
	guid=$(joyguid 2>/dev/null | tr -d '\n')

	# 异常处理
	if [ -z "$guid" ]; then
		echo "错误：无法获取Joystick GUID，请检查joyguid工具" >&2
		exit 1
	fi

	# 查找匹配行
	mapping_line=$(grep -m1 "^${guid}," "$gamecontrollerdb")
	if [ -z "$mapping_line" ]; then
		echo "错误：未找到GUID $guid 对应的控制器配置" >&2
		exit 1
	fi

	# 解析并生成带前缀的变量
	eval "$(
	echo "$mapping_line" | awk -F, '
	{
		for(i=1; i<=NF; i++) {
			if($i ~ /^[a-zA-Z]+:b[0-9]+$/) {
				split($i, pair, ":")
				key = pair[1]
				value = substr(pair[2],2)  # 去掉b前缀
				printf "declare -g mapped_%s=%d\n", key, value  # 添加前缀
			}
		}
	}'
	)"

	if [ ! -z "${mapped_guide}" ]; then
		sed -i -e '/input_enable_hotkey_btn\ \=/c\input_enable_hotkey_btn\ \=\ \"'${mapped_guide}'\"' ${RACFG}
	else
		sed -i -e '/input_enable_hotkey_btn\ \=/c\input_enable_hotkey_btn\ \=\ \"'${mapped_back}'\"' ${RACFG}
	fi
	sed -i -e '/input_menu_toggle_btn\ \=/c\input_menu_toggle_btn\ \=\ \"'${mapped_x}'\"' ${RACFG}
	sed -i -e '/input_exit_emulator_btn\ \=/c\input_exit_emulator_btn\ \=\ \"'${mapped_start}'\"' ${RACFG}
	sed -i -e '/input_toggle_fast_forward_btn\ \=/c\input_toggle_fast_forward_btn\ \=\ \"'${mapped_righttrigger}'\"' ${RACFG}
	sed -i -e '/input_toggle_slowmotion_btn\ \=/c\input_toggle_slowmotion_btn\ \=\ \"'${mapped_lefttrigger}'\"' ${RACFG}
	if [ ! -z "${mapped_leftstick}" ]; then
		sed -i -e '/input_rewind_btn\ \=/c\input_rewind_btn\ \=\ \"'${mapped_leftstick}'\"' ${RACFG}
	else
		sed -i -e '/input_rewind_btn\ \=/c\input_rewind_btn\ =' ${RACFG}
	fi
	sed -i -e '/input_pause_toggle_btn\ \=/c\input_pause_toggle_btn\ \=\ \"'${mapped_a}'\"' ${RACFG}
	sed -i -e '/input_load_state_btn\ \=/c\input_load_state_btn\ \=\ \"'${mapped_rightshoulder}'\"' ${RACFG}
	sed -i -e '/input_save_state_btn\ \=/c\input_save_state_btn\ \=\ \"'${mapped_leftshoulder}'\"' ${RACFG}
	sed -i -e '/input_state_slot_increase_btn\ \=/c\input_state_slot_increase_btn\ \=\ \"'${mapped_dpup}'\"' ${RACFG}
	sed -i -e '/input_state_slot_decrease_btn\ \=/c\input_state_slot_decrease_btn\ \=\ \"'${mapped_dpdown}'\"' ${RACFG}
	sed -i -e '/input_screenshot_btn\ \=/c\input_screenshot_btn\ \=\ \"'${mapped_b}'\"' ${RACFG}
	sed -i -e '/input_fps_toggle_btn\ \=/c\input_fps_toggle_btn\ \=\ \"'${mapped_y}'\"' ${RACFG}
	sed -i -e '/menu_scale_factor\ \=/c\menu_scale_factor\ \=\ \"'${1}'\"' ${RACFG}
	sed -i -e '/menu_widget_scale_factor\ \=/c\menu_widget_scale_factor\ \=\ \"'${2}'\"' ${RACFG}
}

# Restore default files
cp -f /usr/config/system/configs/system.cfg ${SYSCFG}
cp -f /usr/config/retroarch/retroarch.cfg ${RACFG}
[ -f /storage/data/cheats.tar.gz ] && tar xf /storage/data/cheats.tar.gz -C ${ROM_DIR}/ANBERNIC/ &>/dev/null
[ -f /storage/data/datas.zip ] && unzip -oq /storage/data/datas.zip -d /storage &>/dev/null

# Global Settings
sed -i -e '/menu_driver\ \=/c\menu_driver\ \=\ \"ozone\"' ${RACFG}
sed -i -e '/aspect_ratio_index\ \=/c\aspect_ratio_index\ \=\ \"22\"' ${RACFG}
sed -i -e '/quick_menu_show_save_core_overrides\ \=/c\quick_menu_show_save_core_overrides\ \=\ \"true\"' ${RACFG}
sed -i -e '/quick_menu_show_save_game_overrides\ \=/c\quick_menu_show_save_game_overrides\ \=\ \"true\"' ${RACFG}
sed -i -e '/quick_menu_show_undo_save_load_state\ \=/c\quick_menu_show_undo_save_load_state\ \=\ \"true\"' ${RACFG}

# Custom Settings
## Set_ra "10-hotkey-f" "4-menu-x" "11-exit-start" "9-fast-r2" "8-slow-l2" "2-rewind-r3" "0-pause-a" "6-load-l1" "7-save-r1" "15--right" "14--left" "3-shreenshot-b" "1-fps-y" "1.000000-scale"
## Set_system "HOST NAME" "xxx.cfg"
echo -e "$QUIRK_DEVICE" > /storage/.config/hw_info.conf
rm -rf "${ROM_DIR}/bezels"
case ${QUIRK_DEVICE} in
    "Anbernic RG34XX")
        unzip -oq /usr/share/cbepx/reset/34xx.zip -d /storage
        [ -f /storage/data/bezels-351.zip ] && unzip -oq /storage/data/bezels-351.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "3" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "2" "0.400000" "0.300000"
        Set_system "RG34XX" "353"
    ;;
    "Anbernic RG CubeXX")
        unzip -oq /usr/share/cbepx/reset/h700.zip -d /storage
        [ -f /storage/data/bezels-30.zip ] && unzip -oq /storage/data/bezels-30.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "3" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "2" "0.400000" "0.300000"
        Set_system "RGCUBEXX" "30"
    ;;
    "Anbernic RG40XX V")
        unzip -oq /usr/share/cbepx/reset/40xx.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "3" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "2" "0.400000" "0.300000"
        Set_system "RG40XX-V" "353"
    ;;
    "Anbernic RG40XX H")
        unzip -oq /usr/share/cbepx/reset/h700.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "3" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "2" "0.400000" "0.300000"
        Set_system "RG40XX-H" "353"
    ;;
    "Anbernic RG28XX")
        unzip -oq /usr/share/cbepx/reset/h700.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "3" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "2" "0.400000" "0.300000"
        Set_system "RG28XX" "353"
    ;;
    "Anbernic RG35XX 2024")
        unzip -oq /usr/share/cbepx/reset/h700.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "3" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "2" "0.400000" "0.300000"
        Set_system "RG35XX-2024" "353"
    ;;
    "Anbernic RG35XX H")
        unzip -oq /usr/share/cbepx/reset/h700.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "3" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "2" "0.400000" "0.300000"
        Set_system "RG35XX-H" "353"
    ;;
    "Anbernic RG35XX Plus")
        unzip -oq /usr/share/cbepx/reset/h700.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "3" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "2" "0.400000" "0.300000"
        Set_system "RG35XX-P" "353"
    ;;
    "Anbernic RG35XX SP")
        unzip -oq /usr/share/cbepx/reset/h700.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "3" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "2" "0.400000" "0.300000"
        Set_system "RG35XX-SP" "353"
    ;;
    "Anbernic RG ARC-D")
        unzip -oq /usr/share/cbepx/reset/arc.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "4" "11" "9" "8" "2" "0" "6" "7" "15" "14" "3" "1" "0.400000" "0.300000"
        Set_system "RGARC-D" "353"
    ;;
    "Anbernic RG ARC-S")
        unzip -oq /usr/share/cbepx/reset/arc.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "4" "11" "9" "8" "2" "0" "6" "7" "15" "14" "3" "1" "0.400000" "0.300000"
        Set_system "RGARC-S" "353"
    ;;
    "Anbernic RG353P")
        unzip -oq /usr/share/cbepx/reset/353.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RG353P" "353"
    ;;
    "Anbernic RG353PS")
        unzip -oq /usr/share/cbepx/reset/353.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RG353PS" "353"
    ;;
    "Anbernic RG353M"|RG353Mm)
        unzip -oq /usr/share/cbepx/reset/353.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RG353M" "353"
    ;;
    "Anbernic RG353V")
        unzip -oq /usr/share/cbepx/reset/353.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RG353V" "353"
    ;;
    "Anbernic RG353VS")
        unzip -oq /usr/share/cbepx/reset/353.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "10" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RG353VS" "353"
    ;;
    "Anbernic RG503")
        unzip -oq /usr/share/cbepx/reset/353.zip -d /storage
        [ -f /storage/data/bezels-503.zip ] && unzip -oq /storage/data/bezels-503.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RG503" "503"
    ;;
    "Anbernic RG351M")
        unzip -oq /usr/share/cbepx/reset/351m.zip -d /storage
        [ -f /storage/data/bezels-351.zip ] && unzip -oq /storage/data/bezels-351.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "7" "2" "6" "11" "10" "9" "0" "4" "5" "h0right" "h0left" "1" "3" "0.400000" "0.300000"
        Set_system "RG351M" "552"
    ;;
    "Anbernic RG351V")
        unzip -oq /usr/share/cbepx/reset/351v.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "9" "2" "6" "11" "10" "nul" "0" "4" "5" "h0right" "h0left" "1" "3" "0.400000" "0.300000"
        Set_system "RG351V" "552"
    ;;
    "Anbernic RG552")
        unzip -oq /usr/share/cbepx/reset/552.zip -d /storage
        [ -f /storage/data/bezels-552.zip ] && unzip -oq /storage/data/bezels-552.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RG552" "552"
    ;;
    "Anbernic Win600")
        unzip -oq /usr/share/cbepx/reset/600.zip -d /storage
        [ -f /storage/data/bezels-503.zip ] && unzip -oq /storage/data/bezels-503.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "6" "3" "7" "+5" "+2" "10" "1" "4" "5" "h0right" "h0left" "0" "2" "0.400000" "0.300000"
        Set_system "Win600" "552"
    ;;
    "ODROID-GO Super")
        unzip -oq /usr/share/cbepx/reset/max.zip -d /storage
        [ -f /storage/data/bezels-go.zip ] && unzip -oq /storage/data/bezels-go.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "12" "2" "13" "7" "6" "17" "1" "4" "5" "11" "10" "0" "3" "0.400000" "0.300000"
        Set_system "OGS" "552"
    ;;
    "Powkiddy RGB10")
        unzip -oq /usr/share/cbepx/reset/rgb10.zip -d /storage
        [ -f /storage/data/bezels-351.zip ] && unzip -oq /storage/data/bezels-351.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "13" "2" "15" "14" "12" "nul" "1" "4" "5" "11" "10" "0" "3" "0.400000" "0.300000"
        Set_system "RGB10" "552"
	set_setting key.function.a BTN_THUMBR
    ;;
    "Powkiddy RGB20S")
        unzip -oq /usr/share/cbepx/reset/max.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "12" "2" "13" "7" "6" "17" "1" "4" "5" "11" "10" "0" "3" "0.400000" "0.300000"
        Set_system "RGB20S" "552"
	set_setting key.hotkey.b BTN_TRIGGER_HAPPY1
	set_setting key.hotkey.c BTN_TRIGGER_HAPPY2
	set_setting key.function.a BTN_TRIGGER_HAPPY1
	set_setting key.function.b BTN_TRIGGER_HAPPY2
    ;;
    "Powkiddy RGB10X")
        unzip -oq /usr/share/cbepx/reset/max.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
	Set_ra "10" "2" "9" "7" "6" "11" "12" "4" "5" "13" "14" "1" "3" "0.400000" "0.300000"
        Set_system "RGB10X" "552"
	pre_nds_cfg="/storage/.config/drastic/config/drastic.cfg_10x"
    ;;
    "Game Console R36S")
        unzip -oq /usr/share/cbepx/reset/max.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
	#Set_ra "10" "2" "9" "7" "6" "11" "12" "4" "5" "13" "14" "1" "3" "0.400000" "0.300000"
        Set_system "R36S" "552"
    ;;
    "Powkiddy RK2023")
        unzip -oq /usr/share/cbepx/reset/353.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RK2023" "353"
    ;;
    "Powkiddy RGB20P")
        unzip -oq /usr/share/cbepx/reset/20p.zip -d /storage
        [ -f /storage/data/bezels-503.zip ] && unzip -oq /storage/data/bezels-503.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RGB20PRO" "353"
    ;;
    "Powkiddy RGB30")
        unzip -oq /usr/share/cbepx/reset/30.zip -d /storage
        [ -f /storage/data/bezels-30.zip ] && unzip -oq /storage/data/bezels-30.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RGB30" "30"
    ;;
    "Powkiddy RGB20SX")
        unzip -oq /usr/share/cbepx/reset/30.zip -d /storage
        [ -f /storage/data/bezels-30.zip ] && unzip -oq /storage/data/bezels-30.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RGB20SX" "30"
    ;;
    "Powkiddy RGB10 MAX 3 Pro")
        unzip -oq /usr/share/cbepx/reset/max3p.zip -d /storage
        [ -f /storage/data/bezels-503.zip ] && unzip -oq /storage/data/bezels-503.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "13" "2" "17" "7" "6" "15" "1" "4" "5" "11" "10" "0" "3" "0.400000" "0.300000"
        Set_system "RGB10MAX3PRO" "353"
    ;;
    "Powkiddy RGB10 Max 3")
        unzip -oq /usr/share/cbepx/reset/max3.zip -d /storage
        [ -f /storage/data/bezels-503.zip ] && unzip -oq /storage/data/bezels-503.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "1" "4" "5" "16" "15" "0" "3" "0.400000" "0.300000"
        Set_system "RGB10MAX3" "x55"
    ;;
    "Powkiddy x55")
        unzip -oq /usr/share/cbepx/reset/x55.zip -d /storage
        [ -f /storage/data/bezels-503.zip ] && unzip -oq /storage/data/bezels-503.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "0" "4" "5" "16" "15" "1" "3" "0.400000" "0.300000"
        Set_system "X55" "x55"
    ;;
    "Powkiddy x35s")
        unzip -oq /usr/share/cbepx/reset/x55.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "0" "4" "5" "16" "15" "1" "3" "0.400000" "0.300000"
        Set_system "X35S" "x35"
    ;;
    "Powkiddy x35h")
        unzip -oq /usr/share/cbepx/reset/x35h.zip -d /storage
        [ -f /storage/data/bezels-353.zip ] && unzip -oq /storage/data/bezels-353.zip -d ${ROM_DIR}/ &>/dev/null
        Set_ra "8" "2" "9" "7" "6" "12" "0" "4" "5" "16" "15" "1" "3" "0.400000" "0.300000"
        Set_system "X35H" "x35"
    ;;
    "RGBMAX4")
        unzip -oq /usr/share/cbepx/reset/max4.zip -d /storage
        Set_ra "11" "3" "10" "8" "7" "13" "1" "5" "6" "17" "16" "0" "4" "0.400000" "0.300000"
        Set_system "RGBMAX4" "353"
    ;;
    "XiFan MyMini")
        unzip -oq /usr/share/cbepx/reset/max.zip -d /storage
        Set_system "MyMini" "552"
	pre_nds_cfg="/storage/.config/drastic/config/drastic.cfg_mm"
    ;;
    "XiFan R36Pro")
        Set_system "R36Pro" "552"
    ;;
    "XiFan R36Max")
        Set_system "R36Max" "30"
    ;;
    "Clone R36s G28")
        Set_system "R36s_G28" "552"
    ;;
    "Clone R36s G80")
        Set_system "R36s_G80" "552"
    ;;
    *)
        unzip -oq /usr/share/cbepx/reset/353.zip -d /storage
        Set_system "Rockchip" "353"
    ;;
esac

if [ -z "${pre_nds_cfg}" ]; then
	cp /storage/.config/drastic/config/drastic.cfg_pre /storage/.config/drastic/config/drastic.cfg
	gen_drastic.sh /storage/.config/drastic/config/drastic.cfg
else
	cp ${pre_nds_cfg} /storage/.config/drastic/config/drastic.cfg
fi
rm -rf /storage/.config/drastic/config/drastic.cf2
rm -rf /storage/.config/drastic/config/drastic.cfg.*
rm -rf /storage/.config/drastic/usrcheat.dat


# 定义目标分辨率列表（带格式验证）
TARGET_RES="1920x1080 1080x1920 1280x720 720x1280 544x960 960x544 720x720 480x640 640x480 480x320 320x480"

# 双重过滤提取分辨率
detected_res=$(
    grep -oE '(1920x1080|1080x1920|1280x720|720x1280|960x544|544x960|720x720|640x480|480x640|480x320|320x480)' /sys/class/graphics/fb0/modes |
    grep -xE "$(echo "$TARGET_RES" | tr ' ' '|')" |
    head -n1
)

if [[ -n "$detected_res" ]]; then
    # 分割分辨率字符串为宽和高
    IFS='x' read -r width height <<< "$detected_res"
    
    # 比较宽和高，并且交换位置如果需要的话
    if (( width < height )); then
        detected_res="${height}x${width}"
    fi
fi

# 设置默认分辨率
default_res="960x544"
target_zip=/storage/data/"bezels_${detected_res:-$default_res}.zip"

# 执行解压（带安全检查）
if [ -f "$target_zip" ]; then
    unzip -oq "$target_zip" -d ${ROM_DIR}/ || echo "解压失败，请检查ZIP文件完整性"
else
    echo "错误: 必需的压缩包 $target_zip 不存在"
fi

nds_resolutions="1920x1080 1280x720 720x720 640x480"
if [[ ! " $nds_resolutions " =~ " $detected_res " ]]; then
	rm -rf /storage/.config/drastic/lib/libSDL2-2.0.so.0 
fi

set_setting key.dpad.events 1

Set_ra_ext "0.400000" "0.300000"

sync

if [ "$(systemctl is-active input)" = "active" ]
then
  systemctl restart input
fi
exit 0
