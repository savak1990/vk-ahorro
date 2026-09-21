package httpx_test

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/savak1990/vk-ahorro/internal/platform/httpx"
)

func TestWriteJSON(t *testing.T) {
	rec := httptest.NewRecorder()
	httpx.WriteJSON(rec, http.StatusCreated, map[string]string{"status": "ok"})

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusCreated)
	}
	if got := rec.Header().Get("Content-Type"); got != "application/json" {
		t.Fatalf("content type = %q, want application/json", got)
	}
	if got := strings.TrimSpace(rec.Body.String()); got != `{"status":"ok"}` {
		t.Fatalf("body = %q", got)
	}
}

func TestWriteError(t *testing.T) {
	rec := httptest.NewRecorder()
	httpx.WriteError(rec, http.StatusUnauthorized, "unauthorized")

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	if body["error"] != "unauthorized" {
		t.Fatalf("error = %q, want unauthorized", body["error"])
	}
}

func TestRequestIDEchoesIncoming(t *testing.T) {
	var seen string
	h := httpx.RequestID(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		seen = httpx.RequestIDFrom(r.Context())
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("X-Request-Id", "abc123")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if seen != "abc123" {
		t.Fatalf("context id = %q, want abc123", seen)
	}
	if got := rec.Header().Get("X-Request-Id"); got != "abc123" {
		t.Fatalf("response id = %q, want abc123", got)
	}
}

func TestRequestIDGeneratesWhenAbsent(t *testing.T) {
	h := httpx.RequestID(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {}))

	first := httptest.NewRecorder()
	h.ServeHTTP(first, httptest.NewRequest(http.MethodGet, "/", nil))
	second := httptest.NewRecorder()
	h.ServeHTTP(second, httptest.NewRequest(http.MethodGet, "/", nil))

	a := first.Header().Get("X-Request-Id")
	b := second.Header().Get("X-Request-Id")
	if a == "" || b == "" {
		t.Fatalf("empty generated id: %q %q", a, b)
	}
	if a == b {
		t.Fatalf("ids are not unique: %q", a)
	}
}

func TestRequestIDFromEmptyContext(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	if got := httpx.RequestIDFrom(req.Context()); got != "" {
		t.Fatalf("id = %q, want empty", got)
	}
}

func TestCORSAllowedOrigin(t *testing.T) {
	h := httpx.CORS([]string{"https://ahorro.example", "http://localhost:3000"})(
		http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) }))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Origin", "http://localhost:3000")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:3000" {
		t.Fatalf("allow-origin = %q", got)
	}
	if got := rec.Header().Get("Vary"); !strings.Contains(got, "Origin") {
		t.Fatalf("vary = %q, want Origin", got)
	}
}

func TestCORSRejectsUnknownOrigin(t *testing.T) {
	h := httpx.CORS([]string{"https://ahorro.example"})(
		http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) }))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Origin", "https://evil.example")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("allow-origin = %q, want empty", got)
	}
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200: the request itself is not blocked", rec.Code)
	}
}

func TestCORSPreflight(t *testing.T) {
	h := httpx.CORS([]string{"https://ahorro.example"})(
		http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusTeapot) }))

	req := httptest.NewRequest(http.MethodOptions, "/api/v1/hello", nil)
	req.Header.Set("Origin", "https://ahorro.example")
	req.Header.Set("Access-Control-Request-Method", http.MethodGet)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want 204 without reaching the handler", rec.Code)
	}
	if got := rec.Header().Get("Access-Control-Allow-Headers"); !strings.Contains(got, "Authorization") {
		t.Fatalf("allow-headers = %q, want Authorization", got)
	}
}

func TestLoggingRecordsRequest(t *testing.T) {
	var buf bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&buf, nil))
	h := httpx.RequestID(httpx.Logging(logger)(
		http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusTeapot) })))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/hello", nil)
	req.Header.Set("X-Request-Id", "log-1")
	h.ServeHTTP(httptest.NewRecorder(), req)

	var line map[string]any
	if err := json.Unmarshal(buf.Bytes(), &line); err != nil {
		t.Fatalf("log line is not JSON: %v (%q)", err, buf.String())
	}
	for k, want := range map[string]any{
		"request_id": "log-1",
		"method":     http.MethodGet,
		"path":       "/api/v1/hello",
		"status":     float64(http.StatusTeapot),
	} {
		if line[k] != want {
			t.Errorf("log %s = %v, want %v", k, line[k], want)
		}
	}
	if _, ok := line["duration_ms"]; !ok {
		t.Errorf("log has no duration_ms: %v", line)
	}
}
