package ai

import (
	"encoding/json"
	"testing"
)

func TestChatRequestDisablesThinking(t *testing.T) {
	encoded, err := json.Marshal(chatRequest{
		Model:    "deepseek-v4-flash",
		Thinking: thinkingMode{Type: "disabled"},
	})
	if err != nil {
		t.Fatal(err)
	}
	var payload map[string]any
	if err := json.Unmarshal(encoded, &payload); err != nil {
		t.Fatal(err)
	}
	thinking, ok := payload["thinking"].(map[string]any)
	if !ok || thinking["type"] != "disabled" {
		t.Fatalf("thinking mode not disabled: %s", encoded)
	}
}
