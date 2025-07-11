#!/bin/bash
# make by G.R.H

. /etc/profile

SHDIR=`cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P`
SILENCE="0"
ROM_DIR="/storage/roms"

if [ -e "/sys/firmware/devicetree/base/model" ]; then
  hw_info="$(tr -d '\0' </sys/firmware/devicetree/base/model 2>/dev/null)"
else
  hw_info="$(tr -d '\0' </sys/class/dmi/id/sys_vendor 2>/dev/null) $(tr -d '\0' </sys/class/dmi/id/product_name 2>/dev/null)"
fi
hw_info="$(echo ${hw_info} | sed -e "s#[/]#-#g")"

rm -rf /storage/roms/bezels/*

if [ -z "$1" ]; then
        mpv --really-quiet --image-display-duration=6000 "$SHDIR/res/bezels.png" &
        pid=$(pidof mpv)

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

        touch /storage/roms/bezels/.done
        sleep 3
        mpv --really-quiet --image-display-duration=6000 "$SHDIR/res/done.png" &
        sleep 0.5
        $ESUDO kill -9 ${pid} &> /dev/null
        pid=$(pidof mpv)
        sleep 3
        $ESUDO kill -9 ${pid} &> /dev/null
else
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

        touch /storage/roms/bezels/.done
fi
exit 0

