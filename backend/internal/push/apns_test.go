package push

import "testing"

func TestAPNsEndpoint(t *testing.T) {
	tests := map[string]string{
		"":            "https://api.sandbox.push.apple.com",
		"development": "https://api.sandbox.push.apple.com",
		"sandbox":     "https://api.sandbox.push.apple.com",
		"production":  "https://api.push.apple.com",
	}
	for environment, want := range tests {
		got, err := apnsEndpoint(environment)
		if err != nil {
			t.Fatalf("%q: %v", environment, err)
		}
		if got != want {
			t.Fatalf("%q: got %q, want %q", environment, got, want)
		}
	}
	if _, err := apnsEndpoint("preview"); err == nil {
		t.Fatal("unsupported APNs environment should fail")
	}
}
