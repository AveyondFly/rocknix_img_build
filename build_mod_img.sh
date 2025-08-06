#!/bin/bash

mount_point="target"
mount_point_storage="storage"
common_dev="update_files"
system_root="SYSTEM-root"
download_data="data_files"
bakcup_repo="lcdyk0517/rocknix.sync"

DEVICE="$1"
RELEASE_VERSION="$2"
IS_MINI=false
IS_X55=false
IS_3566=false
IS_3326=false
IS_H700=false
IS_STABLE=false
IS_BACKUPREPO=false
IS_EMMC=false

if [[ "$DEVICE" == *mini* ]]; then IS_MINI=true; fi
if [[ "$DEVICE" == *x55* ]]; then IS_X55=true; fi
if [[ "$DEVICE" == 3566* || "$DEVICE" == x55* ]]; then IS_3566=true; fi
if [[ "$DEVICE" == *emmc* ]] ; then IS_EMMC=true; fi
if [[ "$DEVICE" == 3326* ]]; then IS_3326=true; fi
if [[ "$DEVICE" == h700* ]]; then IS_H700=true; fi
if [[ "$DEVICE" == *stable ]]; then IS_STABLE=true; fi

if [ "$UID" -ne 0 ]; then
  echo -e "\033[1;31m❌ 请使用 sudo 执行\033[0m"
  exit 1
fi

if [[ -n "$RELEASE_VERSION" ]]; then
  echo -e "\033[1;32m✅ 启用指定版本（备用仓库逻辑）：$RELEASE_VERSION\033[0m"
  IS_BACKUPREPO=true
fi

