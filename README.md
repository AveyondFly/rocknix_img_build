# Rocknix 镜像魔改工具（Mod Builder）

> 一键下载/解包/注入补丁/重打包 Rocknix 镜像，并通过 GitHub Actions 实现 Nightly 全自动构建与分发。

---

## 目录 / Table of Contents
- [简介](#简介)
- [支持平台](#支持平台)
- [快速开始](#快速开始)
- [本地构建依赖](#本地构建依赖)
- [脚本说明：build_mod_img.sh](#脚本说明build_mod_imgsh)
- [魔改功能概述](#魔改功能概述)
- [输出产物与命名](#输出产物与命名)
- [CI/CD 工作流：nightly 自动构建](#cicd-工作流nightly-自动构建)
- [CI/CD 工作流：stable 自动构建](#cicd-工作流stable-自动构建)
- [CI/CD 工作流：手动发布（Baidu 网盘）](#cicd-工作流手动发布baidu-网盘)
- [CI/CD 工作流：清理任务](#cicd-工作流清理任务)
- [环境变量与机密](#环境变量与机密)
- [目录结构建议](#目录结构建议)
- [常见问题](#常见问题)
- [许可证](#许可证)

---

## 简介
本仓库包含一个用于 **Rocknix 镜像魔改** 的 Bash 脚本和 GitHub Actions 工作流：

- 脚本会按设备下载官方/备份镜像 → 自动扩容 → 挂载分区 → 解包 `SYSTEM` → 注入补丁与资源 → 重新打包 → 调整引导配置（eMMC/UUID 等）→ 输出可直接刷写/分发的新镜像。
- 工作流会每日自动检测最新 nightly 版本并构建多架构镜像，同时上传到 **GitHub Release** 与（可选）**百度网盘**。

> 支持传入现有 `.img` 镜像进行“就地魔改”，也支持通过 tag 自动拉取官方（nightly/stable）或备用仓库镜像。

---

## 支持平台
- **RK3566**（含 `x55` 变体）
- **RK3326**（含 `-emmc` 变体）
- **H700**
- **SM8250**

可选修饰：
- `mini`：仅复制最小化资源（更快、体积更小）
- `stable`：从稳定发行仓库拉取（默认 nightly）
- `emmc`：3326 专用 eMMC 引导处理

> 设备参数中 **包含** 对应关键字即可（例如：`3566_mini`、`3326-emmc_stable`、`x55_mini`）。

---

## 快速开始
> **必须以 root/sudo 运行**，脚本会挂载 loop 设备并修改镜像。

```bash
# 1) 安装依赖（Ubuntu/Debian 示例）
sudo apt-get update && sudo apt-get install -y \
  jq curl wget gzip xz-utils p7zip-full \
  parted gdisk sgdisk util-linux e2fsprogs dosfstools \
  squashfs-tools # 提供 unsquashfs/mksquashfs

# 2) 运行脚本（以 RK3566 为例）
chmod +x ./build_mod_img.sh
sudo ./build_mod_img.sh 3566

# 传入 tag（会优先使用备份仓库版本）
sudo ./build_mod_img.sh h700 nightly-20250712

# 传入本地镜像路径（不再下载）
sudo ./build_mod_img.sh x55 ./Rocknix-x55-20250712.img

# 其它常用示例
sudo ./build_mod_img.sh 3566_mini
sudo ./build_mod_img.sh 3326-emmc
sudo ./build_mod_img.sh 3326-emmc_stable
```

---

## 本地构建依赖
脚本会调用以下工具，请确保已安装：
- `curl`/`wget`、`jq`（GitHub API/下载与 JSON 解析）
- `parted`/`sgdisk`/`gdisk`/`partprobe`/`losetup`（镜像分区操作）
- `e2fsck`/`resize2fs`（EXT 文件系统检查与扩容）
- `unsquashfs`/`mksquashfs`（解包/重打包 `SYSTEM`）
- `depmod`（在 3326 平台重建内核模块依赖）
- `python3`（调用 `tools/*.py` 脚本以合并/更新 ES 配置）

可选：
- 环境变量 `GH_PAT`（提升 GitHub API 频率，强烈建议）

---

## 脚本说明：`build_mod_img.sh`
**调用方式**
```bash
sudo ./build_mod_img.sh <DEVICE> [<RELEASE_TAG | <local-image>.img>]
```

**DEVICE 取值**（示例）：
- `3566`、`x55`、`3326`、`h700`、`sm8250`
- 可追加修饰：`_mini`、`-emmc`、`_stable` 等任意组合（只要包含关键字即可）
  - 例：`3326-emmc_stable`、`x55_mini`、`3566_stable`

**主要流程**（择要）：
1. **来源选择**：
   - 默认从 `ROCKNIX/distribution-nightly` 拉取最新；包含 `stable` 时切换到 `ROCKNIX/distribution`。
   - 若提供第二参数为 `RELEASE_TAG`，走 **备用仓库**（`lcdyk0517/rocknix.sync`）同名 tag。
2. **镜像扩容**：
   - 3566/x55 走 **GPT** 分区扩容；其他走 **MBR** 扩容。
   - `mini` 模式默认 **不扩容**（脚本中仅对非 mini 执行）。
3. **挂载与解包**：
   - 挂载 `p1`（BOOT）/`p2`（STORAGE），解包 `SYSTEM` → `${SYSTEM-root}`。
4. **平台补丁**：
   - 拷贝 `sys_root_files/` 与 `mod_files/`（不同平台有差异化处理/过滤）。
   - 3326 设备：替换/追加内核模块、生成 `modules.order`、`depmod` 以及固件复制；非 eMMC 模式还会批量覆盖启动/配置文件。
6. **ES 配置融合**：
   - 调用 `tools/add_core_to_emulator.py`、`tools/update_ext.py`、`tools/merge_system.py` 合并系统/扩展配置。
7. **重新打包**：
   - 以 `mksquashfs` 生成新的 `SYSTEM`，回写到镜像；必要时修正 `UUID`/`extlinux.conf`。
8. **数据资源**：
   - 初次运行若不存在 `data_files/`，将从 `AveyondFly/console_mod_res` 最新 release 下载所需资源（支持 `GH_PAT`）。
   - `mini` 仅复制最小资源集合；非 `mini` 复制完整数据至 `STORAGE/data/`。

> 若以 `.img` 为输入，则跳过下载环节；若以 tag 为输入，则优先拉取 **备份仓库** 中同名发布。

---

## 魔改功能概述
> 以下功能为主要该项目主要的魔改

### 模拟器扩展
- 新增 **freej2me** 独立 Java 模拟器
- 新增 **pymo** 狭义 Python 游戏引擎独立模拟器
- 新增 **OpenBOR‑FF** 独立模拟器（支持 **OpenBOR LNS**）
- 新增 **64 位 NDS** 独立模拟器（支持中文菜单与金手指）
- 新增 `genesis_plus_gx_EX_libretro.so` 核心（支持“青色胶囊”）
- 新增 `fbneo_ips` 与 `fbneo_plus` 核心（支持 IPS 街机）
- 新增 `onscripter` 与 `onsyuri` 核心（支持 ONS 游戏）
- 新增 `dosbox_svn` 核心
- 新增 `easyrpg_32b` 核心
- 新增 `fbalpha2012_32b`、`fbneo_32b`、`mame2003_plus_32b` 核心
- 新增 `pcsx_rearmed_rumble_32b` 核心（修复部分 PS 游戏显示缺失）
- 新增 `gam4980_32b` 核心（支持步步高学习机游戏）

### 中文用户体验
- 补全 **PPSSPP** 中文字体
- 补全 **Rocknix 工具**中文菜单列表
- 补全 **EmulationStation** 前端中文字体
- 补全 **RetroArch** 中文字体
- 补全部分金手指文件

### 用户体验优化
- 补全游戏遮罩（支持 **640×480**、**720×720**、**480×320**）
- 支持**单卡**用户在 Windows 下直接传输游戏
- 重新设置 **Rocknix 卡2** 游戏路径
- 补全缺失的 **JDK**

---

## 输出产物与命名
- 生成的新镜像会根据模式追加后缀：
  - 标准：`*-mod.img`
  - mini：`*-mini-mod.img`
  - eMMC：`*-emmc-mod.img`
  - mini + eMMC：`*-mini-emmc-mod.img`
- 当 **脚本自行下载** 镜像时，最终会 **自动 gzip**（得到 `*.img.gz`）。
- 当 **传入本地 .img** 时，不会自动压缩，保留为 `.img`。

---

## CI/CD 工作流：nightly 自动构建
工作流：**“🤖🌙 rocknix-nightly 全自动镜像魔改”**（`.github/workflows/*`）

**触发方式**
- `schedule`: 每日 00:00 UTC
- `workflow_dispatch`: 支持参数
  - `force_build`（默认 `true`）：为 `false` 时，若版本未变更则跳过
  - `manual_tag`：手动指定 tag（如 `20250722`）
  - `selected_archs`：逗号分隔（如 `3566,x55,h700`）；默认构建 `3566,x55,3326,h700,3326-emmc,sm8250`
  - `baiduyun_path`：百度云根路径（默认 `/rocknix/自动构建/nightly`）
- `create`: 当创建 `nightly-*` tag 时

**Job 要点**
1. **version-check**：
   - 从 `ROCKNIX/distribution-nightly` 读取最新 release，提取 `H700` 镜像 URL 中的 **8 位日期版本号**；
   - 对比 `.version`（`mod-version` 分支）决定是否跳过；
   - 创建对应的 GitHub Release 与 tag。
2. **build-and-package**：
   - 安装依赖 → 逐架构执行 `sudo ./build_mod_img.sh <arch>`；
   - 上传 `*.img.gz` 为 Artifact；若单文件超过 ~2GB，切分为 `1.9GB` 分卷（`7z -v1900m`）并上传到 Release。
3. **upload-to-baidu**（可选）：
   - 使用 `BaiduPCS-Go` 登录并将 **非 mini** 镜像上传至：`<baiduyun_path>/<YYYYMMDD>/`。
4. **save-version**：
   - 更新/提交 `.version` 到 `mod-version` 分支，键为 `rocknix-nightly`。
5. **cleanup-on-failure**：
   - 构建失败时清理 Release 与 tag。

---

## CI/CD 工作流：stable 自动构建
工作流：**“🤖🟢 rocknix-stable 全自动镜像魔改”**（`.github/workflows/*`）

**触发方式**
- `schedule`: 每日 **02:00 UTC**
- `workflow_dispatch`: 支持参数
  - `force_build`（默认 `true`）：为 `false` 时，若版本未变更则跳过
  - `manual_tag`：手动指定 tag（如 `20250722`）
  - `selected_archs`：逗号分隔（如 `3566,x55,h700`）
  - `baiduyun_path`：百度云根路径（默认 `/rocknix/自动构建/stable`）
- `create`: 当创建 `stable-*` tag 时

**Job 要点**
1. **version-check**：
   - 从 `ROCKNIX/distribution` 读取最新 **稳定版** release，提取 `H700` 镜像 URL 中的 **8 位日期版本号**；
   - 对比 `.version`（`mod-version` 分支）中键 `rocknix-stable`，决定是否跳过；
   - 创建对应 GitHub Release 与 tag（`auto-stable-<ver>` 或 `stable-<manual_tag>`）。
2. **build-and-package**：
   - 安装依赖 → 逐架构执行 `sudo ./build_mod_img.sh <arch>`；
   - 传入的 `<arch>` **包含 `_stable`** 时会触发脚本的稳定源逻辑（脚本中按关键字识别）。
   - 上传 `*.img.gz` 为 Artifact；若单文件超过 ~2GB，切分为 `1.9GB` 分卷并上传到 Release。
3. **upload-to-baidu**（可选）：
   - 使用 `BaiduPCS-Go` 登录并将 **非 mini** 镜像上传至：`<baiduyun_path>/<YYYYMMDD>/`，默认根目录为 `/rocknix/自动构建/stable`。
4. **save-version**：
   - 更新/提交 `.version` 到 `mod-version` 分支，键为 `rocknix-stable`。
5. **cleanup-on-failure**：
   - 构建失败时清理 Release 与 tag。

> **提示（matrix 入参）**：`version-check` 中的“解析应构建架构”步骤会**为传入项追加 `_stable`**。若你在 `selected_archs` 里**已经**写了 `_stable`，可能出现重复后缀（例如 `3566_stable_stable`）。建议在手动指定时仅填裸架构：`3566,x55,3326,h700,3326-emmc,sm8250。

---

## CI/CD 工作流：手动发布（Baidu 网盘）
工作流：**“Create Release with BDPan”**（`.github/workflows/release.yml`）

**触发方式**
- `workflow_dispatch`：参数
  - `force_build`（默认 `false`）：为 `true` 时忽略版本比较、强制构建
  - `manual_tag`：手动指定 tag（可为空）
- `create`: 当创建 `v*` tag 时触发（流程中会删除该临时 tag 以避免保留）

**Job（build-and-release）步骤概览**
1. **恢复版本信息**：从 `mod-version` 分支恢复 `.version`。
2. **清理触发用 tag**（当 `create` 触发时）：删除远端 `v*` tag。
3. **版本检测与对比**：
   - 从 `ROCKNIX/distribution-nightly` 获取最新 release，提取 **H700** 镜像 URL 中的 8 位日期版本号；
   - 若 `force_build != true` 且版本未变化，则以退出码 `78` 终止；
   - 生成 `tag_name`（`auto-<version>` 或 `manual_tag`）与 `release_name`。
4. **构建镜像**：安装依赖，依次执行：
   - `3566` / `x55` / `3326` / `3326-emmc` / `h700`
   - **当前固定使用** `nightly-20250712` **作为输入 tag** 进行构建。
5. **收集产物**：遍历仓库内所有 `*.img.gz`，汇总至环境变量以供后续上传。
6. **上传至百度网盘**：安装并用机密 `BAIDU_COOKIE` 登录 **BaiduPCS-Go**，上传到 `/rocknix/手动构建/<YYYYMMDD>/`。
7. **创建 GitHub Release**：使用 `GITHUB_TOKEN` 基于 `tag_name` 发布 release，并写入说明。
8. **推送版本号**：将 `.version` 写入/更新到 `mod-version` 分支，然后切回 `main`。

**注意 / 建议**
- 构建步骤中 **硬编码** 的 `nightly-20250712` 可能与“版本检测”得到的版本不一致，
  建议将该 tag 改为检测结果或作为 `workflow_dispatch` 入参传递，避免错配。
- 此工作流**固定了一组设备**构建（未区分 mini 与非 mini），最终行为以脚本对设备名关键字的解析为准。

**机密与环境变量**
- `BAIDU_COOKIE`（BaiduPCS-Go 登录）
- `GITHUB_TOKEN`（创建 Release）

---

## CI/CD 工作流：清理任务
工作流：**“🧹 清理构建记录与百度云构建目录”**

**触发方式**
- `schedule`: 每日 **04:00 UTC**
- `workflow_dispatch`: 可手动触发

**Job（cleanup）步骤概览**
1. **检出仓库**：`actions/checkout@v4`。
2. **清理百度云目录**（分别对 `nightly` 与 `stable`）：
   - 安装并登录 **BaiduPCS-Go**（使用机密 `BAIDU_COOKIE`）。
   - 目标路径：`/rocknix/魔改包/自动构建/<TYPE>`（`TYPE ∈ {nightly, stable}`）。
   - 仅保留 **最新 5 个**子目录；其余按名称排序删除（默认按字符串排序，依赖目录命名为日期格式）。
3. **清理 GitHub Releases / Tags**：
   - 使用 `gh` CLI（令牌 `GH_PAT`）拉取 release 列表与所有 git tags。
   - 删除**孤立 tag**（没有对应 release）。
   - 将 release 分为 `nightly` / `stable` / 其他，分别对 nightly/stable **仅保留最新 5 个**，删除多余的 release 与对应 tag；“其他”类型全部删除。

**机密与环境变量**
- `BAIDU_COOKIE`：BaiduPCS-Go 登录。
- `GH_PAT`：gh CLI API 调用（在步骤中以 `GH_TOKEN` 环境变量使用）。

---

### Nightly vs Stable 差异速览

| 项目 | Nightly 工作流 | Stable 工作流 |
| --- | --- | --- |
| 源仓库 | `ROCKNIX/distribution-nightly` | `ROCKNIX/distribution` |
| 定时触发 | **00:00 UTC** | **02:00 UTC** |
| 默认网盘路径 | `/rocknix/自动构建/nightly` | `/rocknix/自动构建/stable` |
| 版本号键（.version） | `rocknix-nightly` | `rocknix-stable` |
| Tag 前缀 | `nightly-*` / `auto-nightly-<ver>` | `stable-*` / `auto-stable-<ver>` |


---

## 环境变量与机密
- **脚本/工作流均可用**
  - `GH_PAT`：提升 GitHub API 访问频率（强烈建议设置）。
- **GitHub Actions 机密**
  - `BAIDU_COOKIE`：给 `BaiduPCS-Go login -cookies=...` 使用，用于网盘上传。

---

## 目录结构建议
```text
<repo-root>/
├─ build_mod_img.sh                 # 本文档对应脚本
├─ update_files/                    # 通用/平台化资源（脚本中引用）
├─ tools/                           # Python 工具：合并/更新 ES 配置
├─ sys_root_files/                  # 注入到 SYSTEM 的基础文件
├─ mod_files/                       # 各平台差异化补丁/资源
├─ data_files/                      # 第一次运行可自动下载/填充
├─ .github/workflows/               # CI/CD（nightly / stable / release / …）
└─ README.md                        # 本文件
```

---

## 常见问题
- **必须 root/sudo？** 是。脚本要挂载 loop 设备并修改分区/文件系统。
- **API 频率受限？** 设置 `GH_PAT`（环境变量或 Actions 机密）。
- **本地传入 .img 会被压缩吗？** 不会；只有脚本下载的镜像会在结尾自动 `gzip`。
- **分卷规则？** 在工作流里，单文件 >≈2GB 时会切成 `1.9GB` 分卷并上传到 Release。
- **eMMC 专用？** 仅 `3326` 系列支持 `emmc` 关键字，将额外处理 u-boot 与 UUID。

