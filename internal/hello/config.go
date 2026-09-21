// Package hello serves the first Ahorro API: a health probe and one greeting
// endpoint behind Cognito authentication.
package hello

import (
	"errors"
	"os"
	"strings"
)

const defaultPort = "8080"

// Config is the whole configuration of the service. It comes from the
// environment only, so a container needs no files.
type Config struct {
	Port               string
	Issuer             string
	ClientID           string
	CORSAllowedOrigins []string
	AuthDisabled       bool
}

// ConfigFromEnv reads the configuration and rejects an incomplete one.
func ConfigFromEnv() (Config, error) {
	cfg := Config{
		Port:               valueOr(os.Getenv("PORT"), defaultPort),
		Issuer:             strings.TrimSuffix(os.Getenv("COGNITO_ISSUER"), "/"),
		ClientID:           os.Getenv("COGNITO_CLIENT_ID"),
		CORSAllowedOrigins: splitList(os.Getenv("CORS_ALLOWED_ORIGINS")),
		AuthDisabled:       os.Getenv("AUTH_DISABLED") == "true",
	}
	if !cfg.AuthDisabled && (cfg.Issuer == "" || cfg.ClientID == "") {
		return Config{}, errors.New("hello: COGNITO_ISSUER and COGNITO_CLIENT_ID are required unless AUTH_DISABLED=true")
	}
	return cfg, nil
}

func valueOr(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func splitList(value string) []string {
	var out []string
	for _, item := range strings.Split(value, ",") {
		if item = strings.TrimSpace(item); item != "" {
			out = append(out, item)
		}
	}
	return out
}
