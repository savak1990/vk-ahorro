package auth_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/savak1990/vk-ahorro/internal/platform/auth"
)

const clientID = "4jnf5pcfr7gvo2vseif36bu6k"

func TestVerifyAcceptsIDToken(t *testing.T) {
	pool := newFakePool(t)
	v := auth.NewVerifier(context.Background(), pool.url, clientID)

	got, err := v.Verify(context.Background(), pool.sign(t, pool.idClaims(clientID)))
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if got.Email != "user@example.com" {
		t.Errorf("email = %q", got.Email)
	}
	if got.Subject != "11111111-2222-3333-4444-555555555555" {
		t.Errorf("sub = %q", got.Subject)
	}
}

func TestVerifyAcceptsAccessToken(t *testing.T) {
	pool := newFakePool(t)
	v := auth.NewVerifier(context.Background(), pool.url, clientID)

	got, err := v.Verify(context.Background(), pool.sign(t, pool.accessClaims(clientID)))
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if got.Email != "user@example.com" {
		t.Errorf("email = %q, want the username claim", got.Email)
	}
}

func TestVerifyPrefersTheEmailClaimOverUsername(t *testing.T) {
	pool := newFakePool(t)
	v := auth.NewVerifier(context.Background(), pool.url, clientID)

	c := pool.accessClaims(clientID)
	c["username"] = "5ec1f2a0-0000-4000-8000-000000000000"
	c["email"] = "user@example.com"

	got, err := v.Verify(context.Background(), pool.sign(t, c))
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if got.Email != "user@example.com" {
		t.Fatalf("email = %q, want the email claim, not the username uuid", got.Email)
	}
}

func TestVerifyRejects(t *testing.T) {
	pool := newFakePool(t)
	v := auth.NewVerifier(context.Background(), pool.url, clientID)

	expired := pool.idClaims(clientID)
	expired["exp"] = time.Now().Add(-time.Minute).Unix()

	wrongAudience := pool.idClaims("some-other-client")
	wrongClient := pool.accessClaims("some-other-client")

	unknownUse := pool.idClaims(clientID)
	unknownUse["token_use"] = "refresh"

	wrongIssuer := pool.idClaims(clientID)
	wrongIssuer["iss"] = "https://cognito-idp.eu-west-1.amazonaws.com/eu-west-1_other"

	tests := map[string]string{
		"empty":          "",
		"malformed":      "not-a-jwt",
		"bad signature":  pool.signWrongKey(t, pool.idClaims(clientID)),
		"expired":        pool.sign(t, expired),
		"wrong audience": pool.sign(t, wrongAudience),
		"wrong client":   pool.sign(t, wrongClient),
		"unknown use":    pool.sign(t, unknownUse),
		"wrong issuer":   pool.sign(t, wrongIssuer),
	}

	for name, token := range tests {
		t.Run(name, func(t *testing.T) {
			if _, err := v.Verify(context.Background(), token); err == nil {
				t.Fatalf("Verify() accepted a %s token", name)
			}
		})
	}
}

func TestMiddlewareRejectsMissingHeader(t *testing.T) {
	pool := newFakePool(t)
	v := auth.NewVerifier(context.Background(), pool.url, clientID)
	h := auth.Middleware(v)(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		t.Fatal("handler ran without a token")
	}))

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hello", nil))

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestMiddlewareRejectsNonBearerScheme(t *testing.T) {
	pool := newFakePool(t)
	v := auth.NewVerifier(context.Background(), pool.url, clientID)
	h := auth.Middleware(v)(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		t.Fatal("handler ran with a non-bearer header")
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/hello", nil)
	req.Header.Set("Authorization", "Basic "+pool.sign(t, pool.idClaims(clientID)))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestMiddlewarePassesClaims(t *testing.T) {
	pool := newFakePool(t)
	v := auth.NewVerifier(context.Background(), pool.url, clientID)

	var seen *auth.Claims
	h := auth.Middleware(v)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen = auth.ClaimsFrom(r.Context())
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/hello", nil)
	req.Header.Set("Authorization", "Bearer "+pool.sign(t, pool.idClaims(clientID)))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if seen == nil || seen.Email != "user@example.com" {
		t.Fatalf("claims = %+v", seen)
	}
}

func TestClaimsFromEmptyContext(t *testing.T) {
	if got := auth.ClaimsFrom(context.Background()); got != nil {
		t.Fatalf("claims = %+v, want nil", got)
	}
}
