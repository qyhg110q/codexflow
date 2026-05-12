package store

import (
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"codexflow/internal/codex"
)

type SessionRuntime struct {
	LatestDiffByTurn    map[string]string
	LatestPlanByTurn    map[string]codex.TurnPlanUpdatedNotification
	TokenUsage          *codex.ThreadTokenUsage
	TokenUsageUpdatedAt string
	CurrentTurnID       string
	RuntimeAttachMode   string
	Ended               bool
}

type SessionBinding struct {
	AgentID        string
	AgentSessionID string
}

type SessionRecord struct {
	Thread  codex.Thread
	Loaded  bool
	Runtime SessionRuntime
}

type PendingRequest struct {
	ID              string         `json:"id"`
	Method          string         `json:"method"`
	ThreadID        string         `json:"threadId"`
	TurnID          string         `json:"turnId"`
	ItemID          string         `json:"itemId"`
	Reason          string         `json:"reason"`
	Summary         string         `json:"summary"`
	Choices         []string       `json:"choices"`
	CreatedAt       time.Time      `json:"createdAt"`
	Params          map[string]any `json:"params"`
	RawRPCRequestID json.RawMessage
}

type Store struct {
	mu           sync.RWMutex
	seq          atomic.Uint64
	sessions     map[string]*SessionRecord
	pending      map[string]*PendingRequest
	endedState   map[string]bool
	managedState map[string]bool
	bindings     map[string]SessionBinding
	localState   *LocalStateDB
}

func New(localState *LocalStateDB) (*Store, error) {
	endedState := make(map[string]bool)
	managedState := make(map[string]bool)
	bindings := make(map[string]SessionBinding)
	if localState != nil {
		loadedState, err := localState.LoadSessionStates()
		if err != nil {
			return nil, err
		}
		for threadID, state := range loadedState {
			if state.Ended {
				endedState[threadID] = true
			}
			if state.Managed {
				managedState[threadID] = true
			}
			if state.AgentID != "" || state.AgentSessionID != "" {
				bindings[threadID] = SessionBinding{
					AgentID:        state.AgentID,
					AgentSessionID: state.AgentSessionID,
				}
			}
		}
	}

	return &Store{
		sessions:     make(map[string]*SessionRecord),
		pending:      make(map[string]*PendingRequest),
		endedState:   endedState,
		managedState: managedState,
		bindings:     bindings,
		localState:   localState,
	}, nil
}

func (s *Store) ReplaceSessions(threads []codex.Thread, loaded map[string]bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	next := make(map[string]*SessionRecord, len(threads))
	for _, thread := range threads {
		existing, ok := s.sessions[thread.ID]
		if !ok {
			existing = &SessionRecord{
				Runtime: SessionRuntime{
					LatestDiffByTurn:  make(map[string]string),
					LatestPlanByTurn:  make(map[string]codex.TurnPlanUpdatedNotification),
					RuntimeAttachMode: "",
					Ended:             s.endedState[thread.ID],
				},
			}
		}

		existing.Thread = mergeThread(existing.Thread, thread)
		existing.Loaded = loaded[thread.ID]
		if existing.Runtime.LatestDiffByTurn == nil {
			existing.Runtime.LatestDiffByTurn = make(map[string]string)
		}
		if existing.Runtime.LatestPlanByTurn == nil {
			existing.Runtime.LatestPlanByTurn = make(map[string]codex.TurnPlanUpdatedNotification)
		}
		next[thread.ID] = existing
	}

	s.sessions = next
}

func (s *Store) UpsertThread(thread codex.Thread) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record, ok := s.sessions[thread.ID]
	if !ok {
		record = &SessionRecord{
			Runtime: SessionRuntime{
				LatestDiffByTurn:  make(map[string]string),
				LatestPlanByTurn:  make(map[string]codex.TurnPlanUpdatedNotification),
				RuntimeAttachMode: "",
				Ended:             s.endedState[thread.ID],
			},
		}
		s.sessions[thread.ID] = record
	}
	record.Thread = mergeThread(record.Thread, thread)
}

func (s *Store) SetSessionEnded(threadID string, ended bool) {
	s.mu.Lock()

	record := s.ensureSessionLocked(threadID)
	record.Runtime.Ended = ended
	if ended {
		s.endedState[threadID] = true
	} else {
		delete(s.endedState, threadID)
	}
	persisted := s.persistedStateLocked(threadID)
	localState := s.localState
	s.mu.Unlock()

	_ = localState.SaveSessionState(threadID, persisted)
}

