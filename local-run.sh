#!/bin/bash

set -euo pipefail

echo "=== Local Docker Run (translator) ==="

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker 未安装或不可用，请先安装 Docker Desktop。"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose 不可用，请确认 Docker Desktop 已开启并支持 compose。"
  exit 1
fi

if [ ! -f .env ]; then
  echo "未找到 .env 文件，请创建 .env 并配置 DASHSCOPE_API_KEY。"
  echo "示例：DASHSCOPE_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx"
  exit 1
fi

if ! grep -q "^DASHSCOPE_API_KEY=" .env; then
  echo ".env 中缺少 DASHSCOPE_API_KEY，请补充后重试。"
  exit 1
fi

mkdir -p temp_audio

PORT=${PORT:-8000}

# Some browsers treat certain ports (e.g., 6000) as unsafe.
if [[ "${PORT}" =~ ^(6000|666[5-9]|7[0-9]{3}|1[0-9]{4}|2[0-9]{4}|3[0-9]{4}|4[0-9]{4}|5[0-9]{4}|6[0-9]{4}|7[0-9]{4}|8[0-9]{4}|9[0-9]{4})$ ]]; then
  echo "提示：PORT=${PORT} 可能被浏览器视为不安全端口（ERR_UNSAFE_PORT）。"
  echo "建议使用 6100/8080/9000 等端口。"
fi

echo "Building & starting containers... (HOST PORT=${PORT})"
PORT=${PORT} docker compose -f docker-compose.local.yml up -d --build

echo "=== Done ==="
echo "访问：http://localhost:${PORT}"
echo "监控：http://localhost:${PORT}/monitor"
echo "日志：docker compose -f docker-compose.local.yml logs -f"