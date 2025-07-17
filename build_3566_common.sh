#! /bin/bash

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

    # 获取分区表类型
    local PART_TABLE
    PART_TABLE=$(parted -s "$IMG" print | grep "Partition Table" | awk '{print $3}')
    if [ -z "$PART_TABLE" ]; then
        echo "错误：无法识别分区表类型"
        return 1
    fi
    echo "检测到分区表类型: $PART_TABLE"

    # 获取最后一个分区的分区号
    local PART_NUM
    if [ "$PART_TABLE" = "gpt" ]; then
        # GPT 分区表使用 sgdisk
        PART_NUM=$(sgdisk -p "$IMG" | awk '/^   / {print $1}' | tail -n 1)
    else
        # MBR 分区表使用 parted
        PART_NUM=$(parted -s "$IMG" print | awk '/^ / {print $1}' | tail -n 1)
    fi
    
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

    # 执行扩容操作（GPT兼容方式）
    truncate -s +${NEW_SIZE}M "$IMG" 2>/dev/null || {
        # 如果truncate失败，使用dd作为后备方案
        dd if=/dev/zero bs=1M count=$NEW_SIZE >> "$IMG" status=progress
    }
    
    if [ $? -ne 0 ]; then
        echo "错误：追加空间失败"
        return 1
    fi

    # GPT分区表需要修复备份表
    if [ "$PART_TABLE" = "gpt" ]; then
        echo "修复GPT备份表..."
        sgdisk -e "$IMG" || {
            echo "警告：GPT备份表修复失败，继续操作"
        }
    fi

    # 重新扫描分区表
    partprobe -s "$IMG"

    # 调整分区大小（根据分区表类型使用不同方法）
    echo "调整分区 $PART_NUM 大小..."
    if [ "$PART_TABLE" = "gpt" ]; then
        # 获取分区信息
        local START_SECTOR ORIG_GUID
        START_SECTOR=$(sgdisk -i $PART_NUM "$IMG" | grep "First sector" | awk '{print $3}')
        ORIG_GUID=$(sgdisk -i $PART_NUM "$IMG" | grep "Partition GUID code" | awk '{print $4}')
        local NEW_END_SECTOR=$(( $(sgdisk -E "$IMG") - 1 ))  # 获取最后一个可用扇区
        
        # 调整分区大小（删除并重新创建）
        sgdisk -d $PART_NUM "$IMG" || {
            echo "错误：删除分区失败"
            return 1
        }
        sgdisk -n $PART_NUM:$START_SECTOR:$NEW_END_SECTOR "$IMG" || {
            echo "错误：创建分区失败"
            return 1
        }
        sgdisk -t $PART_NUM:$ORIG_GUID "$IMG" || {
            echo "警告：恢复分区GUID失败"
        }
    else
        # MBR分区表使用parted
        parted -s "$IMG" resizepart $PART_NUM 100% || {
            echo "错误：调整分区大小失败"
            return 1
        }
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
    local fsck_result=$?
    if [ $fsck_result -gt 1 ]; then  # 严重错误 (>1)
        echo "错误：文件系统检查发现严重问题 (代码 $fsck_result)"
        sudo losetup -d "$LOOP_DEV"
        return 1
    elif [ $fsck_result -eq 1 ]; then  # 轻微错误 (=1)
        echo "警告：文件系统检查发现并修复了问题"
    fi

    # 调整文件系统大小
    echo "调整文件系统大小..."
    if [ "$FS_TYPE" = "xfs" ]; then
        sudo mount "$PART_DEV" /mnt
        sudo xfs_growfs /mnt
        sudo umount /mnt
    else
        sudo resize2fs "$PART_DEV"
    fi
    
    if [ $? -ne 0 ]; then
        echo "错误：调整文件系统大小失败"
        sudo losetup -d "$LOOP_DEV"
        return 1
    fi

    # 清理资源
    sudo losetup -d "$LOOP_DEV"

    # 验证结果
    echo "扩容操作完成！验证结果："
    if [ "$PART_TABLE" = "gpt" ]; then
        gdisk -l "$IMG" | grep -A $((PART_NUM+1)) "Number"
    else
        parted -s "$IMG" unit MB print | grep -E "Disk|Number"
    fi
    
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