resize_img_gpt() {
    local IMG="$1"
    local NEW_SIZE="$2"
    local MAX_SIZE="${3:-2200}"  # 默认最大2.2GB
    local FS_TYPE="${4:-ext4}"   # 默认ext4文件系统

    echo "📝 开始处理镜像文件：$IMG"

    if [ ! -f "$IMG" ]; then
        echo "❌ 错误：文件 $IMG 不存在"
        return 1
    fi

    echo "🔍 检测分区表类型..."
    local PART_TABLE
    PART_TABLE=$(parted -s "$IMG" print | grep "Partition Table" | awk '{print $3}')
    if [ -z "$PART_TABLE" ]; then
        echo "❌ 错误：无法识别分区表类型"
        return 1
    fi
    echo "📦 分区表类型：$PART_TABLE"

    local PART_NUM
    if [ "$PART_TABLE" = "gpt" ]; then
        PART_NUM=$(sgdisk -p "$IMG" | awk '/^   / {print $1}' | tail -n 1)
    else
        PART_NUM=$(parted -s "$IMG" print | awk '/^ / {print $1}' | tail -n 1)
    fi
    if [ -z "$PART_NUM" ]; then
        echo "❌ 错误：无法识别最后一个分区号"
        return 1
    fi
    echo "📍 最后一个分区号：$PART_NUM"

    local CURRENT_SIZE_MB
    CURRENT_SIZE_MB=$(du -m "$IMG" | cut -f1)
    local TARGET_SIZE_MB=$((CURRENT_SIZE_MB + NEW_SIZE))

    if [ "$CURRENT_SIZE_MB" -gt "$MAX_SIZE" ]; then
        echo "🚫 当前大小 ${CURRENT_SIZE_MB}MB + ${NEW_SIZE}MB = ${TARGET_SIZE_MB}MB 超过最大限制 ${MAX_SIZE}MB"
        return 1
    fi

    echo "➕ 开始扩容：当前大小 ${CURRENT_SIZE_MB}MB，追加 ${NEW_SIZE}MB"

    truncate -s +${NEW_SIZE}M "$IMG" 2>/dev/null || {
        echo "📼 truncate 失败，使用 dd 追加数据"
        dd if=/dev/zero bs=1M count=$NEW_SIZE >> "$IMG" status=progress
    }
    if [ $? -ne 0 ]; then
        echo "❌ 错误：追加空间失败"
        return 1
    fi

    if [ "$PART_TABLE" = "gpt" ]; then
        echo "🩹 修复 GPT 备份分区表..."
        sgdisk -e "$IMG" || echo "⚠️ GPT 修复失败，继续执行"
    fi

    echo "🔁 重新扫描分区表..."
    partprobe -s "$IMG"

    echo "📏 调整分区 $PART_NUM 大小..."
    if [ "$PART_TABLE" = "gpt" ]; then
        local START_SECTOR ORIG_GUID
        START_SECTOR=$(sgdisk -i $PART_NUM "$IMG" | grep "First sector" | awk '{print $3}')
        ORIG_GUID=$(sgdisk -i $PART_NUM "$IMG" | grep "Partition GUID code" | awk '{print $4}')
        local NEW_END_SECTOR=$(( $(sgdisk -E "$IMG") - 1 ))

        echo "🧹 删除旧分区..."
        sgdisk -d $PART_NUM "$IMG" || { echo "❌ 删除分区失败"; return 1; }

        echo "🧱 创建新分区：从 $START_SECTOR 到 $NEW_END_SECTOR"
        sgdisk -n $PART_NUM:$START_SECTOR:$NEW_END_SECTOR "$IMG" || { echo "❌ 创建分区失败"; return 1; }

        echo "🔁 还原 GUID 类型..."
        sgdisk -t $PART_NUM:$ORIG_GUID "$IMG" || echo "⚠️ 无法还原分区 GUID"
    else
        parted -s "$IMG" resizepart $PART_NUM 100% || { echo "❌ 分区调整失败"; return 1; }
    fi

    echo "🔗 设置 loop 设备..."
    local LOOP_DEV
    LOOP_DEV=$(sudo losetup -f --show -P "$IMG")
    if [ -z "$LOOP_DEV" ]; then
        echo "❌ 错误：无法设置 loop 设备"
        return 1
    fi
    local PART_DEV="${LOOP_DEV}p${PART_NUM}"

    echo "🧪 检查文件系统..."
    sudo e2fsck -f -y "$PART_DEV"
    local fsck_result=$?
    if [ $fsck_result -gt 1 ]; then
        echo "❌ 错误：文件系统检查失败 (代码 $fsck_result)"
        sudo losetup -d "$LOOP_DEV"
        return 1
    elif [ $fsck_result -eq 1 ]; then
        echo "⚠️ 警告：文件系统已修复"
    fi

    echo "📐 扩展文件系统大小..."
    if [ "$FS_TYPE" = "xfs" ]; then
        sudo mount "$PART_DEV" /mnt
        sudo xfs_growfs /mnt
        sudo umount /mnt
    else
        sudo resize2fs "$PART_DEV"
    fi
    if [ $? -ne 0 ]; then
        echo "❌ 错误：resize2fs 执行失败"
        sudo losetup -d "$LOOP_DEV"
        return 1
    fi

    echo "🧹 清理 loop 设备..."
    sudo losetup -d "$LOOP_DEV"

    echo "✅ 扩容完成！验证分区信息："
    if [ "$PART_TABLE" = "gpt" ]; then
        gdisk -l "$IMG" | grep -A $((PART_NUM+1)) "Number"
    else
        parted -s "$IMG" unit MB print | grep -E "Disk|Number"
    fi

    return 0
}

