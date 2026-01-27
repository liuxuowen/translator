#!/bin/bash

set -euo pipefail

echo "=== Stop Local Docker (translator) ==="

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker 未安装或不可用。"
  exit 1
fi

docker compose -f docker-compose.local.yml down --remove-orphans

echo "=== Done ==="