func (s *Store) SetSessionManaged(threadID string, managed bool) {
	s.mu.Lock()

	_ = s.ensureSessionLocked(threadID)
	if managed {
		s.managedState[threadID] = true
	} else {
		delete(s.managedState, threadID)
	}
	persisted := s.persistedStateLocked(threadID)
	localState := s.localState
	s.mu.Unlock()

	_ = localState.SaveSessionState(threadID, persisted)
}

func (s *Store) DeleteSessionLocalState(threadID string) {
	s.mu.Lock()
	if record, ok := s.sessions[threadID]; ok {
		record.Runtime.Ended = false
	}
	delete(s.endedState, threadID)
	delete(s.managedState, threadID)
	delete(s.bindings, threadID)
	localState := s.localState
	s.mu.Unlock()

	_ = localState.SaveSessionState(threadID, PersistedSessionState{})
}

func (s *Store) ManagedSessionIDs() []string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	ids := make([]string, 0, len(s.managedState))
	for threadID, managed := range s.managedState {
		if !managed {
			continue
		}
		ids = append(ids, threadID)
	}
	slices.Sort(ids)
	return ids
}

func (s *Store) HasLocalSessionState(threadID string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	threadID = strings.TrimSpace(threadID)
	if threadID == "" {
		return false
	}
	return s.endedState[threadID] || s.managedState[threadID]
}

func (s *Store) SetSessionLoaded(threadID string, loaded bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record := s.ensureSessionLocked(threadID)
	record.Loaded = loaded
}

func (s *Store) SetRuntimeAttachMode(threadID, mode string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record := s.ensureSessionLocked(threadID)
	record.Runtime.RuntimeAttachMode = strings.TrimSpace(mode)
}

func (s *Store) SetSessionBinding(threadID, agentID, agentSessionID string) {
	s.mu.Lock()
	threadID = strings.TrimSpace(threadID)
	if threadID == "" {
		s.mu.Unlock()
		return
	}
	_ = s.ensureSessionLocked(threadID)

	trimmedAgentID := strings.TrimSpace(agentID)
	trimmedAgentSessionID := strings.TrimSpace(agentSessionID)
	if trimmedAgentID == "" && trimmedAgentSessionID == "" {
		delete(s.bindings, threadID)
	} else {
		s.bindings[threadID] = SessionBinding{
			AgentID:        trimmedAgentID,
			AgentSessionID: trimmedAgentSessionID,
		}
	}
	persisted := s.persistedStateLocked(threadID)
	localState := s.localState
	s.mu.Unlock()

	_ = localState.SaveSessionState(threadID, persisted)
}

func (s *Store) SessionBinding(threadID string) (SessionBinding, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	binding, ok := s.bindings[strings.TrimSpace(threadID)]
	return binding, ok
}

func (s *Store) UpdateThreadStatus(threadID string, status codex.ThreadStatus) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record := s.ensureSessionLocked(threadID)
	record.Thread.Status = status
}

func (s *Store) RecordTurn(threadID string, turn codex.Turn) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record := s.ensureSessionLocked(threadID)

	updated := false
	for idx := range record.Thread.Turns {
		if record.Thread.Turns[idx].ID == turn.ID {
			record.Thread.Turns[idx] = turn
			updated = true
			break
		}
	}
	if !updated {
		record.Thread.Turns = append(record.Thread.Turns, turn)
	}
	record.Runtime.CurrentTurnID = turn.ID
}

func (s *Store) RecordTurnItem(threadID, turnID string, item map[string]any) {
	s.mu.Lock()
	defer s.mu.Unlock()

	threadID = strings.TrimSpace(threadID)
	turnID = strings.TrimSpace(turnID)
	if threadID == "" || turnID == "" || len(item) == 0 {
		return
	}

	record := s.ensureSessionLocked(threadID)
	turn := ensureTurnLocked(record, turnID)
	itemID := stringField(item, "id")
	if itemID == "" {
		turn.Items = append(turn.Items, cloneMap(item))
		record.Runtime.CurrentTurnID = turnID
		return
	}

	for idx := range turn.Items {
		if stringField(turn.Items[idx], "id") == itemID {
			turn.Items[idx] = mergeItem(turn.Items[idx], item)
			record.Runtime.CurrentTurnID = turnID
			return
		}
	}
	if stringField(item, "type") == "agentMessage" {
		if idx := liveAgentMessageIndex(turn.Items); idx >= 0 {
			turn.Items[idx] = mergeAgentMessageItem(turn.Items[idx], item)
			record.Runtime.CurrentTurnID = turnID
			return
		}
	}

	turn.Items = append(turn.Items, cloneMap(item))
	record.Runtime.CurrentTurnID = turnID
}

