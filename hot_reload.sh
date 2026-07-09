#!/bin/bash
# 触发热加载 (Hot Reload) — 向 Flutter 进程发送 SIGUSR1 信号
# 用法: ./hot_reload.sh

PID=$(ps aux | grep "flutter_tools.snapshot run" | grep -v grep | awk '{print $2}')

if [ -z "$PID" ]; then
  echo "❌ 未找到正在运行的 Flutter 进程"
  exit 1
fi

kill -SIGUSR1 "$PID" 2>/dev/null
if [ $? -eq 0 ]; then
  echo "✅ 热加载已触发 (PID: $PID)"
else
  echo "❌ 发送信号失败"
  exit 1
fi
