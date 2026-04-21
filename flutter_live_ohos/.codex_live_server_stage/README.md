# LiveKit 本地联调服务

这个目录用于启动一套适合局域网联调的 LiveKit 本地服务，包含：

- `livekit`：媒体服务主体，运行在 Docker 中
- `token-service`：Go 版 token/room API 服务
- `scripts/up.sh`：自动探测当前局域网 IP 并启动 `docker compose`

## 端口规划

- `7880`：LiveKit WebSocket / Room API
- `7881`：LiveKit WebRTC TCP 回退端口
- `50000-50100/udp`：LiveKit WebRTC UDP 端口段
- `8091`：Go token 服务

`8080` 已被本机 Java 进程占用，因此 token 服务改为 `8091`。

## 快速启动

```bash
cd /Users/wujilingtong/SanSheng_Project/liver_server_go
chmod +x scripts/up.sh
./scripts/up.sh
```

脚本会优先尝试探测当前默认网络接口的 IPv4，并写入 `.env` 中的 `LIVEKIT_NODE_IP`，用于局域网访问。

## 鸿蒙端联调填写

- `LiveKit URL`: `ws://<你的电脑局域网IP>:7880`
- `Token 接口`: `http://<你的电脑局域网IP>:8091/livekit/token`
- `状态 JSON`: `http://<你的电脑局域网IP>:8091/status`
- `状态页面`: `http://<你的电脑局域网IP>:8091/status/page`

示例：

```bash
curl -X POST http://127.0.0.1:8091/livekit/token \
  -H 'Content-Type: application/json' \
  -d '{"room":"demo-room","identity":"ohos-device-01"}'
```

```bash
curl -s http://127.0.0.1:8091/status | jq
```

## 说明

- 当前方案面向本地联调，`LIVEKIT_API_KEY` 和 `LIVEKIT_API_SECRET` 通过 `.env` 管理。
- 若热点网络切换导致电脑局域网 IP 变化，重新执行一次 `./scripts/up.sh` 即可刷新配置。
