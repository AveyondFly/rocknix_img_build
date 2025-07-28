# Rocknix 全自动镜像魔改构建系统

这是一个采用 GitHub Actions 实现的全自动构建平台，自动下载、扩容、解包、魔改、打包 Rocknix 镜像，并上传到 GitHub Release 和百度网盘指定目录，支持 Stable 和 Nightly 两种类型。

---

## 🎮 魔改功能概述

### 模拟器扩展

1. 添加 freej2me 独立 Java 模拟器
2. 添加 pymo 独立模拟器
3. 添加 支持OpenBor Lns的OpenBorFF 独立模拟器
4. 添加 64 位 NDS 独立模拟器，支持中文菜单和金手指
5. 添加 _genesis_plus_gx_EX_libretro.so 核心，支持青色胶囊
6. 添加 fbneo_ips 核心和 fbneo_plus 核心，支持 IPS 街机
7. 添加 onscripter 和 onsyuri 核心，支持 ONS 游戏
8. 添加 dosbox_svn 核心
9. 添加 easyrpg_32b 核心
10. 添加 fbalpha2012_32b，fbneo_32b，mame2003_plus_32b 核心
11. 添加 pscx_rearmed_rumble_32b 核心，修复部分 PS 游戏显示缺失
12. 添加 gam4980_32b 核心，支持步步高学习机游戏

### 中文用户体验

1. 补全 PPSSPP 中文字体
2. 补全 Rocknix 工具中文菜单列表
3. 补全 EmulationStation 前端中文字体
4. 补全 RetroArch 中文字体
5. 补全部分金手指文件

### 用户体验优化

1. 补全游戏遮罩（支持 640x480，720x720，480x320）
2. 支持单卡用户在 Windows 下直接传输游戏
3. 重新设置 Rocknix 卡2 游戏路径
4. 补全缺失的 JDK

---

## 📅 项目流程概览

- 支持 Stable + Nightly 两种镜像清算重构
- 支持定时构建和手动触发
- 支持跨平台构建（RK3326 / 3566 / x55 / H700）
- 构建后镜像支持分卷上传 GitHub + 百度网盘

---

## 🛠️ 自动构建流程说明

### 🤖🟢 Stable 构建流程

- 每日定时触发（北京时间 10:00）
- 拉取 `ROCKNIX/distribution` 中最新版本
- 判断版本号是否更新（除非强制构建）
- 构建并发布多个架构（如：3326、3566、x55、H700）
- 上传到 GitHub Release，并分卷处理大文件
- 将 `.img.gz` 镜像上传到用户指定的百度云路径

### 🤖🌙 Nightly 构建流程

- 每日定时触发（北京时间 08:00）
- 拉取 `ROCKNIX/distribution-nightly` 中最新版本
- 其余流程与 Stable 基本一致
- 可同时存在 Stable 与 Nightly 构建，互不冲突

---

## 🖐️ 手动触发说明（可选参数）

| 参数名           | 说明                                                         |
| ---------------- | ------------------------------------------------------------ |
| `force_build`    | 是否强制构建（跳过版本重复判断），默认 `true`                |
| `manual_tag`     | 手动指定 tag（如 `20250728`），会生成形如 `stable-20250728` 的 tag |
| `selected_archs` | 构建的目标架构（如 `3326,x55`，多个用英文逗号）              |
| `baiduyun_path`  | 自定义百度云上传路径（不含结尾 `/`，如 `/rocknix自动构建/stable`） |

---

## 📦 构建产物说明

- 所有镜像均为 `.img.gz` 格式；
- 若文件超出 2GB，自动进行 `7z` 分卷打包；
- 最终产物上传到：
  - GitHub Release（支持直接下载）；
  - 百度网盘指定路径（按版本号创建子目录）。

---

## 🧰 脚本构建逻辑（`build_mod_img.sh`）

构建流程包含以下步骤：

1. **版本判断与下载**
   - 拉取最新版本或指定 tag 镜像；
   - 解压 `.img.gz`

2. **镜像扩容**
   - 依据平台使用 GPT/MBR 分区扩展；

3. **挂载分区 & 解包 SYSTEM**
   - 提取并修改 `SYSTEM` squashfs；

4. **注入 mod 内容**
   - 按平台注入内核模块、joypad 驱动、启动脚本、补丁等；

5. **资源数据注入**
   - 下载外挂资源（如 `mod_cores.zip`）；
   - mini 模式仅复制精简包；

6. **打包 SYSTEM**
   - 使用 `mksquashfs` 重建系统；
   - 按平台修正引导参数（如 UUID 替换）；

7. **生成构建产物**
   - 输出重命名后文件（含 `-mod` / `-mini-mod` 等后缀）；
   - gzip 压缩为最终产物。

---

## 🧾 mod-version 分支记录机制

- 构建成功的版本记录在 `.version` 文件；

- 保存在 `mod-version` 分支中，格式如：

  ```text
  rocknix-stable:20250727
  rocknix-nightly:20250728
  ```

---

## ☁️ 百度网盘上传说明

- 使用 `BaiduPCS-Go` 工具上传至百度网盘；

- 上传路径根据手动输入的 `baiduyun_path` 拼接版本号目录；

- 例如：

  ```text
  /rocknix自动构建/nightly/20250728/
  ```

---

## 🔐 GitHub Secrets 配置

| Secret 名称    | 用途说明                                           |
| -------------- | -------------------------------------------------- |
| `GH_PAT`       | 用于调用 GitHub API（避免速率限制，非必需但推荐）  |
| `BAIDU_COOKIE` | 用于 `BaiduPCS-Go login -cookies=...` 登录百度网盘 |

---

## 🚨 错误处理机制

- 若构建失败，会自动清除对应的 tag 与 GitHub Release；
- 保证无效构建不污染发布页面；
- `.version` 仅在成功构建后更新。

---

## 📌 附加说明

- 魔改脚本支持 eMMC 模式处理，会解析 `3326-emmc` 自动处理 uboot
- 对 RGB20S/RGB10 等设备做了 quirks patch 处理
- 可扩展自定义 mod data repo 和 emmc binary

---

> 如需集成上传到其他网盘（如 onedrive、oss），或扩展支持第三方镜像源，欢迎提交Pr和Issues
