# 🚀 全自动魔改镜像发布构建系统

本项目通过 GitHub Actions 实现了对 ROCKNIX 镜像的自动化魔改、构建、上传、发布等完整流程，支持每日定时检查新版本，构建多个平台镜像（含 mini 版），并将构建产物上传至 GitHub Release 与百度网盘。

---

## 📌 功能亮点

- ⏱️ **每天 2 次定时构建**（北京时间 09:00 和 21:00）
- 🛠️ **支持强制构建、手动 tag、自定义构建架构**
- 🔄 **自动检测 ROCKNIX 最新版本镜像**
- 📦 **支持多平台并行构建：3566、X55、3326、H700（含 mini）**
- 💾 **自动保存版本号至 `mod-version` 分支**
- ☁️ **构建产物上传至 GitHub Release**
- 📤 **自动上传至百度网盘目标路径 **
- ❌ **构建失败自动清理对应 Release 与 tag**
- 🧹 **清理 Release 及百度云构建目录，保留最新 10 项（可选扩展）**

---

## ⚙️ 使用方式

### ✅ 1. 自动构建（定时 & 发布 tag）

- 每天自动检查新版本：
  - `1:00` UTC（北京时间 09:00）
  - `13:00` UTC（北京时间 21:00）
- 发布格式 `v*` 的 tag 也会自动触发构建

---

### 🔘 2. 手动触发

你可以从 GitHub Actions 页面点击手动触发（`workflow_dispatch`），并自定义以下参数：

| 参数名           | 说明                               | 示例             |
| ---------------- | ---------------------------------- | ---------------- |
| `force_build`    | 是否强制构建（忽略版本是否已构建） | `true` / `false` |
| `manual_tag`     | 手动构建使用的 tag 名              | `20250722`       |
| `selected_archs` | 要构建的平台架构（多个用`,`分隔）  | `3566,x55,h700`  |

---

## 📂 构建流程说明

1. `version-check`：检查 ROCKNIX 镜像最新版本、是否已构建，创建 Release（空）
2. `build-and-upload`：并行构建对应平台，上传 GitHub Release 与百度网盘
3. `save-version`：将构建版本号写入 `mod-version` 分支用于下次判断
4. `cleanup-on-failure`：如构建失败，则自动清理对应 tag 和 Release

---

## 🔐 Secrets 配置说明

需在仓库的 `Settings → Secrets and variables → Actions` 页面中设置以下 secret：

| Secret 名称    | 用途                                    |
| -------------- | --------------------------------------- |
| `GH_PAT`       | 用于提升 GitHub API 速率 & 上传 Release |
| `BAIDU_COOKIE` | 用于登录 BaiduPCS-Go 账号并上传镜像     |

### 1. `GH_PAT` - GitHub Personal Access Token

用于访问 GitHub API，防止速率限制。

#### 获取方法：

1. 打开 GitHub → 点击右上头像 → `Settings`
2. 左侧选择 `Developer Settings` → `Personal access tokens` → `Tokens (classic)`
3. 点击 `Generate new token`
4. 勾选权限：`repo`, `workflow`
5. 生成后复制该 token
6. 打开你的仓库 → `Settings` → `Secrets and variables` → `Actions`
7. 添加一个新的 Secret 名称为 `GH_PAT`，粘贴 token 内容

---

### 2. `BAIDU_COOKIE` - 百度网盘 Cookie

用于通过 `BaiduPCS-Go` 登录网盘。

#### 获取方法：

1. 登录 [pan.baidu.com](https://pan.baidu.com) 网页版
2. 按 F12 打开开发者工具 → Application → Cookies
3. 找到 `BDUSS`、`STOKEN` 等字段
4. 拼接为 Cookie 字符串，例如：BDUSS=yyyy; STOKEN=zzzz;
5. 添加至 GitHub 仓库 → `Settings` → `Secrets and variables` → `Actions`
6. 新建一个 Secret，命名为 `BAIDU_COOKIE`，粘贴上一步获取的 Cookie

⚠️ **Cookie 中含敏感信息，请妥善保管，建议使用小号登录抓取**

---

## 📁 百度网盘上传路径规则

构建完成后，非 mini 镜像会上传设置的路径下



---

## 🧩 分卷上传支持

若镜像大于 **2GB**，则自动进行分卷（每卷 1900MB）上传到 GitHub Release。

---

## ❌ 构建失败时自动清理

当构建失败且未跳过版本时，会自动：

- 删除 GitHub Release
- 删除 GitHub Tag

---

## 🔁 可选：清理旧构建（待扩展）

你可以添加一个 `clean.yml` 工作流，用于：

- 检查 GitHub Release / 百度网盘构建目录是否超出 10 项
- 删除最旧的构建目录或 Release

---

## 🙋 联系方式

如果你有问题、建议或改进，欢迎提交 Issue 或 PR！
