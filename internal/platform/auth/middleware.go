package auth

import (
	"context"
	"log/slog"
	"net/http"
	"strings"

	"github.com/savak1990/vk-ahorro/internal/platform/httpx"
)

type contextKey struct{}

var claimsKey contextKey

// Middleware rejects a request without a valid bearer token and stores the
// claims of a valid one in the request context.
func Middleware(v *Verifier) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := bearerToken(r)
			if !ok {
				httpx.WriteError(w, http.StatusUnauthorized, "missing bearer token")
				return
			}
			claims, err := v.Verify(r.Context(), raw)
			if err != nil {
				slog.Warn("rejected token",
					"request_id", httpx.RequestIDFrom(r.Context()), "error", err)
				httpx.WriteError(w, http.StatusUnauthorized, "invalid token")
				return
			}
			next.ServeHTTP(w, r.WithContext(WithClaims(r.Context(), claims)))
		})
	}
}

// WithClaims stores claims in a context, as the middleware does.
func WithClaims(ctx context.Context, claims *Claims) context.Context {
	return context.WithValue(ctx, claimsKey, claims)
}

// ClaimsFrom returns the claims stored by Middleware, or nil.
func ClaimsFrom(ctx context.Context) *Claims {
	claims, _ := ctx.Value(claimsKey).(*Claims)
	return claims
}

func bearerToken(r *http.Request) (string, bool) {
	header := r.Header.Get("Authorization")
	scheme, token, found := strings.Cut(header, " ")
	if !found || !strings.EqualFold(scheme, "Bearer") {
		return "", false
	}
	return strings.TrimSpace(token), true
}
