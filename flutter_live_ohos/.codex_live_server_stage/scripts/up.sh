#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
EXAMPLE_FILE="$ROOT_DIR/.env.example"

cd "$ROOT_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$EXAMPLE_FILE" "$ENV_FILE"
fi

detect_ip() {
  local default_iface current_ip
  default_iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}' | head -n 1)"
  if [[ -n "${default_iface:-}" ]]; then
    current_ip="$(ipconfig getifaddr "$default_iface" 2>/dev/null || true)"
    if [[ -n "${current_ip:-}" ]]; then
      echo "$current_ip"
      return 0
    fi
  fi

  ifconfig | awk '
    /inet / && $2 != "127.0.0.1" && $2 !~ /^169\.254\./ {
      print $2
      exit
    }
  '
}

CURRENT_IP="$(detect_ip)"

if [[ -z "${CURRENT_IP:-}" ]]; then
  echo "未能自动探测到局域网 IPv4，请手动编辑 .env 中的 LIVEKIT_NODE_IP。"
  exit 1
fi

perl -0pi -e "s/^LIVEKIT_NODE_IP=.*/LIVEKIT_NODE_IP=${CURRENT_IP}/m" "$ENV_FILE"
perl -0pi -e "s#^PUBLIC_LIVEKIT_URL=.*#PUBLIC_LIVEKIT_URL=ws://${CURRENT_IP}:7880#m" "$ENV_FILE"

echo "当前局域网 IP: ${CURRENT_IP}"
echo "即将启动 LiveKit 和 Go Token 服务..."

docker compose up -d --build

echo
echo "服务已提交启动，请检查："
echo "LiveKit URL: ws://${CURRENT_IP}:7880"
echo "Token URL:   http://${CURRENT_IP}:8091/livekit/token"
