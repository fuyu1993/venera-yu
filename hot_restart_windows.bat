@echo off
chcp 65001 >nul
REM 触发热重启 (Hot Restart) — 向 Flutter 进程发送热重启信号
REM 用法: 双击 hot_restart_windows.bat (需在 flutter run 运行中的终端外执行)

setlocal

REM 查找 flutter_tools.snapshot run 进程的 PID
for /f "tokens=2 delims=," %%a in ('wmic process where "commandline like '%%flutter_tools.snapshot%%' and commandline like '%%run%%'" get processid /format:csv 2^>nul ^| findstr /r "[0-9]"') do set PID=%%a

if "%PID%"=="" (
    echo [错误] 未找到正在运行的 Flutter 进程
    pause
    exit /b 1
)

REM 向 Flutter 控制台进程发送大写 'R' 触发 Hot Restart
powershell -Command "$p = Get-Process -Id %PID%; if ($p) { $p.StandardInput.WriteLine('R'); Write-Host '热重启信号已发送 (PID: %PID%)' } else { Write-Host '进程不存在' }"

if %errorlevel% equ 0 (
    echo [成功] 热重启已触发 (PID: %PID%)
) else (
    echo [错误] 发送信号失败
    pause
    exit /b 1
)