resize_img_mbr() {
    local IMG="$1"
    local NEW_SIZE="$2"
    local MAX_SIZE="${3:-2200}"
    local FS_TYPE="${4:-ext4}"

    if [ ! -f "$IMG" ]; then
        echo -e "\033[1;31m❌ 错误：文件 $IMG 不存在\033[0m"
        return 1
    fi

    local PART_NUM
    PART_NUM=$(parted -s "$IMG" print | awk '/^ / {print $1}' | tail -n 1)
    if [ -z "$PART_NUM" ]; then
        echo -e "\033[1;31m❌ 错误：无法识别最后一个分区号\033[0m"
        return 1
    fi
    echo -e "\033[1;34m🔍 检测到最后一个分区号: $PART_NUM\033[0m"

    local CURRENT_SIZE_MB
    CURRENT_SIZE_MB=$(du -m "$IMG" | cut -f1)
    local TARGET_SIZE_MB=$((CURRENT_SIZE_MB + NEW_SIZE))

    if [ "$CURRENT_SIZE_MB" -gt "$MAX_SIZE" ]; then
        echo -e "\033[1;31m❌ 错误：当前大小 ${CURRENT_SIZE_MB}MB + ${NEW_SIZE}MB = ${TARGET_SIZE_MB}MB\033[0m"
        echo -e "\033[1;33m🚫 超过最大限制 ${MAX_SIZE}MB，操作已取消\033[0m"
        return 1
    fi

    echo -e "\033[1;36m📦 开始扩容镜像...\033[0m"
    dd if=/dev/zero bs=1M count=$NEW_SIZE >> "$IMG" status=progress || return 1

    partprobe -s "$IMG"

    echo -e "\033[1;34m📏 调整分区大小...\033[0m"
    parted -s "$IMG" resizepart $PART_NUM 100% || return 1

    local LOOP_DEV
    LOOP_DEV=$(sudo losetup -f --show -P "$IMG") || return 1
    local PART_DEV="${LOOP_DEV}p${PART_NUM}"

    echo -e "\033[1;34m🔍 检查文件系统...\033[0m"
    sudo e2fsck -f -y "$PART_DEV" || echo -e "\033[1;33m⚠️ 警告：文件系统检查异常，继续\033[0m"

    echo -e "\033[1;34m🧰 调整文件系统大小...\033[0m"
    sudo resize2fs "$PART_DEV" || {
        echo -e "\033[1;31m❌ 错误：resize2fs 执行失败\033[0m"
        sudo losetup -d "$LOOP_DEV"
        return 1
    }

    sudo losetup -d "$LOOP_DEV"

    echo -e "\033[1;32m✅ 扩容完成，打印分区信息：\033[0m"
    parted -s "$IMG" unit MB print | grep -E "Disk|Number"

    return 0
}

resize_img() {
  if $IS_3566; then
    resize_img_gpt "$@"
  else
    resize_img_mbr "$@"
  fi
}