get_latest_version() {
	device=$1
	# 获取所有 Release 数据
	releases=$(curl -s https://api.github.com/repos/ROCKNIX/distribution-nightly/releases)
	# 提取第一个 Release（即最新的）
	latest_release=$(echo "$releases" | jq -r '.[0]')
	# 提取所有资产的下载链接
	assets=$(echo "$latest_release" | jq -r '.assets[].browser_download_url')
	# 过滤出 RK3566.img.gz 的链接（排除 .sha256 文件）
	download_url=$(echo "$assets" | grep "RK3566" | grep "${device}\.img\.gz$")
	# 输出结果
	echo "最新 RK3566.img.gz 文件的下载地址是: $download_url"
}

copy_minimal_files() {
	local file_list=(
	    "cheats.tar.gz"
	    "datas.zip"
	    "jdk.zip"
#	    "bezels_640x480.zip"
#	    "bezels_720x720.zip"
	)

	mkdir -p ${mount_point}/update/
	for file in "${file_list[@]}"; do
		cp ${download_data}/$file ${mount_point}/update/
	done
	cp ${download_data}/mod_cores.zip ${mount_point}/update/
	cp ${download_data}/mod_cores_genesis_plus_gx_EX_libretro.so.zip ${mount_point}/update/
}

filename=$1
source_img_name=${filename%.*}
#source_img_file="${source_img_name}.img.gz"
mount_point="target"
mount_point_storage="storage"
common_dev="update_files"
system_root="SYSTEM-root"
download_data="data_files"


# Check if root
if [ "$UID" -ne 0 ]; then
    echo "The script should be run with sudo!!!" >&2
    exit 1
fi

if [ -z "$filename" ] || ! [[ "$filename" =~ ^.*\.img$ ]]; then
    if [[ "$filename" == *x55* ]]; then
        get_latest_version "x55"
    else
        get_latest_version "Generic"
    fi
    filenamegz=$(basename "$download_url")
    wget ${download_url} -O ${filenamegz} | exit 1
    echo "Decompressing Rocknix image"
    gzip -d ${filenamegz} | exit 1
    filename="${filenamegz%.gz}"
fi

echo "Welcome to build Rocknix mod IMG!"

if [[ ! "$1" == mini* ]]; then
	resize_img $filename 1024 2400 ext4
fi

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
cp ${system_root}/usr/config/drastic/lib/libSDL2-2.0.so.0_3566 ${system_root}/usr/config/drastic/lib/libSDL2-2.0.so.0
rm -rf ${system_root}/usr/config/drastic/lib/libSDL2-2.0.so.0_3566
cp ${common_dev}/gamecontrollerdb.txt_rgb10x  ${system_root}/usr/config/SDL-GameControllerDB/gamecontrollerdb.txt

mkdir -p ${mount_point_storage}/data/
cp ${common_dev}/update.sh  ${mount_point_storage}/data/
cp ${common_dev}/functions ${mount_point_storage}/data/
if [ ! -d ${download_data} ]; then
	download_mod_data ${download_data}
fi

if [[ "$1" == mini* ]]; then
	copy_minimal_files
else
	cp ${download_data}/* ${mount_point_storage}/data/
fi

# Update issue file
echo "Update issue file" 
sed -i '/mod_by_kk/!s/nightly/nightly_mod_by_kk/g' ${system_root}/etc/issue
sed -i '/mod_by_kk/!s/official/official_mod_by_kk/g' ${system_root}/etc/issue
sed -i '/mod_by_kk/!s/nightly/nightly_mod_by_kk/g' ${system_root}/etc/motd
sed -i '/mod_by_kk/!s/official/official_mod_by_kk/g' ${system_root}/etc/motd
sed -i '/mod_by_kk/!s/nightly/nightly_mod_by_kk/g' ${system_root}/etc/os-release
sed -i '/mod_by_kk/!s/official/official_mod_by_kk/g' ${system_root}/etc/os-release

cp -rf ${common_dev}/3366/*  ${mount_point}/device_trees/

#read -p "Press any key to continue..."

echo "Compressing SYSTEM image"
mksquashfs ${system_root} SYSTEM -comp lzo -Xalgorithm lzo1x_999 -Xcompression-level 9 -b 524288 -no-xattrs
rm ${mount_point}/SYSTEM
mv SYSTEM ${mount_point}/SYSTEM
touch ${mount_point}/resize_storage_10G
touch ${mount_point}/ms_unsupported

sync

echo "Unmounting rocknix data partition"
umount ${loop_device}p1
umount ${loop_device}p2
losetup -d ${loop_device}

rm -rf ${system_root}
rm -rf ${mount_point}
rm -rf ${mount_point_storage}

if [ "$1" = "mini*" ]; then
  new_filename="${filename/.img/-mini-mod.img}"
else
  new_filename="${filename/.img/-mod.img}"
fi

mv ${filename} ${new_filename}
gzip ${new_filename}