func (s *Store) AppendAgentMessageDelta(threadID, turnID, itemID, delta string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	threadID = strings.TrimSpace(threadID)
	turnID = strings.TrimSpace(turnID)
	itemID = strings.TrimSpace(itemID)
	if threadID == "" || turnID == "" || delta == "" {
		return
	}

	record := s.ensureSessionLocked(threadID)
	turn := ensureTurnLocked(record, turnID)
	targetIndex := -1
	if itemID != "" {
		for idx := range turn.Items {
			if stringField(turn.Items[idx], "id") == itemID {
				targetIndex = idx
				break
			}
		}
	}
	if targetIndex < 0 {
		for idx := len(turn.Items) - 1; idx >= 0; idx-- {
			if stringField(turn.Items[idx], "type") == "agentMessage" {
				targetIndex = idx
				break
			}
		}
	}
	if targetIndex < 0 {
		item := map[string]any{
			"type": "agentMessage",
			"text": "",
		}
		if itemID != "" {
			item["id"] = itemID
		}
		turn.Items = append(turn.Items, item)
		targetIndex = len(turn.Items) - 1
	}

	item := turn.Items[targetIndex]
	item["type"] = "agentMessage"
	if itemID != "" && stringField(item, "id") == "" {
		item["id"] = itemID
	}
	item["text"] = stringField(item, "text") + delta
	record.Runtime.CurrentTurnID = turnID
}

func ensureTurnLocked(record *SessionRecord, turnID string) *codex.Turn {
	for idx := range record.Thread.Turns {
		if record.Thread.Turns[idx].ID == turnID {
			if record.Thread.Turns[idx].Status == "" {
				record.Thread.Turns[idx].Status = "inProgress"
			}
			return &record.Thread.Turns[idx]
		}
	}

	record.Thread.Turns = append(record.Thread.Turns, codex.Turn{
		ID:     turnID,
		Status: "inProgress",
		Items:  []map[string]any{},
	})
	return &record.Thread.Turns[len(record.Thread.Turns)-1]
}

func mergeItem(existing, incoming map[string]any) map[string]any {
	merged := cloneMap(existing)
	for key, value := range incoming {
		merged[key] = value
	}
	return merged
}

func (s *Store) ensureSessionLocked(threadID string) *SessionRecord {
	record, ok := s.sessions[threadID]
	if ok {
		return record
	}

	record = &SessionRecord{
		Thread: codex.Thread{ID: threadID},
		Runtime: SessionRuntime{
			LatestDiffByTurn:  make(map[string]string),
			LatestPlanByTurn:  make(map[string]codex.TurnPlanUpdatedNotification),
			RuntimeAttachMode: "",
			Ended:             s.endedState[threadID],
		},
	}
	s.sessions[threadID] = record
	return record
}

func (s *Store) persistedStateLocked(threadID string) PersistedSessionState {
	binding := s.bindings[threadID]
	return PersistedSessionState{
		Ended:          s.endedState[threadID],
		Managed:        s.managedState[threadID],
		AgentID:        binding.AgentID,
		AgentSessionID: binding.AgentSessionID,
	}
}

func (s *Store) RecordDiff(threadID, turnID, diff string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record, ok := s.sessions[threadID]
	if !ok {
		return
	}
	record.Runtime.LatestDiffByTurn[turnID] = diff
}

func (s *Store) RecordPlan(notification codex.TurnPlanUpdatedNotification) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record, ok := s.sessions[notification.ThreadID]
	if !ok {
		return
	}
	record.Runtime.LatestPlanByTurn[notification.TurnID] = notification
}

func (s *Store) RecordTokenUsage(notification codex.ThreadTokenUsageUpdatedNotification, updatedAt string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record := s.ensureSessionLocked(notification.ThreadID)
	usage := notification.TokenUsage
	record.Runtime.TokenUsage = &usage
	record.Runtime.TokenUsageUpdatedAt = updatedAt
	if notification.TurnID != "" {
		record.Runtime.CurrentTurnID = notification.TurnID
	}
}

