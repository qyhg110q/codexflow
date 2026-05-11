package runtime

import (
	"bufio"
	"encoding/json"
	"errors"
	"math"
	"os"
	"strings"

	"codexflow/internal/codex"
	"codexflow/internal/store"
)

const contextUsageSource = "codexTranscriptTokenCount"
const appServerContextUsageSource = "codexAppServerTokenUsage"

type transcriptEntry struct {
	Timestamp string          `json:"timestamp"`
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload"`
}

type tokenCountPayload struct {
	Type string `json:"type"`
	Info struct {
		TotalTokenUsage    transcriptTokenUsage `json:"total_token_usage"`
		LastTokenUsage     transcriptTokenUsage `json:"last_token_usage"`
		ModelContextWindow int64                `json:"model_context_window"`
	} `json:"info"`
}

type transcriptTokenUsage struct {
	InputTokens           int64 `json:"input_tokens"`
	CachedInputTokens     int64 `json:"cached_input_tokens"`
	NonCachedInputTokens  int64 `json:"non_cached_input_tokens"`
	OutputTokens          int64 `json:"output_tokens"`
	ReasoningOutputTokens int64 `json:"reasoning_output_tokens"`
	TotalTokens           int64 `json:"total_tokens"`
}

func contextWindowUsageForThread(threadPath *string) *ContextWindowUsage {
	if threadPath == nil {
		return nil
	}

	usage, err := readContextWindowUsage(*threadPath)
	if err != nil || !usage.Available {
		return nil
	}
	return &usage
}

func contextWindowUsageForRecord(record store.SessionRecord) *ContextWindowUsage {
	if record.Runtime.TokenUsage != nil {
		if usage, ok := contextWindowUsageFromAppServer(*record.Runtime.TokenUsage, record.Runtime.TokenUsageUpdatedAt); ok {
			return usage.Clone()
		}
	}
	return contextWindowUsageForThread(record.Thread.Path)
}

func contextWindowUsageFromAppServer(usage codex.ThreadTokenUsage, updatedAt string) (ContextWindowUsage, bool) {
	if usage.ModelContextWindow == nil || *usage.ModelContextWindow <= 0 {
		return ContextWindowUsage{}, false
	}
	contextWindow := *usage.ModelContextWindow
	lastUsage := toTokenUsageBreakdown(usage.Last)
	totalUsage := toTokenUsageBreakdown(usage.Total)
	usedTokens := lastUsage.TotalTokens
	if usedTokens <= 0 {
		usedTokens = lastUsage.InputTokens + lastUsage.OutputTokens
	}
	if usedTokens <= 0 {
		return ContextWindowUsage{}, false
	}

	ratio := float64(usedTokens) / float64(contextWindow)
	remainingTokens := contextWindow - usedTokens
	if remainingTokens < 0 {
		remainingTokens = 0
	}
	return ContextWindowUsage{
		Available:       true,
		UsedTokens:      usedTokens,
		ContextWindow:   contextWindow,
		RemainingTokens: remainingTokens,
		Ratio:           ratio,
		Percent:         int(math.Round(ratio * 100)),
		LastTokenUsage:  lastUsage,
		TotalTokenUsage: totalUsage,
		UpdatedAt:       updatedAt,
		Source:          appServerContextUsageSource,
	}, true
}

func readContextWindowUsage(path string) (ContextWindowUsage, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return ContextWindowUsage{}, errors.New("transcript path is empty")
	}

	file, err := os.Open(path)
	if err != nil {
		return ContextWindowUsage{}, err
	}
	defer file.Close()

	var latest ContextWindowUsage
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 0, 1024*1024), 64*1024*1024)
	for scanner.Scan() {
		usage, ok := parseContextWindowUsageLine(scanner.Bytes())
		if ok {
			latest = usage
		}
	}
	if err := scanner.Err(); err != nil {
		return ContextWindowUsage{}, err
	}
	if !latest.Available {
		return ContextWindowUsage{}, errors.New("token_count event not found")
	}
	return latest, nil
}

func parseContextWindowUsageLine(line []byte) (ContextWindowUsage, bool) {
	var entry transcriptEntry
	if err := json.Unmarshal(line, &entry); err != nil || entry.Type != "event_msg" {
		return ContextWindowUsage{}, false
	}

	var payload tokenCountPayload
	if err := json.Unmarshal(entry.Payload, &payload); err != nil || payload.Type != "token_count" {
		return ContextWindowUsage{}, false
	}

	contextWindow := payload.Info.ModelContextWindow
	lastUsage := toTokenUsage(payload.Info.LastTokenUsage)
	totalUsage := toTokenUsage(payload.Info.TotalTokenUsage)
	usedTokens := lastUsage.TotalTokens
	if usedTokens <= 0 {
		usedTokens = lastUsage.InputTokens + lastUsage.OutputTokens
	}
	if contextWindow <= 0 || usedTokens <= 0 {
		return ContextWindowUsage{}, false
	}

	ratio := float64(usedTokens) / float64(contextWindow)
	remainingTokens := contextWindow - usedTokens
	if remainingTokens < 0 {
		remainingTokens = 0
	}
	return ContextWindowUsage{
		Available:       true,
		UsedTokens:      usedTokens,
		ContextWindow:   contextWindow,
		RemainingTokens: remainingTokens,
		Ratio:           ratio,
		Percent:         int(math.Round(ratio * 100)),
		LastTokenUsage:  lastUsage,
		TotalTokenUsage: totalUsage,
		UpdatedAt:       entry.Timestamp,
		Source:          contextUsageSource,
	}, true
}

func toTokenUsage(usage transcriptTokenUsage) TokenUsage {
	return TokenUsage{
		InputTokens:           usage.InputTokens,
		CachedInputTokens:     usage.CachedInputTokens,
		NonCachedInputTokens:  usage.NonCachedInputTokens,
		OutputTokens:          usage.OutputTokens,
		ReasoningOutputTokens: usage.ReasoningOutputTokens,
		TotalTokens:           usage.TotalTokens,
	}
}

func toTokenUsageBreakdown(usage codex.TokenUsageBreakdown) TokenUsage {
	nonCachedInputTokens := usage.InputTokens - usage.CachedInputTokens
	if nonCachedInputTokens < 0 {
		nonCachedInputTokens = 0
	}
	return TokenUsage{
		InputTokens:           usage.InputTokens,
		CachedInputTokens:     usage.CachedInputTokens,
		NonCachedInputTokens:  nonCachedInputTokens,
		OutputTokens:          usage.OutputTokens,
		ReasoningOutputTokens: usage.ReasoningOutputTokens,
		TotalTokens:           usage.TotalTokens,
	}
}
