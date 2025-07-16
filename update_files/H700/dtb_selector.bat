@echo off
color 1F
setlocal ENABLEDELAYEDEXPANSION

:: ���� ASCII LOGO ��˵��
echo( " �������������������������������������������������������������������������� "
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
echo( "     * ÿ�� H700 �豸����Ҫ������Ӧ�� DTB ���Ƶ� ROCKNIX �����ĸ��ļ����� *"
echo(
echo( "           * ���������ѡ��Ļ����Զ���� DTB �ļ��ĸ��� *"
echo(
echo( "   --------------------------------------------------------------------------"
echo(
echo( "                               �X-------------�["
echo( "                               �� �������������"
echo( "                               �^-------------�a"
echo(
echo( "   --------------------------------------------------------------------------"
pause >nul
cls


REM ��� device_trees �ļ����Ƿ����
if not exist "device_trees" (
    echo ? �豸����ʧ��������ˢд�̼���
    pause
    exit /b
)

REM �豸�ͺ��� dtb �ļ�ӳ��
set "name1=RG 28XX"
set "file1=sun50i-h700-anbernic-rg28xx.dtb"

set "name2=RG 35XXH"
set "file2=sun50i-h700-anbernic-rg35xx-h.dtb"

set "name3=RG 35XXH [����Ļrev6]"
set "file3=sun50i-h700-anbernic-rg35xx-h-rev6-panel.dtb"

set "name4=RG 35XXPlus"
set "file4=sun50i-h700-anbernic-rg35xx-plus.dtb"

set "name5=RG 35XXPlus [����Ļrev6]"
set "file5=sun50i-h700-anbernic-rg35xx-plus-rev6-panel.dtb"

set "name6=RG 35XX+"
set "file6=sun50i-h700-anbernic-rg35xx-2024.dtb"

set "name7=RG 35XX+ [����Ļrev6]"
set "file7=sun50i-h700-anbernic-rg35xx-2024-rev6-panel.dtb"

set "name8=RG 35XX SP"
set "file8=sun50i-h700-anbernic-rg35xx-sp.dtb"

set "name9=RG 35XX SP [����ĻV2]"
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
echo        ��ѡ���豸�ͺţ�
echo ================================
for /L %%i in (1,1,15) do (
    call echo  %%i. !name%%i!
)
echo ================================
set /p choice=�������ţ�1-15�������� Q �˳���

REM �˳�ѡ��
if /I "%choice%"=="Q" goto :exit

REM �����Ƿ�Ϊ����
set /a test=choice+0 >nul 2>nul
if %choice% lss 1 goto :invalid
if %choice% gtr 15 goto :invalid

REM ��ȡ�ļ������豸��
call set "dtb_file=!file%choice%!"
call set "device_name=!name%choice%!"

REM ����ļ��Ƿ����
if not exist "device_trees\!dtb_file!" (
    echo.
    echo δ�ҵ���Ӧ�� DTB �ļ���device_trees\!dtb_file!
    goto :exit
)

REM ִ�и��Ʋ�������
copy /Y "device_trees\!dtb_file!" "dtb.img" >nul
echo.
echo [!device_name!] ���豸���ѳɹ�����Ϊ dtb.img
pause
goto :menu

:invalid
echo.
echo ������Ч�������� 1 �� 15 �����֣������� Q �˳���
pause
goto :menu

:exit
echo.
echo ��лʹ�ã���������˳�...
pause >nul
exit
