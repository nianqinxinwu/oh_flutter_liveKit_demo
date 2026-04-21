package main

import (
	"context"
	"encoding/json"
	"errors"
	"html/template"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/livekit/protocol/auth"
	livekit "github.com/livekit/protocol/livekit"
	lksdk "github.com/livekit/server-sdk-go/v2"
)

var statusPageTemplate = template.Must(template.New("status-page").Parse(`
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LiveKit 服务状态</title>
  <meta http-equiv="refresh" content="5">
  <style>
    :root {
      color-scheme: light;
      --bg: #f4f7fb;
      --card: #ffffff;
      --ok: #0f9d58;
      --warn: #d93025;
      --text: #18212f;
      --sub: #5d6b82;
      --line: #dbe4f0;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Segoe UI", sans-serif;
      background: var(--bg);
      color: var(--text);
    }
    .wrap {
      max-width: 960px;
      margin: 0 auto;
      padding: 24px 16px 40px;
    }
    .hero, .card {
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 18px;
      box-shadow: 0 8px 30px rgba(15, 32, 60, 0.06);
    }
    .hero {
      padding: 20px;
      margin-bottom: 16px;
    }
    .hero h1 {
      margin: 0 0 8px;
      font-size: 26px;
    }
    .meta {
      color: var(--sub);
      font-size: 14px;
      line-height: 1.6;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 12px;
      margin-bottom: 16px;
    }
    .card {
      padding: 16px;
    }
    .label {
      color: var(--sub);
      font-size: 13px;
      margin-bottom: 8px;
    }
    .value {
      font-size: 20px;
      font-weight: 700;
      word-break: break-all;
    }
    .pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 12px;
      border-radius: 999px;
      font-size: 14px;
      font-weight: 700;
      margin-bottom: 12px;
    }
    .pill.ok {
      color: var(--ok);
      background: rgba(15, 157, 88, 0.12);
    }
    .pill.warn {
      color: var(--warn);
      background: rgba(217, 48, 37, 0.12);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 18px;
      overflow: hidden;
    }
    th, td {
      text-align: left;
      padding: 14px 16px;
      border-bottom: 1px solid var(--line);
      vertical-align: top;
    }
    th {
      color: var(--sub);
      font-size: 13px;
      font-weight: 600;
      background: #f9fbff;
    }
    tr:last-child td {
      border-bottom: none;
    }
    .ok-text { color: var(--ok); font-weight: 700; }
    .warn-text { color: var(--warn); font-weight: 700; }
    .mono {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <section class="hero">
      <div class="pill {{if eq .Status "ok"}}ok{{else}}warn{{end}}">
        {{if eq .Status "ok"}}服务正常{{else}}服务异常/降级{{end}}
      </div>
      <h1>LiveKit 本地服务状态页</h1>
      <div class="meta">
        当前时间：{{.ServerTime}}<br>
        服务运行时长：{{.Uptime}}<br>
        LiveKit 公网地址：<span class="mono">{{.PublicLiveKitURL}}</span><br>
        Token 服务地址：<span class="mono">{{.TokenServiceURL}}</span>
      </div>
    </section>

    <section class="grid">
      <div class="card">
        <div class="label">活跃房间数</div>
        <div class="value">{{.ActiveRoomCount}}</div>
      </div>
      <div class="card">
        <div class="label">LiveKit API 地址</div>
        <div class="value mono">{{.LiveKitAPIURL}}</div>
      </div>
      <div class="card">
        <div class="label">刷新说明</div>
        <div class="value" style="font-size:16px;font-weight:600;">页面每 5 秒自动刷新</div>
      </div>
    </section>

    <table>
      <thead>
        <tr>
          <th>检查项</th>
          <th>状态</th>
          <th>耗时</th>
          <th>说明</th>
        </tr>
      </thead>
      <tbody>
        {{range .Checks}}
        <tr>
          <td>{{.Name}}</td>
          <td class="{{if eq .Status "ok"}}ok-text{{else}}warn-text{{end}}">{{.Status}}</td>
          <td>{{.Latency}}</td>
          <td class="mono">{{.Detail}}</td>
        </tr>
        {{end}}
      </tbody>
    </table>
  </div>
</body>
</html>
`))

type appConfig struct {
	port              string
	listenAddr        string
	liveKitAPIURL     string
	publicLiveKitURL  string
	apiKey            string
	apiSecret         string
	defaultTTLSeconds int64
}

type app struct {
	cfg        appConfig
	roomClient *lksdk.RoomServiceClient
	httpClient *http.Client
	startedAt  time.Time
}

