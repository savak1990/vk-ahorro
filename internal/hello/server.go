package hello

import (
	"context"
	"log/slog"
	"net/http"

	"github.com/savak1990/vk-ahorro/internal/platform/auth"
	"github.com/savak1990/vk-ahorro/internal/platform/httpx"
)

// NewHandler builds the routes and the middleware chain. The context bounds
// the lifetime of the JWKS background refresh.
func NewHandler(ctx context.Context, cfg Config, logger *slog.Logger) http.Handler {
	protect := passThrough
	if !cfg.AuthDisabled {
		protect = auth.Middleware(auth.NewVerifier(ctx, cfg.Issuer, cfg.ClientID))
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handleHealthz)
	mux.Handle("GET /api/v1/hello", protect(http.HandlerFunc(handleHello)))

	return httpx.RequestID(httpx.Logging(logger)(httpx.CORS(cfg.CORSAllowedOrigins)(mux)))
}

func passThrough(next http.Handler) http.Handler { return next }
