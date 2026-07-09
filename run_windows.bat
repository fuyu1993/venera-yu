@echo off
chcp 65001 >nul
REM 热启动 venera 的 Windows 桌面端
REM 用法: 双击 run_windows.bat
REM 启动后支持: r=热重载, R=热重启, h=帮助, d=分离, q=退出
setlocal

cd /d "%~dp0"

set PATH=C:\Users\10911\flutter\flutter\bin;%PATH%

echo ^> flutter run -d windows
flutter run -d windows

pause
