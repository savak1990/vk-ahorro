package api

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"time"
)

const shutdownTimeout = 10 * time.Second

// Run serves until the context is cancelled, then drains connections within
// the shutdown budget Kubernetes allows between SIGTERM and SIGKILL.
func Run(ctx context.Context, cfg Config, logger *slog.Logger) error {
	if cfg.AuthDisabled {
		logger.Warn("AUTH_DISABLED is set: every request is anonymous, local development only")
	}

	listener, err := net.Listen("tcp", ":"+cfg.Port)
	if err != nil {
		return fmt.Errorf("ahorro-api: listening on port %s: %w", cfg.Port, err)
	}

	srv := &http.Server{
		Handler:           NewHandler(ctx, cfg, logger),
		ReadHeaderTimeout: 10 * time.Second,
	}

	serveErr := make(chan error, 1)
	go func() {
		logger.Info("listening", "address", listener.Addr().String())
		serveErr <- srv.Serve(listener)
	}()

	select {
	case err := <-serveErr:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return fmt.Errorf("ahorro-api: serving: %w", err)
	case <-ctx.Done():
	}

	logger.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), shutdownTimeout)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("ahorro-api: shutting down: %w", err)
	}
	return nil
}
