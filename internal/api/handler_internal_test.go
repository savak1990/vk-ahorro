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
	helloHandler(Config{})(rec, req)

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

// The stand-in identity must not displace a real one, and must reach the
// response whole when there is no real one.
func TestHelloUsesTheStandInIdentityWithoutClaims(t *testing.T) {
	cfg := Config{
		AuthDisabled:   true,
		AnonymousEmail: "e2e@vk-ahorro.invalid",
		AnonymousSub:   "00000000-0000-0000-0000-000000000000",
	}

	rec := httptest.NewRecorder()
	helloHandler(cfg)(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hello", nil))

	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	if body["message"] != "Hello, e2e@vk-ahorro.invalid" {
		t.Errorf("message = %q", body["message"])
	}
	if body["sub"] != "00000000-0000-0000-0000-000000000000" {
		t.Errorf("sub = %q", body["sub"])
	}
}