type tokenRequest struct {
	Room           string `json:"room"`
	Identity       string `json:"identity"`
	Name           string `json:"name"`
	Metadata       string `json:"metadata"`
	TTLSeconds     int64  `json:"ttlSeconds"`
	CanPublish     *bool  `json:"canPublish"`
	CanSubscribe   *bool  `json:"canSubscribe"`
	CanPublishData *bool  `json:"canPublishData"`
}

type createRoomRequest struct {
	Name            string `json:"name"`
	EmptyTimeout    uint32 `json:"emptyTimeout"`
	DepartureTimout uint32 `json:"departureTimeout"`
	MaxParticipants uint32 `json:"maxParticipants"`
	Metadata        string `json:"metadata"`
}

type jsonMessage map[string]any

type statusCheck struct {
	Name      string `json:"name"`
	Status    string `json:"status"`
	Detail    string `json:"detail"`
	LatencyMS int64  `json:"latencyMs"`
}

type statusResponse struct {
	Status           string        `json:"status"`
	ServerTime       string        `json:"serverTime"`
	UptimeSeconds    int64         `json:"uptimeSeconds"`
	PublicLiveKitURL string        `json:"publicLiveKitUrl"`
	TokenServiceURL  string        `json:"tokenServiceUrl"`
	LiveKitAPIURL    string        `json:"livekitApiUrl"`
	ActiveRoomCount  int           `json:"activeRoomCount"`
	Checks           []statusCheck `json:"checks"`
}

type statusPageData struct {
	Status           string
	ServerTime       string
	Uptime           string
	PublicLiveKitURL string
	TokenServiceURL  string
	LiveKitAPIURL    string
	ActiveRoomCount  int
	Checks           []statusPageCheck
}

type statusPageCheck struct {
	Name    string
	Status  string
	Detail  string
	Latency string
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("加载配置失败: %v", err)
	}

	service := &app{
		cfg:        cfg,
		roomClient: lksdk.NewRoomServiceClient(cfg.liveKitAPIURL, cfg.apiKey, cfg.apiSecret),
		httpClient: &http.Client{Timeout: 3 * time.Second},
		startedAt:  time.Now(),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", service.handleHealth)
	mux.HandleFunc("/status", service.handleStatus)
	mux.HandleFunc("/status/page", service.handleStatusPage)
	mux.HandleFunc("/livekit/token", service.handleToken)
	mux.HandleFunc("/livekit/rooms", service.handleRooms)
	mux.HandleFunc("/livekit/rooms/", service.handleRoomByName)

	server := &http.Server{
		Addr:              cfg.listenAddr + ":" + cfg.port,
		Handler:           withCORS(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("token 服务启动: http://%s:%s", cfg.listenAddr, cfg.port)
	log.Printf("客户端 LiveKit URL: %s", cfg.publicLiveKitURL)

	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("token 服务启动失败: %v", err)
	}
}

func loadConfig() (appConfig, error) {
	cfg := appConfig{
		port:             getenv("PORT", "8091"),
		listenAddr:       getenv("LISTEN_ADDR", "0.0.0.0"),
		liveKitAPIURL:    getenv("LIVEKIT_API_URL", "http://livekit:7880"),
		publicLiveKitURL: getenv("PUBLIC_LIVEKIT_URL", "ws://127.0.0.1:7880"),
		apiKey:           strings.TrimSpace(os.Getenv("LIVEKIT_API_KEY")),
		apiSecret:        strings.TrimSpace(os.Getenv("LIVEKIT_API_SECRET")),
	}

	ttlValue := getenv("TOKEN_DEFAULT_TTL_SECONDS", "3600")
	ttlSeconds, err := strconv.ParseInt(ttlValue, 10, 64)
	if err != nil || ttlSeconds <= 0 {
		return appConfig{}, errors.New("TOKEN_DEFAULT_TTL_SECONDS 必须是正整数")
	}
	cfg.defaultTTLSeconds = ttlSeconds

	if cfg.apiKey == "" || cfg.apiSecret == "" {
		return appConfig{}, errors.New("LIVEKIT_API_KEY 和 LIVEKIT_API_SECRET 不能为空")
	}

	return cfg, nil
}

func (a *app) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w, http.MethodGet)
		return
	}

	writeJSON(w, http.StatusOK, jsonMessage{
		"status":           "ok",
		"livekitApiUrl":    a.cfg.liveKitAPIURL,
		"publicLivekitUrl": a.cfg.publicLiveKitURL,
	})
}

func (a *app) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w, http.MethodGet)
		return
	}

	status := a.collectStatus(r.Context(), resolveTokenServiceURL(r))
	code := http.StatusOK
	if status.Status != "ok" {
		code = http.StatusServiceUnavailable
	}
	writeJSON(w, code, status)
}

