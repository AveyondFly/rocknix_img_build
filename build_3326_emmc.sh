#! /bin/bash

# 定义扩容函数
resize_img() {
    local IMG="$1"
    local NEW_SIZE="$2"
    local MAX_SIZE="${3:-2200}"  # 默认最大2.2GB
    local FS_TYPE="${4:-ext4}"   # 默认ext4文件系统

    # 检查文件存在
    if [ ! -f "$IMG" ]; then
        echo "错误：文件 $IMG 不存在"
        return 1
    fi

    # 获取最后一个分区的分区号
    local PART_NUM
    PART_NUM=$(parted -s "$IMG" print | awk '/^ / {print $1}' | tail -n 1)
    if [ -z "$PART_NUM" ]; then
        echo "错误：无法识别最后一个分区号"
        return 1
    fi
    echo "检测到最后一个分区号: $PART_NUM"

    # 计算当前大小和目标大小
    local CURRENT_SIZE_MB
    CURRENT_SIZE_MB=$(du -m "$IMG" | cut -f1)
    local TARGET_SIZE_MB=$((CURRENT_SIZE_MB + NEW_SIZE))

    # 检查大小限制
    if [ "$CURRENT_SIZE_MB" -gt "$MAX_SIZE" ]; then
        echo "错误：当前大小 ${CURRENT_SIZE_MB}MB + ${NEW_SIZE}MB = ${TARGET_SIZE_MB}MB"
        echo "超过最大限制 ${MAX_SIZE}MB (2.2GB)，操作已取消"
        return 1
    fi

    echo "开始扩容：当前大小 ${CURRENT_SIZE_MB}MB，将追加 ${NEW_SIZE}MB"

    # 执行扩容操作
    dd if=/dev/zero bs=1M count=$NEW_SIZE >> "$IMG" status=progress
    if [ $? -ne 0 ]; then
        echo "错误：追加空间失败"
        return 1
    fi

    # 重新扫描分区表
    partprobe -s "$IMG"

    # 调整分区大小（使用100%表示到磁盘末尾）
    echo "调整分区 $PART_NUM 大小..."
    parted -s "$IMG" resizepart $PART_NUM 100%
    if [ $? -ne 0 ]; then
        echo "错误：调整分区大小失败"
        return 1
    fi

    # 设置loop设备
    local LOOP_DEV
    LOOP_DEV=$(sudo losetup -f --show -P "$IMG")
    if [ -z "$LOOP_DEV" ]; then
        echo "错误：无法创建loop设备"
        return 1
    fi
    
    local PART_DEV="${LOOP_DEV}p${PART_NUM}"

    # 检查文件系统
    echo "检查文件系统..."
    sudo e2fsck -f -y "$PART_DEV"
    if [ $? -ne 0 ]; then
        echo "警告：文件系统检查发现问题，但继续操作"
    fi

    # 调整文件系统大小
    echo "调整文件系统大小..."
    sudo resize2fs "$PART_DEV"
    if [ $? -ne 0 ]; then
        echo "错误：调整文件系统大小失败"
        sudo losetup -d "$LOOP_DEV"
        return 1
    fi

    # 清理资源
    sudo losetup -d "$LOOP_DEV"

    # 验证结果
    echo "扩容操作完成！验证结果："
    parted -s "$IMG" unit MB print | grep -E "Disk|Number"

    return 0
}

