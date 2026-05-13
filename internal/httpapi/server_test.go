package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"codexflow/internal/runtime"
)

func TestSessionForkEndpointRoutesToAgent(t *testing.T) {
	agent := &fakeAgent{
		forkResult: runtime.SessionSummary{ID: "forked-thread", LifecycleStage: "managed"},
	}
	server := newServer(agent, slog.New(slog.NewTextHandler(io.Discard, nil)))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/sessions/source-thread/fork", strings.NewReader(`{"turnId":"turn-2"}`))
	recorder := httptest.NewRecorder()

	server.Handler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d; body = %s", recorder.Code, http.StatusCreated, recorder.Body.String())
	}
	if agent.forkThreadID != "source-thread" {
		t.Fatalf("fork thread id = %q, want %q", agent.forkThreadID, "source-thread")
	}
	if agent.forkTurnID != "turn-2" {
		t.Fatalf("fork turn id = %q, want %q", agent.forkTurnID, "turn-2")
	}

	var response runtime.SessionSummary
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if response.ID != "forked-thread" {
		t.Fatalf("response id = %q, want %q", response.ID, "forked-thread")
	}
}

func TestSessionStartAllowsEmptyCWD(t *testing.T) {
	agent := &fakeAgent{
		startResult: runtime.SessionSummary{ID: "thread-no-cwd", LifecycleStage: "managed"},
	}
	server := newServer(agent, slog.New(slog.NewTextHandler(io.Discard, nil)))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/sessions", strings.NewReader(`{"action":"start","cwd":"","prompt":"hello","agent":"codex","policy":"ask"}`))
	recorder := httptest.NewRecorder()

	server.Handler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d; body = %s", recorder.Code, http.StatusCreated, recorder.Body.String())
	}
	if agent.startCWD != "" {
		t.Fatalf("start cwd = %q, want empty", agent.startCWD)
	}
	if agent.startPrompt != "hello" {
		t.Fatalf("start prompt = %q, want %q", agent.startPrompt, "hello")
	}
}

type fakeAgent struct {
	forkThreadID string
	forkTurnID   string
	forkResult   runtime.SessionSummary
	startCWD     string
	startPrompt  string
	startResult  runtime.SessionSummary
}

func (a *fakeAgent) Dashboard() runtime.Dashboard {
	return runtime.Dashboard{}
}

func (a *fakeAgent) ListSessions() []runtime.SessionSummary {
	return nil
}

func (a *fakeAgent) Refresh(context.Context) error {
	return nil
}

func (a *fakeAgent) StartSession(_ context.Context, cwd, prompt, _ string, _ string) (runtime.SessionSummary, error) {
	a.startCWD = cwd
	a.startPrompt = prompt
	return a.startResult, nil
}

func (a *fakeAgent) ForkSession(_ context.Context, threadID, turnID string) (runtime.SessionSummary, error) {
	a.forkThreadID = threadID
	a.forkTurnID = turnID
	return a.forkResult, nil
}

func (a *fakeAgent) SessionDetail(context.Context, string) (runtime.SessionDetail, error) {
	return runtime.SessionDetail{}, nil
}

func (a *fakeAgent) ContextWindowUsage(string) (runtime.ContextWindowUsage, error) {
	return runtime.ContextWindowUsage{}, nil
}

func (a *fakeAgent) ResumeSession(context.Context, string) (runtime.SessionSummary, error) {
	return runtime.SessionSummary{}, nil
}

func (a *fakeAgent) EndSession(context.Context, string) error {
	return nil
}

func (a *fakeAgent) ArchiveSession(context.Context, string) error {
	return nil
}

func (a *fakeAgent) StartTurn(context.Context, string, []map[string]any, string) (runtime.TurnDetail, error) {
	return runtime.TurnDetail{}, nil
}

func (a *fakeAgent) SteerTurn(context.Context, string, string, []map[string]any) error {
	return nil
}

func (a *fakeAgent) InterruptTurn(context.Context, string, string) error {
	return nil
}

func (a *fakeAgent) PendingRequests() []runtime.PendingRequestView {
	return nil
}

func (a *fakeAgent) ResolveRequest(context.Context, string, json.RawMessage) error {
	return nil
}

func (a *fakeAgent) Subscribe() chan runtime.Event {
	return make(chan runtime.Event)
}

func (a *fakeAgent) Unsubscribe(chan runtime.Event) {}