func (a *app) handleStatusPage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w, http.MethodGet)
		return
	}

	status := a.collectStatus(r.Context(), resolveTokenServiceURL(r))
	pageData := statusPageData{
		Status:           status.Status,
		ServerTime:       status.ServerTime,
		Uptime:           formatUptime(status.UptimeSeconds),
		PublicLiveKitURL: status.PublicLiveKitURL,
		TokenServiceURL:  status.TokenServiceURL,
		LiveKitAPIURL:    status.LiveKitAPIURL,
		ActiveRoomCount:  status.ActiveRoomCount,
		Checks:           make([]statusPageCheck, 0, len(status.Checks)),
	}

	for _, check := range status.Checks {
		pageData.Checks = append(pageData.Checks, statusPageCheck{
			Name:    check.Name,
			Status:  check.Status,
			Detail:  check.Detail,
			Latency: formatLatency(check.LatencyMS),
		})
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := statusPageTemplate.Execute(w, pageData); err != nil {
		http.Error(w, "渲染状态页失败", http.StatusInternalServerError)
	}
}

func (a *app) collectStatus(ctx context.Context, tokenServiceURL string) statusResponse {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	checks := make([]statusCheck, 0, 3)
	checks = append(checks, statusCheck{
		Name:      "token-service",
		Status:    "ok",
		Detail:    "Go token 服务进程正常响应",
		LatencyMS: 0,
	})

	httpCheck := a.checkLiveKitHTTP(ctx)
	checks = append(checks, httpCheck)

	roomCheck, activeRoomCount := a.checkLiveKitRoomService(ctx)
	checks = append(checks, roomCheck)

	overallStatus := "ok"
	for _, item := range checks {
		if item.Status != "ok" {
			overallStatus = "degraded"
			break
		}
	}

	return statusResponse{
		Status:           overallStatus,
		ServerTime:       time.Now().Format(time.RFC3339),
		UptimeSeconds:    int64(time.Since(a.startedAt).Seconds()),
		PublicLiveKitURL: a.cfg.publicLiveKitURL,
		TokenServiceURL:  tokenServiceURL,
		LiveKitAPIURL:    a.cfg.liveKitAPIURL,
		ActiveRoomCount:  activeRoomCount,
		Checks:           checks,
	}
}

func (a *app) checkLiveKitHTTP(ctx context.Context) statusCheck {
	startedAt := time.Now()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.cfg.liveKitAPIURL, nil)
	if err != nil {
		return statusCheck{
			Name:      "livekit-http",
			Status:    "error",
			Detail:    "创建请求失败: " + err.Error(),
			LatencyMS: elapsedMilliseconds(startedAt),
		}
	}

	resp, err := a.httpClient.Do(req)
	if err != nil {
		return statusCheck{
			Name:      "livekit-http",
			Status:    "error",
			Detail:    "HTTP 探活失败: " + err.Error(),
			LatencyMS: elapsedMilliseconds(startedAt),
		}
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return statusCheck{
			Name:      "livekit-http",
			Status:    "error",
			Detail:    "HTTP 返回异常状态码: " + strconv.Itoa(resp.StatusCode),
			LatencyMS: elapsedMilliseconds(startedAt),
		}
	}

	return statusCheck{
		Name:      "livekit-http",
		Status:    "ok",
		Detail:    "LiveKit HTTP 信令入口可达",
		LatencyMS: elapsedMilliseconds(startedAt),
	}
}

func (a *app) checkLiveKitRoomService(ctx context.Context) (statusCheck, int) {
	startedAt := time.Now()
	resp, err := a.roomClient.ListRooms(ctx, &livekit.ListRoomsRequest{})
	if err != nil {
		return statusCheck{
			Name:      "livekit-roomservice",
			Status:    "error",
			Detail:    "RoomService 调用失败: " + err.Error(),
			LatencyMS: elapsedMilliseconds(startedAt),
		}, 0
	}

	roomCount := len(resp.Rooms)
	return statusCheck{
		Name:      "livekit-roomservice",
		Status:    "ok",
		Detail:    "RoomService 正常，当前活跃房间数: " + strconv.Itoa(roomCount),
		LatencyMS: elapsedMilliseconds(startedAt),
	}, roomCount
}

