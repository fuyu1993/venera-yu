#!/usr/bin/env bash
# 热启动 venera 的 macOS 应用
# 用法: ./run_macos.sh
# 启动后支持: r=热重载, R=热重启, h=帮助, d=分离, q=退出
# 说明: Flutter 退出后保持交互式 shell 打开，避免命令窗口自动关闭
cd "$(dirname "$0")"

flutter run -d macos

# Flutter 退出后保持命令窗口打开（进入交互式 shell），按 exit 可关闭
exec "$SHELL"
