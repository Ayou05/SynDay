package push

import "testing"

func TestChannelForPayload(t *testing.T) {
	tests := map[string]string{
		"review_reminder":        "review",
		"bedtime_reminder":       "bedtime",
		"partner_task_completed": "partner_task",
		"partner_joined_focus":   "partner_join",
		"streak_milestone":       "streak",
		"unknown":                "partner_task",
	}
	for kind, want := range tests {
		if got := channelForPayload(map[string]any{"kind": kind}); got != want {
			t.Fatalf("kind %q: got %q, want %q", kind, got, want)
		}
	}
}