func (s *Store) SnapshotSessions() []SessionRecord {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]SessionRecord, 0, len(s.sessions))
	for _, record := range s.sessions {
		result = append(result, cloneSessionRecord(*record))
	}

	slices.SortFunc(result, func(a, b SessionRecord) int {
		if a.Thread.UpdatedAt == b.Thread.UpdatedAt {
			switch {
			case a.Thread.ID < b.Thread.ID:
				return -1
			case a.Thread.ID > b.Thread.ID:
				return 1
			default:
				return 0
			}
		}
		if a.Thread.UpdatedAt > b.Thread.UpdatedAt {
			return -1
		}
		return 1
	})

	return result
}

func (s *Store) SnapshotSession(id string) (SessionRecord, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	record, ok := s.sessions[id]
	if !ok {
		return SessionRecord{}, false
	}
	return cloneSessionRecord(*record), true
}

func (s *Store) UpsertPending(method string, rpcID json.RawMessage, params map[string]any, choices []string) PendingRequest {
	s.mu.Lock()
	defer s.mu.Unlock()

	id := fmt.Sprintf("req-%06d", s.seq.Add(1))
	request := &PendingRequest{
		ID:              id,
		Method:          method,
		ThreadID:        stringField(params, "threadId"),
		TurnID:          stringField(params, "turnId"),
		ItemID:          stringField(params, "itemId"),
		Reason:          stringField(params, "reason"),
		Summary:         summarize(method, params),
		Choices:         slices.Clone(choices),
		CreatedAt:       time.Now(),
		Params:          cloneMap(params),
		RawRPCRequestID: slices.Clone(rpcID),
	}
	s.pending[id] = request
	return clonePending(*request)
}

func (s *Store) DeletePending(id string) (PendingRequest, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	request, ok := s.pending[id]
	if !ok {
		return PendingRequest{}, false
	}
	delete(s.pending, id)
	return clonePending(*request), true
}

func (s *Store) SnapshotPending() []PendingRequest {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]PendingRequest, 0, len(s.pending))
	for _, request := range s.pending {
		result = append(result, clonePending(*request))
	}
	slices.SortFunc(result, func(a, b PendingRequest) int {
		if a.CreatedAt.Equal(b.CreatedAt) {
			switch {
			case a.ID < b.ID:
				return -1
			case a.ID > b.ID:
				return 1
			default:
				return 0
			}
		}
		if a.CreatedAt.Before(b.CreatedAt) {
			return -1
		}
		return 1
	})
	return result
}

func stringField(m map[string]any, key string) string {
	value, ok := m[key]
	if !ok {
		return ""
	}
	text, _ := value.(string)
	return text
}

func summarize(method string, params map[string]any) string {
	switch method {
	case "item/commandExecution/requestApproval":
		if command, ok := params["command"].(string); ok && command != "" {
			return command
		}
		return "Command approval requested"
	case "item/fileChange/requestApproval":
		return "File change approval requested"
	case "item/permissions/requestApproval":
		return "Additional permissions requested"
	case "item/tool/requestUserInput":
		if questions, ok := params["questions"].([]any); ok {
			for _, value := range questions {
				object, ok := value.(map[string]any)
				if !ok {
					continue
				}
				if question, ok := object["question"].(string); ok && strings.TrimSpace(question) != "" {
					return strings.TrimSpace(question)
				}
				if prompt, ok := object["prompt"].(string); ok && strings.TrimSpace(prompt) != "" {
					return strings.TrimSpace(prompt)
				}
			}
		}
		return "Agent is waiting for structured user input"
	default:
		return method
	}
}

func cloneMap(source map[string]any) map[string]any {
	if source == nil {
		return nil
	}
	data, _ := json.Marshal(source)
	var cloned map[string]any
	_ = json.Unmarshal(data, &cloned)
	return cloned
}

func cloneSessionRecord(record SessionRecord) SessionRecord {
	cloned := record
	cloned.Thread = cloneThread(record.Thread)
	cloned.Runtime = SessionRuntime{
		LatestDiffByTurn:    make(map[string]string, len(record.Runtime.LatestDiffByTurn)),
		LatestPlanByTurn:    make(map[string]codex.TurnPlanUpdatedNotification, len(record.Runtime.LatestPlanByTurn)),
		TokenUsage:          cloneTokenUsage(record.Runtime.TokenUsage),
		TokenUsageUpdatedAt: record.Runtime.TokenUsageUpdatedAt,
		CurrentTurnID:       record.Runtime.CurrentTurnID,
		RuntimeAttachMode:   record.Runtime.RuntimeAttachMode,
		Ended:               record.Runtime.Ended,
	}
	for key, value := range record.Runtime.LatestDiffByTurn {
		cloned.Runtime.LatestDiffByTurn[key] = value
	}
	for key, value := range record.Runtime.LatestPlanByTurn {
		cloned.Runtime.LatestPlanByTurn[key] = value
	}
	return cloned
}

