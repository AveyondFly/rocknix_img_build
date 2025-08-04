RK3326 启动配置切换工具 (Mac用户手动操作指南)
=========================================

由于脚本在Mac系统上可能无法正常运行，请按照以下步骤手动切换配置：

1. 准备工作
------------
- 下载完整的配置文件包（包含以下内容）：
  ├── config/
  │   ├── boot.ini
  │   ├── boot-overlays.ini
  │   ├── overlays-rg351v-p2/
  │   └── ...其他overlays文件夹...
  └── rk3326-*.dtb（各种dtb文件）

2. 手动切换步骤
---------------
① 删除旧配置文件：
   - 打开终端，执行：
     rm -f /Volumes/你的TF卡/boot.ini
     rm -rf /Volumes/你的TF卡/overlays

② 复制新配置：
   A. 普通设备：
      cp config/boot.ini /Volumes/你的TF卡/
      cp rk3326-对应设备.dtb /Volumes/你的TF卡/

   B. 需要overlays的设备（如RG351V V2屏幕）：
      cp config/boot-overlays.ini /Volumes/你的TF卡/boot.ini
      cp -r config/overlays-对应型号/ /Volumes/你的TF卡/overlays

3. 设备对照表
-------------
| 设备类型           | 需要复制的文件                          |
|--------------------|----------------------------------------|
| 普通设备           | boot.ini + 对应.dtb文件                |
| 需要overlays的设备 | boot-overlays.ini + 对应.dtb + overlays|

常见设备配置：
- 安伯尼克 RG351V V2屏幕：
  rk3326-anbernic-rg351v.dtb + overlays-rg351v-p2
- GameConsole R36s P3屏幕：
  rk3326-gameconsole-r33s.dtb + overlays-r36s-p3

4. 修改boot.ini（可选）
------------------------
如果用文本编辑器打开boot.ini，请确保：
1. 换行符为LF格式（Unix格式）
2. 包含以下关键行：
   FDT /rk3326-对应设备.dtb

5. 注意事项
-----------
❗ 操作前请备份重要数据
❗ 确保TF卡已正确挂载到/Volumes/目录
❗ 文件名严格区分大小写
❗ 使用"磁盘工具"安全弹出TF卡