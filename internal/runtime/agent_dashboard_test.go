package runtime

import (
	"encoding/json"
	"testing"

	"codexflow/internal/codex"
	"codexflow/internal/store"
)

func TestDashboardLoadedSessionsExcludeEndedSessions(t *testing.T) {
	sessionStore, err := store.New(nil)
	if err != nil {
		t.Fatalf("create session store: %v", err)
	}

	sessionStore.ReplaceSessions([]codex.Thread{
		{
			ID:            "ended-thread",
			ModelProvider: "OpenAI",
			CreatedAt:     100,
			UpdatedAt:     200,
			Status:        codex.ThreadStatus{Type: "idle"},
			CWD:           "/tmp/ended",
		},
		{
			ID:            "active-thread",
			ModelProvider: "OpenAI",
			CreatedAt:     101,
			UpdatedAt:     201,
			Status:        codex.ThreadStatus{Type: "active"},
			CWD:           "/tmp/active",
		},
	}, map[string]bool{
		"ended-thread":  true,
		"active-thread": true,
	})

	sessionStore.SetSessionEnded("ended-thread", true)

	agent := &Agent{store: sessionStore}
	dashboard := agent.Dashboard()

	if got, want := dashboard.Stats.LoadedSessions, 1; got != want {
		t.Fatalf("loaded sessions = %d, want %d", got, want)
	}

	if got, want := dashboard.Stats.ActiveSessions, 1; got != want {
		t.Fatalf("active sessions = %d, want %d", got, want)
	}

	summaries := dashboard.Sessions
	if len(summaries) != 2 {
		t.Fatalf("sessions count = %d, want 2", len(summaries))
	}

	for _, session := range summaries {
		if session.ID == "ended-thread" && session.Loaded {
			t.Fatalf("ended session should not be marked loaded in API summary")
		}
	}
}

func TestEndedSessionSummaryForcesIdleStatus(t *testing.T) {
	sessionStore, err := store.New(nil)
	if err != nil {
		t.Fatalf("create session store: %v", err)
	}

	sessionStore.ReplaceSessions([]codex.Thread{
		{
			ID:            "ended-thread",
			ModelProvider: "OpenAI",
			CreatedAt:     100,
			UpdatedAt:     200,
			Status:        codex.ThreadStatus{Type: "active"},
			CWD:           "/tmp/ended",
		},
	}, map[string]bool{
		"ended-thread": true,
	})
	sessionStore.SetSessionEnded("ended-thread", true)

	record, ok := sessionStore.SnapshotSession("ended-thread")
	if !ok {
		t.Fatalf("SnapshotSession() missing record")
	}

	summary := toSessionSummary(record, 0)
	if got := summary.Status; got != "idle" {
		t.Fatalf("summary.Status = %q, want %q", got, "idle")
	}
}

func TestSessionSummaryIncludesRuntimeAttachMode(t *testing.T) {
	sessionStore, err := store.New(nil)
	if err != nil {
		t.Fatalf("create session store: %v", err)
	}

	sessionStore.UpsertThread(codex.Thread{
		ID:            "claude:thread-1",
		ModelProvider: "Anthropic",
		CreatedAt:     100,
		UpdatedAt:     200,
		Status:        codex.ThreadStatus{Type: "idle", ActiveFlags: []string{"claudeRuntimeAvailable"}},
		CWD:           "/tmp/claude",
	})
	sessionStore.SetRuntimeAttachMode("claude:thread-1", "resumed_existing")

	record, ok := sessionStore.SnapshotSession("claude:thread-1")
	if !ok {
		t.Fatalf("SnapshotSession() missing record")
	}
	summary := toSessionSummary(record, 0)
	if got := summary.RuntimeAttachMode; got != "resumed_existing" {
		t.Fatalf("summary.RuntimeAttachMode = %q, want %q", got, "resumed_existing")
	}
}

func TestHandleNotificationIgnoresUserMessageItemEvents(t *testing.T) {
	sessionStore, err := store.New(nil)
	if err != nil {
		t.Fatalf("create session store: %v", err)
	}

	params, err := json.Marshal(codex.ItemStartedNotification{
		ThreadID: "thread-1",
		TurnID:   "turn-1",
		Item: map[string]any{
			"id":      "user-item",
			"type":    "userMessage",
			"content": []any{map[string]any{"type": "text", "text": "你是谁"}},
		},
	})
	if err != nil {
		t.Fatalf("marshal notification: %v", err)
	}

	agent := &Agent{store: sessionStore}
	agent.handleNotification(t.Context(), codex.Notification{
		Method: "item/started",
		Params: params,
	})

	if _, ok := sessionStore.SnapshotSession("thread-1"); ok {
		t.Fatal("userMessage item notification should not create session state")
	}
}
