@echo off
color 1F
setlocal ENABLEDELAYEDEXPANSION

:: 启动 ASCII LOGO 和说明
echo( " ※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※ "
echo(
echo( "   --------------------------------------------------------------------------"
echo( "        ___          __                    _         __  ___________  ____ "
echo( "       /   |  ____  / /_  ___  _________  (_)____   / / / /__  / __ \/ __ \ "
echo( "      / /| | / __ \/ __ \/ _ \/ ___/ __ \/ / ___/  / /_/ /  / / / / / / / / "
echo( "     / ___ |/ / / / /_/ /  __/ /  / / / / / /__   / __  /  / / /_/ / /_/ /  "
echo( "    /_/  |_/_/ /_/_.___/\___/_/  /_/ /_/_/\___/  /_/ /_/  /_/\____/\____/   "
echo( "           ____  __________     _____      __          __                 "
echo( "          / __ \/_  __/ __ )   / ___/___  / /__  _____/ /_____  _____      "
echo( "         / / / / / / / __  |   \__ \/ _ \/ / _ \/ ___/ __/ __ \/ ___/      "
echo( "        / /_/ / / / / /_/ /   ___/ /  __/ /  __/ /__/ /_/ /_/ / /          "
echo( "       /_____/ /_/ /_____/   /____/\___/_/\___/\___/\__/\____/_/           "
echo(
echo( "   --------------------------------------------------------------------------"
echo(
echo( "     * 每个 H700 设备都需要将其相应的 DTB 复制到 ROCKNIX 分区的根文件夹中 *"
echo(
echo( "           * 本程序根据选择的机型自动完成 DTB 文件的复制 *"
echo(
echo( "   --------------------------------------------------------------------------"
echo(
echo( "                               ╔-------------╗"
echo( "                               ┆ 按任意键继续┆"
echo( "                               ╚-------------╝"
echo(
echo( "   --------------------------------------------------------------------------"
pause >nul
cls


REM 检查 device_trees 文件夹是否存在
if not exist "device_trees" (
    echo ? 设备树丢失，请重新刷写固件。
    pause
    exit /b
)

REM 设备型号与 dtb 文件映射
set "name1=RG 28XX"
set "file1=sun50i-h700-anbernic-rg28xx.dtb"

set "name2=RG 35XXH"
set "file2=sun50i-h700-anbernic-rg35xx-h.dtb"

set "name3=RG 35XXH [新屏幕rev6]"
set "file3=sun50i-h700-anbernic-rg35xx-h-rev6-panel.dtb"

set "name4=RG 35XXPlus"
set "file4=sun50i-h700-anbernic-rg35xx-plus.dtb"

set "name5=RG 35XXPlus [新屏幕rev6]"
set "file5=sun50i-h700-anbernic-rg35xx-plus-rev6-panel.dtb"

set "name6=RG 35XX+"
set "file6=sun50i-h700-anbernic-rg35xx-2024.dtb"

set "name7=RG 35XX+ [新屏幕rev6]"
set "file7=sun50i-h700-anbernic-rg35xx-2024-rev6-panel.dtb"

set "name8=RG 35XX SP"
set "file8=sun50i-h700-anbernic-rg35xx-sp.dtb"

set "name9=RG 35XX SP [新屏幕V2]"
set "file9=sun50i-h700-anbernic-rg35xx-sp-v2-panel.dtb"

set "name10=RG 40XXH"
set "file10=sun50i-h700-anbernic-rg40xx-h.dtb"

set "name11=RG 40XXV"
set "file11=sun50i-h700-anbernic-rg40xx-v.dtb"

set "name12=RG CubeXX"
set "file12=sun50i-h700-anbernic-rgcubexx.dtb"

set "name13=RG 34XX"
set "file13=sun50i-h700-anbernic-rg34xx.dtb"

set "name14=RG 34XX SP"
set "file14=sun50i-h700-anbernic-rg34xx-sp.dtb"

set "name15=RG 35XX Pro"
set "file15=sun50i-h700-anbernic-rg35xx-pro.dtb"

:menu
cls
echo ================================
echo        请选择设备型号：
echo ================================
for /L %%i in (1,1,15) do (
    call echo  %%i. !name%%i!
)
echo ================================
set /p choice=请输入编号（1-15）或输入 Q 退出：

REM 退出选项
if /I "%choice%"=="Q" goto :exit

REM 输入是否为数字
set /a test=choice+0 >nul 2>nul
if %choice% lss 1 goto :invalid
if %choice% gtr 15 goto :invalid

REM 获取文件名和设备名
call set "dtb_file=!file%choice%!"
call set "device_name=!name%choice%!"

REM 检查文件是否存在
if not exist "device_trees\!dtb_file!" (
    echo.
    echo 未找到对应的 DTB 文件：device_trees\!dtb_file!
    goto :exit
)

REM 执行复制并重命名
copy /Y "device_trees\!dtb_file!" "dtb.img" >nul
echo.
echo [!device_name!] 的设备树已成功复制为 dtb.img
pause
goto :menu

:invalid
echo.
echo 输入无效，请输入 1 到 15 的数字，或输入 Q 退出。
pause
goto :menu

:exit
echo.
echo 感谢使用，按任意键退出...
pause >nul
exit
