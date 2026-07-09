@echo off
chcp 65001 >nul
REM 触发热加载 (Hot Reload) — 向 Flutter 进程发送热加载信号
REM 用法: 双击 hot_reload_windows.bat (需在 flutter run 运行中的终端外执行)

setlocal

REM 查找 flutter_tools.snapshot run 进程的 PID
for /f "tokens=2 delims=," %%a in ('wmic process where "commandline like '%%flutter_tools.snapshot%%' and commandline like '%%run%%'" get processid /format:csv 2^>nul ^| findstr /r "[0-9]"') do set PID=%%a

if "%PID%"=="" (
    echo [错误] 未找到正在运行的 Flutter 进程
    pause
    exit /b 1
)

REM 在 Windows 上通过 WMIC 发送 Ctrl+Break 信号（相当于 SIGUSR1 触发热加载）
REM 使用 PowerShell 向控制台进程发送信号
powershell -Command "$p = Get-Process -Id %PID%; if ($p) { $p.StandardInput.WriteLine('r'); Write-Host '热加载信号已发送 (PID: %PID%)' } else { Write-Host '进程不存在' }"

if %errorlevel% equ 0 (
    echo [成功] 热加载已触发 (PID: %PID%)
) else (
    echo [错误] 发送信号失败
    pause
    exit /b 1
)
