package hello_test

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/savak1990/vk-ahorro/internal/hello"
)

func quietLogger() *slog.Logger {
	return slog.New(slog.NewJSONHandler(io.Discard, nil))
}

func TestHealthzIsOpen(t *testing.T) {
	h := hello.NewHandler(context.Background(), hello.Config{AuthDisabled: true}, quietLogger())

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("status field = %q", body["status"])
	}
	if rec.Header().Get("X-Request-Id") == "" {
		t.Error("no X-Request-Id on the response")
	}
}

func TestHelloWithAuthDisabled(t *testing.T) {
	h := hello.NewHandler(context.Background(), hello.Config{AuthDisabled: true}, quietLogger())

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hello", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	if body["message"] != "Hello, anonymous" {
		t.Errorf("message = %q", body["message"])
	}
}

func TestHelloNeedsATokenWhenAuthIsOn(t *testing.T) {
	cfg := hello.Config{
		Issuer:   "https://cognito-idp.eu-west-1.amazonaws.com/eu-west-1_abc",
		ClientID: "client-1",
	}
	h := hello.NewHandler(context.Background(), cfg, quietLogger())

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hello", nil))

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestCORSHeaderOnAllowedOrigin(t *testing.T) {
	cfg := hello.Config{AuthDisabled: true, CORSAllowedOrigins: []string{"https://ahorro.example"}}
	h := hello.NewHandler(context.Background(), cfg, quietLogger())

	req := httptest.NewRequest(http.MethodGet, "/api/v1/hello", nil)
	req.Header.Set("Origin", "https://ahorro.example")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "https://ahorro.example" {
		t.Fatalf("allow-origin = %q", got)
	}
}

func TestUnknownPathIs404(t *testing.T) {
	h := hello.NewHandler(context.Background(), hello.Config{AuthDisabled: true}, quietLogger())

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/nope", nil))

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
}