download_mod_data() {
	mkdir -p $1
	TAG=$(curl -s https://api.github.com/repos/AveyondFly/console_mod_res/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d '"' -f4)
	curl -s https://api.github.com/repos/AveyondFly/console_mod_res/releases/latest | \
	grep "browser_download_url" | \
	grep -v "source" | \
	sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/' | \
	xargs -n 1 -I {} wget -P $1 {}
}

filename=$1
source_img_name=${filename%.*}
#source_img_file="${source_img_name}.img.gz"
#target_img_name="JELOS-RGB30.aarch64-20240314-MOU"
mount_point="target"
mount_point_storage="storage"
common_dev="update_files"
system_root="SYSTEM-root"
download_data="data_files"

if [ -z "$1" ]  
then  
    echo "Should run with img as: sudo ./build_mod_img.sh IMG_TO_BE_MOD.img"
    exit 1
fi

# Check if root
if [ "$UID" -ne 0 ]; then
    echo "The script should be run with sudo!!!" >&2
    exit 1
fi

echo "Welcome to build Rocknix mod IMG!"

resize_img $filename 1024 2400 ext4

echo "Creating mount point"
mkdir -p ${mount_point}
mkdir -p ${mount_point_storage}
echo "Mounting Rocknix boot partition"
loop_device=$(losetup -f)
losetup -P $loop_device $filename
mount ${loop_device}p1 ${mount_point}
mount ${loop_device}p2 ${mount_point_storage}

echo "Decompressing SYSTEM image"
rm -rf ${system_root}
unsquashfs -d ${system_root} ${mount_point}/SYSTEM

# Add mod files
cp -rf ./sys_root_files/* ${system_root}/
cp -rf ./mod_files/* ${system_root}/
mkdir -p ${mount_point_storage}/data/
cp ${common_dev}/update.sh  ${mount_point_storage}/data/
cp ${common_dev}/functions ${mount_point_storage}/data/
if [ ! -d ${download_data} ]; then
	download_mod_data ${download_data}
fi
cp ${download_data}/* ${mount_point_storage}/data/

# Update issue file
echo "Update issue file" 
sed -i '/mod_by_kk/!s/nightly/nightly_mod_by_kk/g' ${system_root}/etc/issue
sed -i '/mod_by_kk/!s/official/official_mod_by_kk/g' ${system_root}/etc/issue
sed -i '/mod_by_kk/!s/community/ninghtly_mod_by_kk/g' ${system_root}/etc/issue
sed -i '/mod_by_kk/!s/nightly/nightly_mod_by_kk/g' ${system_root}/etc/motd
sed -i '/mod_by_kk/!s/official/official_mod_by_kk/g' ${system_root}/etc/motd
sed -i '/mod_by_kk/!s/nightly/nightly_mod_by_kk/g' ${system_root}/etc/os-release
sed -i '/mod_by_kk/!s/official/official_mod_by_kk/g' ${system_root}/etc/os-release

# 3326 related update
cp ${common_dev}/gamecontrollerdb.txt_rgb10x  ${system_root}/usr/config/SDL-GameControllerDB/gamecontrollerdb.txt
cp ${common_dev}/001-device_config_rgb20s ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB20S/001-device_config
cp ${common_dev}/050-modifiers_20s ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB20S/050-modifiers

sed -i 's/^\(DEVICE_FUNC_KEYA_MODIFIER=\).*/\1"BTN_SELECT"/' ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB10X/050-modifiers
sed -i 's/^\(DEVICE_FUNC_KEYA_MODIFIER=\).*/\1"BTN_THUMBR"/' ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB10/050-modifiers
sed -i 's/^\(DEVICE_FUNC_KEYB_MODIFIER=\).*/\1"BTN_THUMBL"/' ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB10/050-modifiers

echo "update N64"
cp ${common_dev}/n64_default.ini ${system_root}/usr/local/share/mupen64plus/default.ini
cp ${common_dev}/mupen64plus.cfg.mymini ${system_root}/usr/local/share/mupen64plus/

# Run depmod for base overlay modules
MODVER=$(basename $(ls -d ${system_root}/usr/lib/kernel-overlays/base/lib/modules/*))
cp ${common_dev}/rk915.ko ${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/kernel/drivers/net/wireless/
cp ${common_dev}/rocknix-singleadc-joypad.ko ${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/rocknix-joypad/
find ${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/ -name *.ko | \
  sed -e "s,${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/,," \
    > ${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/modules.order
depmod -b ${system_root}/usr/lib/kernel-overlays/base -a -e -F "${common_dev}/linux-${MODVER}/System.map" ${MODVER} 2>&1

cp ${common_dev}/rk915_fw.bin ${system_root}/usr/lib/kernel-overlays/base/lib/firmware/
cp ${common_dev}/rk915_patch.bin ${system_root}/usr/lib/kernel-overlays/base/lib/firmware/

#read -p "Press any key to continue..."

echo "Compressing SYSTEM image"
mksquashfs ${system_root} SYSTEM -comp lzo -Xalgorithm lzo1x_999 -Xcompression-level 9 -b 524288 -no-xattrs
rm ${mount_point}/SYSTEM
mv SYSTEM ${mount_point}/SYSTEM
touch ${mount_point}/resize_storage_10G
touch ${mount_point}/ms_unsupported

# 3326 Related mode
rm -rf ${mount_point}/*.dtb
cp -rf ${common_dev}/3326/*  ${mount_point}/
rm -rf ${mount_point}/boot*.ini

# update uuid
cp ${mount_point}/extlinux/extlinux.conf ${mount_point}/extlinux/extlinux.conf_bak
uuid=`blkid -s UUID -o value ${loop_device}p1`
suuid=`blkid -s UUID -o value ${loop_device}p2`
sed -i "s|boot=\\\${partition_boot}|boot=UUID=$uuid|g" ${mount_point}/extlinux/extlinux.conf
sed -i "s|disk=\\\${partition_storage}|disk=UUID=$suuid|g" ${mount_point}/extlinux/extlinux.conf
sync

echo "Unmounting rocknix data partition"
umount ${loop_device}p1
umount ${loop_device}p2
losetup -d ${loop_device}

rm -rf ${system_root}
rm -rf ${mount_point}
rm -rf ${mount_point_storage}
