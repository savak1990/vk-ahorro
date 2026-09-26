package api_test

import (
	"slices"
	"testing"

	"github.com/savak1990/vk-ahorro/internal/api"
)

// clearEnv sets every variable the config reads, so a value inherited from the
// caller's environment cannot change the result.
func clearEnv(t *testing.T) {
	t.Helper()
	for _, name := range []string{"PORT", "COGNITO_ISSUER", "COGNITO_CLIENT_ID", "CORS_ALLOWED_ORIGINS", "AUTH_DISABLED"} {
		t.Setenv(name, "")
	}
}

func TestConfigFromEnvDefaults(t *testing.T) {
	clearEnv(t)
	t.Setenv("COGNITO_ISSUER", "https://cognito-idp.eu-west-1.amazonaws.com/eu-west-1_abc")
	t.Setenv("COGNITO_CLIENT_ID", "client-1")

	cfg, err := api.ConfigFromEnv()
	if err != nil {
		t.Fatalf("ConfigFromEnv() error = %v", err)
	}
	if cfg.Port != "8080" {
		t.Errorf("port = %q, want 8080", cfg.Port)
	}
	if cfg.AuthDisabled {
		t.Errorf("auth is disabled by default")
	}
	if len(cfg.CORSAllowedOrigins) != 0 {
		t.Errorf("origins = %v, want none", cfg.CORSAllowedOrigins)
	}
}

func TestConfigFromEnvReadsAll(t *testing.T) {
	clearEnv(t)
	t.Setenv("PORT", "9090")
	t.Setenv("COGNITO_ISSUER", "https://cognito-idp.eu-west-1.amazonaws.com/eu-west-1_abc/")
	t.Setenv("COGNITO_CLIENT_ID", "client-1")
	t.Setenv("CORS_ALLOWED_ORIGINS", "https://a.example, https://b.example ")

	cfg, err := api.ConfigFromEnv()
	if err != nil {
		t.Fatalf("ConfigFromEnv() error = %v", err)
	}
	if cfg.Port != "9090" {
		t.Errorf("port = %q", cfg.Port)
	}
	if cfg.Issuer != "https://cognito-idp.eu-west-1.amazonaws.com/eu-west-1_abc" {
		t.Errorf("issuer = %q, want the trailing slash removed", cfg.Issuer)
	}
	want := []string{"https://a.example", "https://b.example"}
	if !slices.Equal(cfg.CORSAllowedOrigins, want) {
		t.Errorf("origins = %v, want %v", cfg.CORSAllowedOrigins, want)
	}
}

func TestConfigFromEnvRequiresCognitoUnlessAuthDisabled(t *testing.T) {
	clearEnv(t)
	t.Setenv("COGNITO_ISSUER", "")
	t.Setenv("COGNITO_CLIENT_ID", "")

	if _, err := api.ConfigFromEnv(); err == nil {
		t.Fatal("ConfigFromEnv() accepted an empty issuer while auth is on")
	}

	t.Setenv("AUTH_DISABLED", "true")
	cfg, err := api.ConfigFromEnv()
	if err != nil {
		t.Fatalf("ConfigFromEnv() error = %v", err)
	}
	if !cfg.AuthDisabled {
		t.Error("AUTH_DISABLED=true was not read")
	}
}
