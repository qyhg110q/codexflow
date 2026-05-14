package config

import (
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
		ListenAddr:      getenv("CODEXFLOW_LISTEN_ADDR", layout.DefaultListenAddr),
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

	exeDir := executableDir()
	if exeDir != "" {
		if webRoot != "" {
			listenAddr = "0.0.0.0:4318"
			stateDBPath = filepath.Join(exeDir, "data", "codexflow-state.db")
		} else if !isSourceCheckout(exeDir) && runtime.GOOS == "windows" {
			listenAddr = "0.0.0.0:4318"
			stateDBPath = filepath.Join(exeDir, "data", "codexflow-state.db")
		}
	}

	return runtimeLayout{
		DefaultListenAddr:  listenAddr,
		DefaultStateDBPath: stateDBPath,
		WebRoot:            webRoot,
	}
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
	exeDir := executableDir()
	if exeDir == "" {
		return ""
	}

	for _, candidate := range []string{
		filepath.Join(exeDir, "web"),
		filepath.Join(exeDir, "flutter", "codexflow", "build", "web"),
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
