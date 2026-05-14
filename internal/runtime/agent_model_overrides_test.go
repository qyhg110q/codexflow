package runtime

import "testing"

func TestApplyModelOverrides(t *testing.T) {
	params := map[string]any{}

	applyModelOverrides(params, "gpt-5.5", "HIGH")

	if got := params["model"]; got != "gpt-5.5" {
		t.Fatalf("model = %v, want %q", got, "gpt-5.5")
	}
	if got := params["effort"]; got != "high" {
		t.Fatalf("effort = %v, want %q", got, "high")
	}
}

func TestApplyModelOverridesSkipsEmptyValues(t *testing.T) {
	params := map[string]any{}

	applyModelOverrides(params, "  ", "  ")

	if len(params) != 0 {
		t.Fatalf("params = %#v, want empty", params)
	}
}
