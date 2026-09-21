package httpx

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/http"
)

// HeaderRequestID is the header carrying the request id in and out.
const HeaderRequestID = "X-Request-Id"

type contextKey struct{}

var requestIDKey contextKey

// RequestID echoes an incoming request id or generates one, puts it in the
// request context, and sets it on the response before the handler runs.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get(HeaderRequestID)
		if id == "" {
			id = newRequestID()
		}
		w.Header().Set(HeaderRequestID, id)
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), requestIDKey, id)))
	})
}

// RequestIDFrom returns the request id stored by RequestID, or "".
func RequestIDFrom(ctx context.Context) string {
	id, _ := ctx.Value(requestIDKey).(string)
	return id
}

func newRequestID() string {
	var b [16]byte
	rand.Read(b[:])
	return hex.EncodeToString(b[:])
}
