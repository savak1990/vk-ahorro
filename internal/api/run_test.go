package api_test

import (
	"bytes"
	"context"
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/savak1990/vk-ahorro/internal/api"
)

func TestRunStopsWhenTheContextIsCancelled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- api.Run(ctx, api.Config{Port: "0", AuthDisabled: true}, quietLogger()) }()

	time.Sleep(50 * time.Millisecond)
	cancel()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("Run() error = %v", err)
		}
	case <-time.After(10 * time.Second):
		t.Fatal("Run() did not return within the 10 s shutdown budget")
	}
}

func TestRunWarnsWhenAuthIsDisabled(t *testing.T) {
	var buf bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&buf, &slog.HandlerOptions{Level: slog.LevelWarn}))

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- api.Run(ctx, api.Config{Port: "0", AuthDisabled: true}, logger) }()
	time.Sleep(50 * time.Millisecond)
	cancel()
	<-done

	if !strings.Contains(buf.String(), "AUTH_DISABLED") {
		t.Fatalf("no warning about disabled auth: %q", buf.String())
	}
}

func TestRunFailsOnABadPort(t *testing.T) {
	err := api.Run(context.Background(), api.Config{Port: "not-a-port", AuthDisabled: true}, quietLogger())
	if err == nil {
		t.Fatal("Run() accepted an invalid port")
	}
}
