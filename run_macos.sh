#!/usr/bin/env bash
# 热启动 venera 的 macOS 应用
# 用法: ./run_macos.sh
# 启动后支持: r=热重载, R=热重启, h=帮助, d=分离, q=退出
set -e
cd "$(dirname "$0")"
flutter run -d macos
