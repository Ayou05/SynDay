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

func TestChatRequestCanEnableJSONOutput(t *testing.T) {
	request := chatRequest{
		Model:          "deepseek-v4-flash",
		Thinking:       thinkingMode{Type: "disabled"},
		ResponseFormat: &responseFormat{Type: "json_object"},
	}
	encoded, err := json.Marshal(request)
	if err != nil {
		t.Fatal(err)
	}
	var payload map[string]any
	if err := json.Unmarshal(encoded, &payload); err != nil {
		t.Fatal(err)
	}
	format, ok := payload["response_format"].(map[string]any)
	if !ok || format["type"] != "json_object" {
		t.Fatalf("JSON output not enabled: %s", encoded)
	}
}
