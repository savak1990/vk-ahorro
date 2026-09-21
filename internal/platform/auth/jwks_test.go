package auth_test

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	jose "github.com/go-jose/go-jose/v4"
)

const testKeyID = "test-key"

// fakePool is a Cognito-shaped issuer: it serves a JWKS and signs tokens with
// the matching key.
type fakePool struct {
	url    string
	key    *rsa.PrivateKey
	otherK *rsa.PrivateKey
}

func newFakePool(t *testing.T) *fakePool {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generating key: %v", err)
	}
	other, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generating second key: %v", err)
	}
	pool := &fakePool{key: key, otherK: other}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /.well-known/jwks.json", func(w http.ResponseWriter, _ *http.Request) {
		set := jose.JSONWebKeySet{Keys: []jose.JSONWebKey{{
			Key:       key.Public(),
			KeyID:     testKeyID,
			Algorithm: string(jose.RS256),
			Use:       "sig",
		}}}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(set); err != nil {
			t.Errorf("encoding jwks: %v", err)
		}
	})
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	pool.url = srv.URL
	return pool
}

type claims map[string]any

// idToken returns the claim set Cognito puts in an id token.
func (p *fakePool) idClaims(clientID string) claims {
	return claims{
		"iss":       p.url,
		"sub":       "11111111-2222-3333-4444-555555555555",
		"aud":       clientID,
		"token_use": "id",
		"email":     "user@example.com",
		"exp":       time.Now().Add(time.Hour).Unix(),
		"iat":       time.Now().Unix(),
	}
}

// accessClaims returns the claim set Cognito puts in an access token.
func (p *fakePool) accessClaims(clientID string) claims {
	return claims{
		"iss":       p.url,
		"sub":       "11111111-2222-3333-4444-555555555555",
		"client_id": clientID,
		"token_use": "access",
		"username":  "user@example.com",
		"exp":       time.Now().Add(time.Hour).Unix(),
		"iat":       time.Now().Unix(),
	}
}

func (p *fakePool) sign(t *testing.T, c claims) string {
	t.Helper()
	return p.signWith(t, p.key, c)
}

func (p *fakePool) signWrongKey(t *testing.T, c claims) string {
	t.Helper()
	return p.signWith(t, p.otherK, c)
}

func (p *fakePool) signWith(t *testing.T, key *rsa.PrivateKey, c claims) string {
	t.Helper()
	signer, err := jose.NewSigner(
		jose.SigningKey{Algorithm: jose.RS256, Key: key},
		(&jose.SignerOptions{}).WithType("JWT").WithHeader(jose.HeaderKey("kid"), testKeyID),
	)
	if err != nil {
		t.Fatalf("building signer: %v", err)
	}
	payload, err := json.Marshal(c)
	if err != nil {
		t.Fatalf("marshalling claims: %v", err)
	}
	obj, err := signer.Sign(payload)
	if err != nil {
		t.Fatalf("signing: %v", err)
	}
	raw, err := obj.CompactSerialize()
	if err != nil {
		t.Fatalf("serializing: %v", err)
	}
	return raw
}
