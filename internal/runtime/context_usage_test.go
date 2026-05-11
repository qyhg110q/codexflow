package runtime

import (
	"os"
	"path/filepath"
	"testing"

	"codexflow/internal/codex"
	"codexflow/internal/store"
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

func TestContextWindowUsageForRecordUsesAppServerTokenUsageWithoutTranscriptPath(t *testing.T) {
	contextWindow := int64(272000)
	record := store.SessionRecord{
		Thread: codex.Thread{ID: "thread-1"},
		Runtime: store.SessionRuntime{
			TokenUsage: &codex.ThreadTokenUsage{
				Last: codex.TokenUsageBreakdown{
					TotalTokens:           3268,
					InputTokens:           2654,
					CachedInputTokens:     2432,
					OutputTokens:          614,
					ReasoningOutputTokens: 576,
				},
				Total: codex.TokenUsageBreakdown{
					TotalTokens:           4000,
					InputTokens:           3000,
					CachedInputTokens:     2400,
					OutputTokens:          1000,
					ReasoningOutputTokens: 700,
				},
				ModelContextWindow: &contextWindow,
			},
			TokenUsageUpdatedAt: "2026-05-11T15:00:00Z",
		},
	}

	usage := contextWindowUsageForRecord(record)
	if usage == nil || !usage.Available {
		t.Fatal("usage should be available")
	}
	if got, want := usage.UsedTokens, int64(3268); got != want {
		t.Fatalf("UsedTokens = %d, want %d", got, want)
	}
	if got, want := usage.ContextWindow, contextWindow; got != want {
		t.Fatalf("ContextWindow = %d, want %d", got, want)
	}
	if got, want := usage.TotalTokenUsage.TotalTokens, int64(4000); got != want {
		t.Fatalf("TotalTokenUsage.TotalTokens = %d, want %d", got, want)
	}
	if got, want := usage.Source, appServerContextUsageSource; got != want {
		t.Fatalf("Source = %q, want %q", got, want)
	}
}
