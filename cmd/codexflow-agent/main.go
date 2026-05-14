package main

import (
	"context"
	"log/slog"
	"net/http"
	"net/netip"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"

	"codexflow/internal/config"
	"codexflow/internal/httpapi"
	"codexflow/internal/runtime"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	cfg := config.Load()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	agent := runtime.NewAgent(cfg, logger)
	if err := agent.Start(ctx); err != nil {
		logger.Error("failed to start agent", "error", err)
		os.Exit(1)
	}

	server := &http.Server{
		Addr:    cfg.ListenAddr,
		Handler: httpapi.NewServer(agent, logger, cfg.WebRoot).Handler(),
	}

	go func() {
		<-ctx.Done()
		_ = server.Shutdown(context.Background())
	}()

	logStartup(logger, cfg)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Error("http server failed", "error", err)
		os.Exit(1)
	}
}

func logStartup(logger *slog.Logger, cfg config.Config) {
	fields := []any{
		"addr", cfg.ListenAddr,
		"codex_path", cfg.CodexPath,
		"state_db_path", cfg.StateDBPath,
	}
	if strings.TrimSpace(cfg.WebRoot) != "" {
		fields = append(fields, "web_root", cfg.WebRoot)
	}
	logger.Info("codexflow agent listening", fields...)

	baseURL := "http://" + normalizeHostForURL(cfg.ListenAddr)
	logger.Info("codexflow access", "api", baseURL, "healthz", baseURL+"/healthz")
}

func normalizeHostForURL(addr string) string {
	host := strings.TrimSpace(addr)
	if host == "" {
		return "127.0.0.1:4318"
	}

	parsed, err := netip.ParseAddrPort(host)
	if err != nil {
		return host
	}
	if parsed.Addr().IsUnspecified() {
		if parsed.Addr().Is6() {
			return "[::1]:" + portString(parsed.Port())
		}
		return "127.0.0.1:" + portString(parsed.Port())
	}
	return host
}

func portString(port uint16) string {
	return strconv.Itoa(int(port))
}
