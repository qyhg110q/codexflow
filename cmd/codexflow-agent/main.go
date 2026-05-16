package main

import (
	"context"
	"log/slog"
	"net"
	"net/http"
	"net/netip"
	"os"
	"os/signal"
	"slices"
	"strconv"
	"strings"
	"syscall"

	"codexflow/internal/config"
	"codexflow/internal/httpapi"
	"codexflow/internal/runtime"
)

var listLANIPv4s = detectLANIPv4s

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

	access := collectAccessURLs(cfg)
	logger.Info(
		"codexflow access",
		"browser", access.BrowserURL,
		"phone", access.PhoneURL,
		"healthz", access.HealthzURL,
	)
	if len(access.ExtraLANURLs) > 0 {
		logger.Info("codexflow lan alternatives", "urls", strings.Join(access.ExtraLANURLs, ", "))
	}
	if access.PhoneHint != "" {
		logger.Info("codexflow phone hint", "message", access.PhoneHint)
	}
}

type accessURLs struct {
	BrowserURL   string
	PhoneURL     string
	HealthzURL   string
	ExtraLANURLs []string
	PhoneHint    string
}

func collectAccessURLs(cfg config.Config) accessURLs {
	host := strings.TrimSpace(cfg.ListenAddr)
	if host == "" {
		host = "127.0.0.1:4318"
	}

	localHost := normalizeHostForURL(host)
	browserURL := "http://" + localHost
	healthzURL := browserURL + "/healthz"

	phoneURL := browserURL
	phoneHint := ""
	lanURLs := lanURLsForListenAddr(host)
	if len(lanURLs) > 0 {
		phoneURL = lanURLs[0]
		if len(lanURLs) > 1 {
			lanURLs = lanURLs[1:]
		} else {
			lanURLs = nil
		}
	} else if hostIsLoopback(host) {
		phoneHint = "listenAddr is loopback-only. Phone devices on LAN cannot reach this agent until listenAddr is changed to 0.0.0.0:<port> or a LAN IP."
	}

	if strings.TrimSpace(cfg.WebRoot) == "" {
		phoneHint = strings.TrimSpace(strings.Join([]string{
			phoneHint,
			"No bundled web detected. Browser root may not serve the web client yet.",
		}, " "))
	}

	return accessURLs{
		BrowserURL:   browserURL,
		PhoneURL:     phoneURL,
		HealthzURL:   healthzURL,
		ExtraLANURLs: lanURLs,
		PhoneHint:    phoneHint,
	}
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

func lanURLsForListenAddr(addr string) []string {
	parsed, err := netip.ParseAddrPort(strings.TrimSpace(addr))
	if err != nil {
		return nil
	}

	if parsed.Addr().IsLoopback() {
		return nil
	}
	if !parsed.Addr().IsUnspecified() && !parsed.Addr().Is6() {
		return []string{"http://" + parsed.String()}
	}

	port := portString(parsed.Port())
	var urls []string
	for _, ip := range listLANIPv4s() {
		urls = append(urls, "http://"+ip+":"+port)
	}
	return urls
}

func detectLANIPv4s() []string {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil
	}

	var ips []string
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			prefix, err := netip.ParsePrefix(addr.String())
			if err != nil {
				continue
			}
			ip := prefix.Addr()
			if !ip.Is4() || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
				continue
			}
			ips = append(ips, ip.String())
		}
	}

	slices.Sort(ips)
	return slices.Compact(ips)
}

func hostIsLoopback(addr string) bool {
	parsed, err := netip.ParseAddrPort(strings.TrimSpace(addr))
	if err != nil {
		return false
	}
	return parsed.Addr().IsLoopback()
}

func portString(port uint16) string {
	return strconv.Itoa(int(port))
}
