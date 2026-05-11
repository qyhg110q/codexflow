package runtime

import (
	"os"
	"path/filepath"
	"testing"
)

func TestReadContextWindowUsageUsesLatestTokenCount(t *testing.T) {
	path := filepath.Join(t.TempDir(), "session.jsonl")
	content := `{"timestamp":"2026-05-11T10:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":100,"non_cached_input_tokens":900,"output_tokens":50,"reasoning_output_tokens":10,"total_tokens":1050},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":100,"non_cached_input_tokens":900,"output_tokens":50,"reasoning_output_tokens":10,"total_tokens":1050},"model_context_window":200000},"rate_limits":null}}
{"timestamp":"2026-05-11T10:01:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":5000,"cached_input_tokens":3000,"non_cached_input_tokens":2000,"output_tokens":250,"reasoning_output_tokens":80,"total_tokens":5250},"last_token_usage":{"input_tokens":4000,"cached_input_tokens":2500,"non_cached_input_tokens":1500,"output_tokens":200,"reasoning_output_tokens":70,"total_tokens":4200},"model_context_window":200000},"rate_limits":null}}
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	usage, err := readContextWindowUsage(path)
	if err != nil {
		t.Fatalf("readContextWindowUsage() error = %v", err)
	}
	if !usage.Available {
		t.Fatal("usage should be available")
	}
	if got, want := usage.UsedTokens, int64(4200); got != want {
		t.Fatalf("UsedTokens = %d, want %d", got, want)
	}
	if got, want := usage.ContextWindow, int64(200000); got != want {
		t.Fatalf("ContextWindow = %d, want %d", got, want)
	}
	if got, want := usage.TotalTokenUsage.TotalTokens, int64(5250); got != want {
		t.Fatalf("TotalTokenUsage.TotalTokens = %d, want %d", got, want)
	}
	if got, want := usage.Source, contextUsageSource; got != want {
		t.Fatalf("Source = %q, want %q", got, want)
	}
}