download_mod_data() {
    local target_dir="$1"
    mkdir -p "$target_dir"

    # 环境变量兼容处理
    if [[ -n "$GH_PAT" ]]; then
        AUTH_HEADER="Authorization: token $GH_PAT"
        echo -e "\033[1;36m🔐 使用 GH_PAT 提高 API 限额\033[0m"
    else
        echo -e "\033[1;33m⚠️ 未设置 GH_PAT，将使用匿名方式（每小时最多60次）\033[0m"
    fi

    local response=$(curl -sSL -H "Accept: application/vnd.github+json" \
        ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
        https://api.github.com/repos/AveyondFly/console_mod_res/releases/latest)

    if [[ -z "$response" || "$response" == "null" ]]; then
        echo -e "\033[1;31m❌ 获取 mod release 数据失败\033[0m"
        return 1
    fi

    if echo "$response" | grep -q "API rate limit exceeded"; then
        echo -e "\033[1;31m⛔ GitHub API 访问频率受限，建议设置 GITHUB_TOKEN\033[0m"
        return 1
    fi

    local urls=$(echo "$response" | jq -r '.assets[].browser_download_url' | grep -v "source")

    if [[ -z "$urls" ]]; then
        echo -e "\033[1;31m❌ 未找到任何下载链接\033[0m"
        return 1
    fi

    echo -e "\033[1;36m📥 开始下载 mod 数据...\033[0m"
    echo "$urls" | xargs -I {} wget --show-progress --progress=bar:force:noscroll -P "$target_dir" {}

    echo -e "\033[1;32m✅ 下载完成，mod 数据保存到：$target_dir\033[0m"
    return 0
}

get_latest_version() {
    case "$DEVICE" in
        3326*) PATTERN="RK3326.*b.img.gz$" ;;
        x55*)  PATTERN="RK3566.*x55.img.gz$" ;;
        3566*) PATTERN="RK3566.*Generic.img.gz$" ;;
        h700*) PATTERN="H700.*img.gz$" ;;
        *) echo -e "\033[1;31m❌ 不支持的设备类型：$DEVICE\033[0m" && exit 1 ;;
    esac

    # 仓库地址判断
    if [[ "$IS_STABLE" == "true" ]]; then
        REPO="ROCKNIX/distribution"
        VERSION_TYPE="🟢 stable"
    else
        REPO="ROCKNIX/distribution-nightly"
        VERSION_TYPE="🔵 nightly"
    fi

    if [[ "$IS_BACKUPREPO" == "true" ]]; then
        REPO="${bakcup_repo}"
        VERSION_TYPE="📦 备份镜像"
    fi

    echo -e "\033[1;36m🔍 当前拉取源：$VERSION_TYPE ($REPO)\033[0m"

    # 环境变量兼容处理
    if [[ -n "$GH_PAT" ]]; then
        AUTH_HEADER="Authorization: token $GH_PAT"
        echo -e "\033[1;36m🔐 使用 GH_PAT 提高 API 限额\033[0m"
    else
        echo -e "\033[1;33m⚠️ 未设置 GH_PAT，将使用匿名方式（每小时最多60次）\033[0m"
    fi

    for i in {1..30}; do
        echo -e "\033[1;34m🔁 获取镜像（尝试 $i/30）...\033[0m"
        
        if [[ -n "$RELEASE_VERSION" ]]; then
            echo -e "\033[1;34m📦 启用指定版本：$RELEASE_VERSION\033[0m"
            api_url="https://api.github.com/repos/$REPO/releases/tags/$RELEASE_VERSION"
        else
            api_url="https://api.github.com/repos/$REPO/releases"
        fi

        response=$(curl -sSL -H "Accept: application/vnd.github+json" \
            ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
            "$api_url")

        # 检查 API 是否限制
        if echo "$response" | grep -q "API rate limit exceeded"; then
            echo -e "\033[1;31m⛔ GitHub API 访问频率受限，终止执行！\033[0m"
            return 1
        fi

        if echo "$response" | grep -q "Not Found"; then
            echo -e "\033[1;31m❌ 找不到指定版本：$RELEASE_VERSION\033[0m"
            return 1
        fi


        # 尝试 jq 解析
        if [[ -n "$RELEASE_VERSION" ]]; then
            assets=$(echo "$response" | jq -r '.assets[].browser_download_url')
        else
            assets=$(echo "$response" | jq -r '[.[] | select(.assets != null)][0].assets[].browser_download_url' 2>/dev/null)
        fi
        if [[ $? -ne 0 || -z "$assets" ]]; then
            echo -e "\033[1;33m⚠️ 无法解析 GitHub 返回内容（可能是网络问题或格式错误），30 秒后重试...\033[0m"
            sleep 30
            continue
        fi

        download_url=$(echo "$assets" | grep -iE "$PATTERN")

        if [[ -n "$download_url" ]]; then
            echo -e "\033[1;32m✅ 成功找到下载链接：$download_url\033[0m"
            return 0
        fi

        echo -e "\033[1;33m⚠️ 暂未找到符合 $DEVICE 的镜像，30 秒后重试...\033[0m"
        sleep 30
    done

    echo -e "\033[1;31m❌ 连续尝试 30 次后仍未找到镜像，终止执行\033[0m"
    return 1
}


