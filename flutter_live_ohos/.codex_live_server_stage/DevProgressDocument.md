# LiveKit 服务端开发进度

## 目标

- 使用 `docker-compose` 搭建本地可联调的 LiveKit 服务端
- 使用 Go 版本 SDK 实现独立 token 服务
- 支持鸿蒙真机在同一热点/局域网下访问
- 避开本机已占用的 `8080` 端口

## 当前规划

### 服务拆分

- `livekit`：基于官方 `livekit/livekit-server:v1.11.0`
- `token-service`：独立 Go 服务，提供 token 和房间管理接口

### 端口方案

- `7880`：LiveKit 信令和 Room API
- `7881`：LiveKit WebRTC TCP
- `50000-50100/udp`：WebRTC UDP 端口段
- `8091`：Go token 服务

### 局域网访问方案

- 启动脚本自动探测当前电脑默认网络接口的 IPv4
- 自动写入 `LIVEKIT_NODE_IP`
- 鸿蒙设备与电脑接入同一热点后，通过 `ws://<电脑IP>:7880` 访问

## 当前进度

- 已确认 `8080` 端口被本机 Java 进程占用，不再使用
- 已确认现有 Docker 中 `6379`、`3306`、`5672`、`15672` 已被其他业务占用
- 已设计 LiveKit 本地 compose 方案，不依赖现有 Redis
- 已完成目录初始化：`/Users/wujilingtong/SanSheng_Project/liver_server_go`
- 已实现 Go token 服务接口：
  - `GET /health`
  - `GET /status`
  - `GET /status/page`
  - `POST /livekit/token`
  - `GET /livekit/rooms`
  - `POST /livekit/rooms`
  - `DELETE /livekit/rooms/:roomName`
- 已解决容器内 Go 依赖下载超时问题：
  - Docker 构建改为使用 `GOPROXY=https://goproxy.cn,direct`
  - 已补齐 `go.sum`
- 已完成 `docker compose up -d --build`
- 当前联调地址：
  - `LiveKit URL`: `ws://172.20.10.8:7880`
  - `Token URL`: `http://172.20.10.8:8091/livekit/token`
- 已完成本机可用性验证：
  - `GET /health` 返回 `status=ok`
  - `GET /status` 可返回服务端聚合状态
  - `GET /status/page` 可直接在浏览器查看状态页
  - `POST /livekit/token` 可生成房间 token
  - `POST /livekit/rooms` 可成功创建 `demo-room`
- 已规划 Go token 服务接口：
  - 后续再补鉴权、日志、配置分环境

## 下一步

- 使用鸿蒙真机在同一热点下连接 `ws://172.20.10.8:7880`
- 通过 token 接口为真机动态生成联调 token
- 将 Flutter 页面改成直接调用 token 服务，而不是手填 token
- 视长期运营需求补充：
  - 服务端鉴权
  - 业务用户与房间映射
  - 日志与监控
  - 生产环境密钥管理
