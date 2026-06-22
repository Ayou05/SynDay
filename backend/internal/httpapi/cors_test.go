package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCORSAllowsTauriOrigin(t *testing.T) {
	handler := cors([]string{"tauri://localhost"})(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	request := httptest.NewRequest(http.MethodGet, "/v1/time", nil)
	request.Header.Set("Origin", "tauri://localhost")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if got := response.Header().Get("Access-Control-Allow-Origin"); got != "tauri://localhost" {
		t.Fatalf("Access-Control-Allow-Origin = %q", got)
	}
}

func TestCORSRejectsUnknownPreflight(t *testing.T) {
	handler := cors([]string{"tauri://localhost"})(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		t.Fatal("next handler must not run for rejected preflight")
	}))
	request := httptest.NewRequest(http.MethodOptions, "/v1/tasks", nil)
	request.Header.Set("Origin", "https://unknown.example")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusForbidden)
	}
}
