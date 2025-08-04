@echo off
pyinstaller --onefile --icon=my.ico dtb_selector.py
copy /Y dist\dtb_selector.exe dtb_selector.exe >nul
rmdir /S /Q build
rmdir /S /Q dist
del /F /Q dtb_selector.spec