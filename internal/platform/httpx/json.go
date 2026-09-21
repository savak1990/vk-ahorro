package httpx

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// WriteJSON writes v as a JSON body with the given status code.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("writing json response", "error", err)
	}
}

// WriteError writes a JSON error body with the given status code.
func WriteError(w http.ResponseWriter, status int, message string) {
	WriteJSON(w, status, map[string]string{"error": message})
}
