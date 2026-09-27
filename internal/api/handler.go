package api

import (
	"net/http"

	"github.com/savak1990/vk-ahorro/internal/platform/auth"
	"github.com/savak1990/vk-ahorro/internal/platform/httpx"
)

func handleHealthz(w http.ResponseWriter, _ *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// helloHandler greets the verified user, or the stand-in identity that a
// target with no identity provider configures.
func helloHandler(cfg Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Defaulted here as well as in the config, so a Config built in code
		// rather than read from the environment still greets by a name.
		name, sub := valueOr(cfg.AnonymousEmail, defaultAnonymousEmail), cfg.AnonymousSub
		if claims := auth.ClaimsFrom(r.Context()); claims != nil {
			name, sub = claims.Email, claims.Subject
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]string{
			"message": "Hello, " + name,
			"sub":     sub,
		})
	}
}