func cloneTokenUsage(usage *codex.ThreadTokenUsage) *codex.ThreadTokenUsage {
	if usage == nil {
		return nil
	}
	cloned := *usage
	if usage.ModelContextWindow != nil {
		value := *usage.ModelContextWindow
		cloned.ModelContextWindow = &value
	}
	return &cloned
}

func cloneThread(thread codex.Thread) codex.Thread {
	data, _ := json.Marshal(thread)
	var cloned codex.Thread
	_ = json.Unmarshal(data, &cloned)
	return cloned
}

func clonePending(request PendingRequest) PendingRequest {
	cloned := request
	cloned.Choices = slices.Clone(request.Choices)
	cloned.Params = cloneMap(request.Params)
	cloned.RawRPCRequestID = slices.Clone(request.RawRPCRequestID)
	return cloned
}

func mergeThread(existing, incoming codex.Thread) codex.Thread {
	merged := incoming

	if len(merged.Turns) == 0 && len(existing.Turns) > 0 {
		merged.Turns = cloneTurns(existing.Turns)
	}
	if len(merged.Turns) > 0 && len(existing.Turns) > 0 {
		merged.Turns = mergeTurns(existing.Turns, merged.Turns)
	}
	if strings.TrimSpace(merged.Preview) == "" && strings.TrimSpace(existing.Preview) != "" {
		merged.Preview = existing.Preview
	}
	if strings.TrimSpace(merged.CWD) == "" && strings.TrimSpace(existing.CWD) != "" {
		merged.CWD = existing.CWD
	}
	if merged.CreatedAt == 0 && existing.CreatedAt > 0 {
		merged.CreatedAt = existing.CreatedAt
	}
	if merged.UpdatedAt == 0 && existing.UpdatedAt > 0 {
		merged.UpdatedAt = existing.UpdatedAt
	}
	if len(merged.Source) == 0 && len(existing.Source) > 0 {
		merged.Source = slices.Clone(existing.Source)
	}
	if merged.Path == nil || strings.TrimSpace(*merged.Path) == "" {
		merged.Path = cloneStringPtr(existing.Path)
	}
	if merged.RuntimeSessionID == nil || strings.TrimSpace(*merged.RuntimeSessionID) == "" {
		merged.RuntimeSessionID = cloneStringPtr(existing.RuntimeSessionID)
	}
	if merged.Name == nil || strings.TrimSpace(*merged.Name) == "" {
		merged.Name = cloneStringPtr(existing.Name)
	}
	if merged.AgentNickname == nil || strings.TrimSpace(*merged.AgentNickname) == "" {
		merged.AgentNickname = cloneStringPtr(existing.AgentNickname)
	}
	if merged.AgentRole == nil || strings.TrimSpace(*merged.AgentRole) == "" {
		merged.AgentRole = cloneStringPtr(existing.AgentRole)
	}
	if len(merged.GitInfo) == 0 && len(existing.GitInfo) > 0 {
		merged.GitInfo = cloneMap(existing.GitInfo)
	}

	return merged
}

func cloneTurns(turns []codex.Turn) []codex.Turn {
	if len(turns) == 0 {
		return nil
	}
	data, _ := json.Marshal(turns)
	var cloned []codex.Turn
	_ = json.Unmarshal(data, &cloned)
	return cloned
}

func mergeTurns(existing, incoming []codex.Turn) []codex.Turn {
	existingByID := make(map[string]codex.Turn, len(existing))
	for _, turn := range existing {
		existingByID[turn.ID] = turn
	}

	result := cloneTurns(incoming)
	for idx := range result {
		old, ok := existingByID[result[idx].ID]
		if !ok {
			continue
		}
		if len(result[idx].Items) == 0 && len(old.Items) > 0 {
			result[idx].Items = cloneItems(old.Items)
			continue
		}
		if result[idx].Status == "inProgress" || old.Status == "inProgress" {
			result[idx].Items = mergeTurnItems(old.Items, result[idx].Items)
		}
	}
	return result
}