func (a *app) handleToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w, http.MethodPost)
		return
	}

	var req tokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, jsonMessage{"error": "请求体不是合法 JSON"})
		return
	}

	req.Room = strings.TrimSpace(req.Room)
	req.Identity = strings.TrimSpace(req.Identity)
	req.Name = strings.TrimSpace(req.Name)

	if req.Room == "" || req.Identity == "" {
		writeJSON(w, http.StatusBadRequest, jsonMessage{"error": "room 和 identity 不能为空"})
		return
	}

	grant := &auth.VideoGrant{
		RoomJoin:       true,
		Room:           req.Room,
		CanPublish:     boolPtrValue(req.CanPublish, true),
		CanSubscribe:   boolPtrValue(req.CanSubscribe, true),
		CanPublishData: boolPtrValue(req.CanPublishData, true),
	}

	token := auth.NewAccessToken(a.cfg.apiKey, a.cfg.apiSecret)
	token.SetVideoGrant(grant).
		SetIdentity(req.Identity).
		SetValidFor(time.Duration(ttlSeconds(req.TTLSeconds, a.cfg.defaultTTLSeconds)) * time.Second)

	if req.Name != "" {
		token.SetName(req.Name)
	}
	if req.Metadata != "" {
		token.SetMetadata(req.Metadata)
	}

	jwt, err := token.ToJWT()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, jsonMessage{"error": "生成 token 失败", "detail": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, jsonMessage{
		"token":      jwt,
		"room":       req.Room,
		"identity":   req.Identity,
		"wsUrl":      a.cfg.publicLiveKitURL,
		"expiresIn":  ttlSeconds(req.TTLSeconds, a.cfg.defaultTTLSeconds),
		"serverTime": time.Now().Format(time.RFC3339),
	})
}

func (a *app) handleRooms(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		resp, err := a.roomClient.ListRooms(r.Context(), &livekit.ListRoomsRequest{})
		if err != nil {
			writeJSON(w, http.StatusBadGateway, jsonMessage{"error": "查询房间失败", "detail": err.Error()})
			return
		}
		writeJSON(w, http.StatusOK, resp)
	case http.MethodPost:
		var req createRoomRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, jsonMessage{"error": "请求体不是合法 JSON"})
			return
		}

		req.Name = strings.TrimSpace(req.Name)
		if req.Name == "" {
			writeJSON(w, http.StatusBadRequest, jsonMessage{"error": "name 不能为空"})
			return
		}

		room, err := a.roomClient.CreateRoom(context.Background(), &livekit.CreateRoomRequest{
			Name:             req.Name,
			EmptyTimeout:     req.EmptyTimeout,
			DepartureTimeout: req.DepartureTimout,
			MaxParticipants:  req.MaxParticipants,
			Metadata:         req.Metadata,
		})
		if err != nil {
			writeJSON(w, http.StatusBadGateway, jsonMessage{"error": "创建房间失败", "detail": err.Error()})
			return
		}

		writeJSON(w, http.StatusCreated, room)
	default:
		writeMethodNotAllowed(w, http.MethodGet, http.MethodPost)
	}
}

func (a *app) handleRoomByName(w http.ResponseWriter, r *http.Request) {
	roomName := strings.TrimPrefix(r.URL.Path, "/livekit/rooms/")
	roomName = strings.TrimSpace(roomName)
	if roomName == "" {
		writeJSON(w, http.StatusBadRequest, jsonMessage{"error": "roomName 不能为空"})
		return
	}

	if r.Method != http.MethodDelete {
		writeMethodNotAllowed(w, http.MethodDelete)
		return
	}

	resp, err := a.roomClient.DeleteRoom(r.Context(), &livekit.DeleteRoomRequest{Room: roomName})
	if err != nil {
		writeJSON(w, http.StatusBadGateway, jsonMessage{"error": "删除房间失败", "detail": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, statusCode int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("写入响应失败: %v", err)
	}
}

func writeMethodNotAllowed(w http.ResponseWriter, methods ...string) {
	w.Header().Set("Allow", strings.Join(methods, ", "))
	writeJSON(w, http.StatusMethodNotAllowed, jsonMessage{"error": "请求方法不支持"})
}

func getenv(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func boolValue(value *bool, fallback bool) bool {
	if value == nil {
		return fallback
	}
	return *value
}

func boolPtrValue(value *bool, fallback bool) *bool {
	result := boolValue(value, fallback)
	return &result
}

func ttlSeconds(value int64, fallback int64) int64 {
	if value > 0 {
		return value
	}
	return fallback
}

func elapsedMilliseconds(startedAt time.Time) int64 {
	return time.Since(startedAt).Milliseconds()
}

func formatUptime(seconds int64) string {
	duration := time.Duration(seconds) * time.Second
	if duration < time.Minute {
		return duration.String()
	}
	duration = duration.Round(time.Second)
	return duration.String()
}

func formatLatency(milliseconds int64) string {
	return strconv.FormatInt(milliseconds, 10) + "ms"
}

func resolveTokenServiceURL(r *http.Request) string {
	host := strings.TrimSpace(r.Host)
	if host == "" {
		host = "127.0.0.1:8091"
	}
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	return scheme + "://" + host
}