copy_minimal_files() {
    echo -e "\033[1;36m📦 根据设备类型选择 minimal 文件...\033[0m"

    if $IS_3566 && ! $IS_X55; then
        echo "🔧 当前设备为 3566，选择适配文件列表"
        file_list=(
            "datas.zip"
            "jdk.zip"
        )
    elif $IS_X55; then
        echo "🔧 当前设备为 X55，仅使用最小文件"
        file_list=(
            "bezels_640x480.zip"
        )
    else
        echo "🔧 当前设备为 3326 或 H700，使用完整文件列表"
        file_list=(
            "cheats.tar.gz"
            "datas.zip"
            "jdk.zip"
            "bezels_480x320.zip"
            "bezels_640x480.zip"
            "bezels_720x720.zip"
        )
    fi

    echo -e "\033[1;36m📁 拷贝必要文件到 ${mount_point}/update/ ...\033[0m"
    mkdir -p "${mount_point}/update/"

    for file in "${file_list[@]}"; do
        if [[ -f "${download_data}/$file" ]]; then
            echo -e "\033[1;34m➡️ 拷贝：$file\033[0m"
            cp "${download_data}/$file" "${mount_point}/update/"
        else
            echo -e "\033[1;31m⚠️ 缺少文件：$file，跳过\033[0m"
        fi
    done

    # 永远附加这两个核心 mod 文件
    cp "${download_data}/mod_cores.zip" "${mount_point}/update/"
    cp "${download_data}/mod_cores_genesis_plus_gx_EX_libretro.so.zip" "${mount_point}/update/"
}
# ------------------------
# 平台专属复制函数
# ------------------------
copy_3566() {
  echo "📂 [3566] 复制 mod 文件"
  cp -rf ./sys_root_files/* ${system_root}/
  cp -rf ./mod_files/* ${system_root}/
  cp ${system_root}/usr/config/drastic/lib/libSDL2-2.0.so.0_3566 ${system_root}/usr/config/drastic/lib/libSDL2-2.0.so.0
  rm -rf ${system_root}/usr/config/drastic/lib/libSDL2-2.0.so.0_3566
  mkdir -p ${mount_point_storage}/data/
  cp ${common_dev}/update.sh  ${mount_point_storage}/data/
  cp ${common_dev}/functions ${mount_point_storage}/data/
}

copy_3326() {
  echo "📂 [3326] 复制 mod 文件"
  cp -rf ./sys_root_files/* ${system_root}/
  chmod 775 -R ./mod_files/usr/lib/autostart/
  cp -rf ./mod_files/* ${system_root}/
  mkdir -p ${mount_point_storage}/data/
  cp ${common_dev}/update.sh  ${mount_point_storage}/data/
  cp ${common_dev}/functions ${mount_point_storage}/data/
  cp ${common_dev}/gamecontrollerdb.txt_rgb10x  ${system_root}/usr/config/SDL-GameControllerDB/gamecontrollerdb.txt
  cp ${common_dev}/001-device_config_rgb20s ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB20S/001-device_config
  cp ${common_dev}/050-modifiers_20s ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB20S/050-modifiers

  sed -i 's/^\(DEVICE_FUNC_KEYA_MODIFIER=\).*/\1"BTN_SELECT"/' ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB10X/050-modifiers
  sed -i 's/^\(DEVICE_FUNC_KEYA_MODIFIER=\).*/\1"BTN_THUMBR"/' ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB10/050-modifiers
  sed -i 's/^\(DEVICE_FUNC_KEYB_MODIFIER=\).*/\1"BTN_THUMBL"/' ${system_root}/usr/lib/autostart/quirks/devices/Powkiddy\ RGB10/050-modifiers

  echo "update N64"
  cp ${common_dev}/n64_default.ini ${system_root}/usr/local/share/mupen64plus/default.ini
  cp ${common_dev}/mupen64plus.cfg.mymini ${system_root}/usr/local/share/mupen64plus/
  MODVER=$(basename $(ls -d ${system_root}/usr/lib/kernel-overlays/base/lib/modules/*))
  if [[ ! -d "${common_dev}/linux-${MODVER}" ]]; then
    echo -e "\033[1;31m❌ 缺少必要的内核模块目录：${common_dev}/linux-${MODVER}\033[0m"
    exit 1
  fi
  cp ${common_dev}/linux-${MODVER}/KERNEL ${mount_point}/
  cp ${common_dev}/linux-${MODVER}/rk915.ko ${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/kernel/drivers/net/wireless/
  cp ${common_dev}/linux-${MODVER}/rocknix-singleadc-joypad.ko ${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/rocknix-joypad/
  find ${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/ -name *.ko | \
    sed -e "s,${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/,," \
      > ${system_root}/usr/lib/kernel-overlays/base/lib/modules/${MODVER}/modules.order
  depmod -b ${system_root}/usr/lib/kernel-overlays/base -a -e -F "${common_dev}/linux-${MODVER}/System.map" ${MODVER} 2>&1

  cp ${common_dev}/rk915_fw.bin ${system_root}/usr/lib/kernel-overlays/base/lib/firmware/
  cp ${common_dev}/rk915_patch.bin ${system_root}/usr/lib/kernel-overlays/base/lib/firmware/

    if [[ "$IS_EMMC" != "true" ]]; then
        # echo "🔄 非 eMMC 模式，复制 3326 配置文件..."
        # cp -rf ${common_dev}/3326/*      ${mount_point}/
        # cp -rf ${common_dev}/3326_ini/*  ${mount_point}/
        # rm -rf ${mount_point}/extlinux/
        echo "🔄 非 eMMC 模式，复制 3326 自动配置文件..."
        cp -rf ${common_dev}/3326/*      ${mount_point}/
        cp -rf ${common_dev}/3326_ini/*  ${mount_point}/
        cp -rf ${common_dev}/3326_auto/*  ${mount_point}/
        rm -rf ${mount_point}/extlinux/
        rm -rf ${mount_point}/boot.scr
        rm -rf ${mount_point}/*.ini
        rm -rf ${mount_point}/*.py
        rm -rf ${mount_point}/my.ico
        rm -rf ${mount_point}/package.cmd
        mv -f ${mount_point}/readme.txt  ${mount_point}/"Mac User Please Readme.txt"
    else
        echo "🔄 eMMC 模式，复制 3326 配置文件..."
        rm -rf ${mount_point}/*.dtb
        cp -rf ${common_dev}/3326/*  ${mount_point}/
        rm -rf ${mount_point}/boot*.ini
        
    fi
}

copy_h700() {
  echo "📂 [H700] 复制 mod 文件"
  cp -rf ./sys_root_files/* ${system_root}/
  EXCLUDE_FILES=("mcu_led" "mcu_led_ctrl.sh")
  EXCLUDE_DIRS=("quirks/devices/")

  SOURCE_DIR="./mod_files"
  TARGET_DIR="${system_root}"  # 替换为你的目标根目录

  # 遍历 SOURCE_DIR 下的所有文件（相对于 SOURCE_DIR）
  find "$SOURCE_DIR" -type f | while read -r filepath; do
      relative_path="${filepath#$SOURCE_DIR/}"  # 获取相对路径
      skip=false

      #### [1] 检查是否在排除目录中 ####
      for dir in "${EXCLUDE_DIRS[@]}"; do
          if [[ "$relative_path" == "$dir"* ]]; then
              skip=true
              break
          fi
      done

      #### [2] 检查是否是排除的文件名 ####
      if [ "$skip" = false ]; then
          filename=$(basename "$relative_path")
          for exfile in "${EXCLUDE_FILES[@]}"; do
              if [[ "$filename" == "$exfile" ]]; then
                  skip=true
                  break
              fi
          done
      fi

      #### [3] 如果不在排除项中，则执行复制 ####
      if [ "$skip" = false ]; then
          target_path="$TARGET_DIR/$relative_path"
          mkdir -p "$(dirname "$target_path")"
          cp "$filepath" "$target_path"
      fi
  done
  mkdir -p ${mount_point_storage}/data/
  cp ${common_dev}/update.sh  ${mount_point_storage}/data/
  cp ${common_dev}/functions ${mount_point_storage}/data/
  cp ${common_dev}/H700/dtb_selector.exe ${mount_point}/

}

modify_system() {
    if $IS_3566; then
        echo -e "\033[1;36m🔁 应用 3566 平台补丁...\033[0m"
        copy_3566
    elif $IS_3326; then
        echo -e "\033[1;36m🔁 应用 3326 平台补丁...\033[0m"
        copy_3326
    elif $IS_H700; then
        echo -e "\033[1;36m🔁 应用 H700 平台补丁...\033[0m"
        copy_h700
    fi

    echo -e "\033[1;36m📝 修改 /etc/issue 等版本标识...\033[0m"
    sed -i '/mod_by_kk/!s/nightly/nightly_mod_by_kk/g' ${system_root}/etc/motd
    sed -i '/mod_by_kk/!s/official/official_mod_by_kk/g' ${system_root}/etc/motd
    sed -i '/mod_by_kk/!s/nightly/nightly_mod_by_kk/g' ${system_root}/etc/os-release
    sed -i '/mod_by_kk/!s/official/official_mod_by_kk/g' ${system_root}/etc/os-release
    sed -i '/^[[:space:]]*$/d' "${system_root}/etc/issue"
    {
        echo "... M o d: $(date '+%a %b %e %H:%M:%S CST %Y')"
        echo -e "... Mod by \e[1;32mkk\e[0m & \e[1;33mlcdyk\e[0m based on \e[1;34mG.R.H\e[0m"
    } >> "${system_root}/etc/issue"
}

finalize_image() {
    echo -e "\033[1;36m📦 重新打包 SYSTEM 镜像...\033[0m"
    mksquashfs ${system_root} SYSTEM -comp lzo -Xalgorithm lzo1x_999 -Xcompression-level 9 -b 524288 -no-xattrs

    echo -e "\033[1;33m🧹 清理旧 SYSTEM 镜像并替换...\033[0m"
    rm ${mount_point}/SYSTEM
    mv SYSTEM ${mount_point}/SYSTEM

    touch ${mount_point}/resize_storage_10G
    touch ${mount_point}/ms_unsupported

    if [[ "$IS_3326" == "true" && "$IS_EMMC" == "false" ]]; then
        uuid=$(blkid -s UUID -o value ${loop_device}p2)
        for file in ${mount_point}/config/*.ini; do
            [ -f "$file" ] && sed -i "s/disk=LABEL=STORAGE/disk=UUID=$uuid/" "$file"
        done
    elif [[ "$IS_EMMC" == "true" ]]; then
        cp ${mount_point}/extlinux/extlinux.conf ${mount_point}/extlinux/extlinux.conf_bak
        uuid=`blkid -s UUID -o value ${loop_device}p1`
        suuid=`blkid -s UUID -o value ${loop_device}p2`
        sed -i "s|boot=\\\${partition_boot}|boot=UUID=$uuid|g" ${mount_point}/extlinux/extlinux.conf
        sed -i "s|disk=\\\${partition_storage}|disk=UUID=$suuid|g" ${mount_point}/extlinux/extlinux.conf
    fi

    echo -e "\033[1;34m📤 卸载挂载的分区...\033[0m"
    sync
    umount ${loop_device}p1
    umount ${loop_device}p2
    losetup -d ${loop_device}

    if [[ "$IS_EMMC" == "true" ]]; then
        { dd if=$filename bs=32K count=1; cat ${common_dev}/emmc_3326_uboot.bin; } | dd of=$filename bs=4M conv=fsync,notrunc
    fi

    echo -e "\033[1;32m✅ 清理临时目录...\033[0m"
    rm -rf ${system_root} ${mount_point} ${mount_point_storage}
}
# ------------------------
# 🎯 主流程开始
# ------------------------
# 🧱 检查 DEVICE 参数
if [[ -z "$DEVICE" ]]; then
  echo -e "\033[1;31m❌ 参数不能为空，支持：3566,3566_mini,x55,x55_mini,3326,3326_mini,h700,h700_mini\033[0m"
  exit 1
fi

if [[ "$2" != *.img ]]; then
    # 🔍 获取镜像下载链接
    echo -e "\033[1;36m🔍 获取最新版本镜像...\033[0m"
    get_latest_version "$DEVICE"

    filenamegz=$(basename "$download_url")
    echo -e "\033[1;36m📦 下载镜像文件：$filenamegz\033[0m"
    wget --show-progress --progress=bar:force:noscroll "$download_url" -O "$filenamegz"

    echo -e "\033[1;36m📂 解压镜像...\033[0m"
    gzip -d "$filenamegz"
    filename="${filenamegz%.gz}"
else
    filename=$2
fi

echo -e "\033[1;34m📋 变量状态检查：\033[0m"
echo -e "  👉 DEVICE         = $DEVICE"
echo -e "  👉 RELEASE_VERSION= $RELEASE_VERSION"
echo -e "  👉 filename       = $filename"
echo -e "  👉 IS_MINI        = $IS_MINI"
echo -e "  👉 IS_X55         = $IS_X55"
echo -e "  👉 IS_3566        = $IS_3566"
echo -e "  👉 IS_3326        = $IS_3326"
echo -e "  👉 IS_H700        = $IS_H700"
echo -e "  👉 IS_EMMC        = $IS_EMMC"
echo -e "  👉 IS_STABLE      = $IS_STABLE"
echo -e "  👉 IS_BACKUPREPO  = $IS_BACKUPREPO"

echo -e "\033[1;33m✨ 开始魔改镜像：$filename\033[0m"

if ! $IS_MINI; then
  resize_img $filename 1524 2800 ext4
fi

echo -e "\033[1;34m📁 创建挂载点...\033[0m"
mkdir -p ${mount_point}
mkdir -p ${mount_point_storage}

echo -e "\033[1;34m🔗 挂载系统分区...\033[0m"
loop_device=$(losetup -f)
losetup -P $loop_device $filename
mount ${loop_device}p1 ${mount_point}
mount ${loop_device}p2 ${mount_point_storage}

# ✅ 解包 SYSTEM 文件前确保存在
if [ ! -f "${mount_point}/SYSTEM" ]; then
  echo -e "\033[1;31m❌ 缺少 SYSTEM 镜像文件，无法继续\033[0m"
  exit 1
fi

echo -e "\033[1;34m❌ 删除残留文件夹如果有...\033[0m"
rm -rf ${system_root}
echo -e "\033[1;34m📂 解包...\033[0m"
unsquashfs -d ${system_root} ${mount_point}/SYSTEM

modify_system

# 下载 mod 数据（如未存在）
if [ ! -d "$download_data" ]; then
  download_mod_data "$download_data"
fi

# 🎯 复制数据
if $IS_MINI; then
  echo -e "\033[1;36m➡️ 进入 Mini 模式：仅复制必要 mod 数据\033[0m"
  copy_minimal_files
else
  echo -e "\033[1;36m➡️ 进入 Full 模式：复制全部 mod 数据\033[0m"
  cp "${download_data}/"* "${mount_point_storage}/data/"
fi

# ✅ 构建 SYSTEM 镜像等收尾
finalize_image

if [[ "$IS_EMMC" == "true" ]]; then
    suffix=$($IS_MINI && echo "mini-emmc-mod" || echo "emmc-mod")
else
    suffix=$($IS_MINI && echo "mini-mod" || echo "mod")
fi

output_file="${filename/.img/-$suffix.img}"
mv "$filename" "$output_file"

if [[ "$2" != *.img ]]; then
    gzip "$output_file"
    size=$(du -h "$output_file.gz" | cut -f1)
    echo -e "\033[1;32m✅ 构建完成：$output_file.gz （大小：$size）\033[0m"
fi
