package hello

import (
	"net/http"

	"github.com/savak1990/vk-ahorro/internal/platform/auth"
	"github.com/savak1990/vk-ahorro/internal/platform/httpx"
)

const anonymous = "anonymous"

func handleHealthz(w http.ResponseWriter, _ *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func handleHello(w http.ResponseWriter, r *http.Request) {
	name, sub := anonymous, ""
	if claims := auth.ClaimsFrom(r.Context()); claims != nil {
		name, sub = claims.Email, claims.Subject
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]string{
		"message": "Hello, " + name,
		"sub":     sub,
	})
}
