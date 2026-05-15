package config

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

type Config struct {
	ListenAddr      string
	CodexPath       string
	ClaudePath      string
	RefreshInterval time.Duration
	StateDBPath     string
	WebRoot         string
}

func Load() Config {
	layout := detectRuntimeLayout()
	return Config{
		ListenAddr:      loadListenAddr(layout),
		CodexPath:       getenv("CODEXFLOW_CODEX_PATH", detectCodexPath()),
		ClaudePath:      getenv("CODEXFLOW_CLAUDE_PATH", "claude"),
		RefreshInterval: getDurationEnv("CODEXFLOW_REFRESH_INTERVAL", 12*time.Second),
		StateDBPath:     getenv("CODEXFLOW_STATE_DB_PATH", layout.DefaultStateDBPath),
		WebRoot:         getenv("CODEXFLOW_WEB_ROOT", layout.WebRoot),
	}
}

type runtimeLayout struct {
	DefaultListenAddr  string
	DefaultStateDBPath string
	WebRoot            string
}

type fileConfig struct {
	ListenAddr string `json:"listenAddr"`
}

func getenv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getDurationEnv(key string, fallback time.Duration) time.Duration {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := time.ParseDuration(value)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}

func defaultStateDBPath() string {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return "./codexflow-state.db"
	}
	return filepath.Join(home, ".codexflow", "state.db")
}

func detectRuntimeLayout() runtimeLayout {
	webRoot := detectWebRoot()
	listenAddr := "127.0.0.1:4318"
	stateDBPath := defaultStateDBPath()

	baseDir := runtimeBaseDir()
	if baseDir != "" {
		if webRoot != "" && baseDir == executableDir() {
			listenAddr = "0.0.0.0:4318"
			stateDBPath = filepath.Join(baseDir, "data", "codexflow-state.db")
		} else if !isSourceCheckout(baseDir) && runtime.GOOS == "windows" {
			listenAddr = "0.0.0.0:4318"
			stateDBPath = filepath.Join(baseDir, "data", "codexflow-state.db")
		}
	}

	return runtimeLayout{
		DefaultListenAddr:  listenAddr,
		DefaultStateDBPath: stateDBPath,
		WebRoot:            webRoot,
	}
}

func loadListenAddr(layout runtimeLayout) string {
	configPath := configFilePath()
	if configPath == "" {
		return layout.DefaultListenAddr
	}

	cfg, err := readOrCreateFileConfig(configPath, layout.DefaultListenAddr)
	if err != nil {
		return layout.DefaultListenAddr
	}
	if strings.TrimSpace(cfg.ListenAddr) == "" {
		return layout.DefaultListenAddr
	}
	return strings.TrimSpace(cfg.ListenAddr)
}

func readOrCreateFileConfig(path string, defaultListenAddr string) (fileConfig, error) {
	if !fileExists(path) {
		cfg := fileConfig{ListenAddr: defaultListenAddr}
		if err := writeFileConfig(path, cfg); err != nil {
			return fileConfig{}, err
		}
		return cfg, nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return fileConfig{}, err
	}

	var cfg fileConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return fileConfig{}, err
	}

	if strings.TrimSpace(cfg.ListenAddr) == "" {
		cfg.ListenAddr = defaultListenAddr
		if err := writeFileConfig(path, cfg); err != nil {
			return fileConfig{}, err
		}
	}

	return cfg, nil
}

func writeFileConfig(path string, cfg fileConfig) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	return os.WriteFile(path, data, 0o644)
}

func detectCodexPath() string {
	if runtime.GOOS == "windows" {
		for _, candidate := range []string{"codex.cmd", "codex.exe", "codex"} {
			if resolved, err := exec.LookPath(candidate); err == nil && strings.TrimSpace(resolved) != "" {
				return resolved
			}
		}

		for _, candidate := range []string{
			filepath.Join(os.Getenv("APPDATA"), "npm", "codex.cmd"),
			filepath.Join(os.Getenv("LOCALAPPDATA"), "Programs", "codex", "codex.exe"),
			filepath.Join(os.Getenv("LOCALAPPDATA"), "Microsoft", "WinGet", "Links", "codex.exe"),
		} {
			if candidate != "" && fileExists(candidate) {
				return candidate
			}
		}
	}

	if resolved, err := exec.LookPath("codex"); err == nil && strings.TrimSpace(resolved) != "" {
		return resolved
	}
	return "codex"
}

func detectWebRoot() string {
	baseDir := runtimeBaseDir()
	if baseDir == "" {
		return ""
	}

	for _, candidate := range []string{
		filepath.Join(baseDir, "web"),
		filepath.Join(baseDir, "flutter", "codexflow", "build", "web"),
	} {
		if dirExists(candidate) {
			return candidate
		}
	}

	return ""
}

func executableDir() string {
	path, err := os.Executable()
	if err != nil || strings.TrimSpace(path) == "" {
		return ""
	}
	return filepath.Dir(path)
}

func configFilePath() string {
	baseDir := runtimeBaseDir()
	if baseDir == "" {
		return ""
	}
	return filepath.Join(baseDir, "codexflow-agent.json")
}

func runtimeBaseDir() string {
	if cwd, err := os.Getwd(); err == nil && isSourceCheckout(cwd) {
		return cwd
	}
	return executableDir()
}

func isSourceCheckout(dir string) bool {
	for current := dir; current != "" && current != filepath.Dir(current); current = filepath.Dir(current) {
		if fileExists(filepath.Join(current, "go.mod")) &&
			dirExists(filepath.Join(current, "cmd")) &&
			dirExists(filepath.Join(current, "internal")) {
			return true
		}
	}
	return false
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}
