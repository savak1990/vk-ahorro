package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/savak1990/vk-ahorro/internal/platform/auth"
)

func TestHelloUsesTheVerifiedClaims(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/v1/hello", nil)
	req = req.WithContext(auth.WithClaims(req.Context(),
		&auth.Claims{Subject: "sub-1", Email: "user@example.com"}))

	rec := httptest.NewRecorder()
	handleHello(rec, req)

	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	if body["message"] != "Hello, user@example.com" {
		t.Errorf("message = %q", body["message"])
	}
	if body["sub"] != "sub-1" {
		t.Errorf("sub = %q", body["sub"])
	}
}