func mergeTurnItems(existing, incoming []map[string]any) []map[string]any {
	result := cloneItems(incoming)
	seen := make(map[string]int, len(result))
	for idx, item := range result {
		itemID := stringField(item, "id")
		if itemID != "" {
			seen[itemID] = idx
		}
	}

	for _, item := range existing {
		itemID := stringField(item, "id")
		if itemID == "" {
			if stringField(item, "type") == "agentMessage" {
				if idx := agentMessageIndex(result); idx >= 0 {
					result[idx] = mergeAgentMessageItem(result[idx], item)
					continue
				}
			}
			result = append(result, cloneMap(item))
			continue
		}
		idx, ok := seen[itemID]
		if !ok {
			if duplicateIdx := equivalentTurnItemIndex(result, item); duplicateIdx >= 0 {
				result[duplicateIdx] = mergeEquivalentTurnItem(result[duplicateIdx], item)
				seen[itemID] = duplicateIdx
				continue
			}
			if stringField(item, "type") == "agentMessage" {
				if liveIdx := liveAgentMessageIndex(result); liveIdx >= 0 {
					result[liveIdx] = mergeAgentMessageItem(result[liveIdx], item)
					seen[itemID] = liveIdx
					continue
				}
			}
			result = append(result, cloneMap(item))
			seen[itemID] = len(result) - 1
			continue
		}
		if stringField(item, "type") == "agentMessage" && stringField(result[idx], "type") == "agentMessage" {
			if len(stringField(item, "text")) > len(stringField(result[idx], "text")) {
				result[idx]["text"] = stringField(item, "text")
			}
		}
	}
	return result
}

func equivalentTurnItemIndex(items []map[string]any, item map[string]any) int {
	itemType := stringField(item, "type")
	switch itemType {
	case "userMessage":
		text := normalizedItemText(item)
		if text == "" {
			return -1
		}
		for idx := len(items) - 1; idx >= 0; idx-- {
			if stringField(items[idx], "type") == itemType && normalizedItemText(items[idx]) == text {
				return idx
			}
		}
	case "agentMessage":
		text := normalizedItemText(item)
		if text == "" {
			return -1
		}
		for idx := len(items) - 1; idx >= 0; idx-- {
			if stringField(items[idx], "type") != itemType {
				continue
			}
			candidateText := normalizedItemText(items[idx])
			if candidateText != "" && sameStreamingAgentMessage(candidateText, text) {
				return idx
			}
		}
	}
	return -1
}

func mergeEquivalentTurnItem(existing, incoming map[string]any) map[string]any {
	if stringField(existing, "type") == "agentMessage" && stringField(incoming, "type") == "agentMessage" {
		return mergeAgentMessageItem(existing, incoming)
	}
	return mergeItem(incoming, existing)
}

func mergeAgentMessageItem(existing, incoming map[string]any) map[string]any {
	merged := mergeItem(existing, incoming)
	if stringField(existing, "id") != "" && isLiveAgentMessageID(stringField(incoming, "id")) {
		merged["id"] = stringField(existing, "id")
	}
	if len(stringField(existing, "text")) > len(stringField(incoming, "text")) {
		merged["text"] = stringField(existing, "text")
	}
	return merged
}

func normalizedItemText(item map[string]any) string {
	switch stringField(item, "type") {
	case "userMessage":
		return normalizeComparableText(codex.FirstUserText([]map[string]any{item}))
	case "agentMessage":
		return normalizeComparableText(stringField(item, "text"))
	default:
		return ""
	}
}

func normalizeComparableText(value string) string {
	return strings.Join(strings.Fields(value), " ")
}

func sameStreamingAgentMessage(left, right string) bool {
	return left == right || strings.HasPrefix(left, right) || strings.HasPrefix(right, left)
}

func agentMessageIndex(items []map[string]any) int {
	for idx := len(items) - 1; idx >= 0; idx-- {
		if stringField(items[idx], "type") == "agentMessage" {
			return idx
		}
	}
	return -1
}

func liveAgentMessageIndex(items []map[string]any) int {
	for idx := len(items) - 1; idx >= 0; idx-- {
		if stringField(items[idx], "type") != "agentMessage" {
			continue
		}
		if isLiveAgentMessageID(stringField(items[idx], "id")) {
			return idx
		}
	}
	return -1
}

func isLiveAgentMessageID(itemID string) bool {
	return itemID == "" || strings.HasSuffix(itemID, "-agent-live")
}

func cloneItems(items []map[string]any) []map[string]any {
	if len(items) == 0 {
		return nil
	}
	result := make([]map[string]any, 0, len(items))
	for _, item := range items {
		result = append(result, cloneMap(item))
	}
	return result
}

func cloneStringPtr(value *string) *string {
	if value == nil {
		return nil
	}
	cloned := *value
	return &cloned
}
