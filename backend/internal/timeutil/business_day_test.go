package timeutil

import (
	"testing"
	"time"
)

func TestBusinessDate(t *testing.T) {
	location, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		name string
		at   string
		want string
	}{
		{"before midnight", "2026-06-21T23:59:59+08:00", "2026-06-21"},
		{"after midnight belongs to yesterday", "2026-06-22T00:00:00+08:00", "2026-06-21"},
		{"one second before boundary", "2026-06-22T03:59:59+08:00", "2026-06-21"},
		{"at boundary", "2026-06-22T04:00:00+08:00", "2026-06-22"},
		{"after boundary", "2026-06-22T12:00:00+08:00", "2026-06-22"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			at, err := time.Parse(time.RFC3339, tt.at)
			if err != nil {
				t.Fatal(err)
			}
			if got := BusinessDateString(at, location); got != tt.want {
				t.Fatalf("BusinessDateString() = %s, want %s", got, tt.want)
			}
		})
	}
}

func TestNextBoundary(t *testing.T) {
	location, _ := time.LoadLocation("Asia/Shanghai")
	at, _ := time.Parse(time.RFC3339, "2026-06-22T03:00:00+08:00")
	got := NextBoundary(at, location)
	if want := "2026-06-22T04:00:00+08:00"; got.Format(time.RFC3339) != want {
		t.Fatalf("NextBoundary() = %s, want %s", got.Format(time.RFC3339), want)
	}

	at, _ = time.Parse(time.RFC3339, "2026-06-22T05:00:00+08:00")
	got = NextBoundary(at, location)
	if want := "2026-06-23T04:00:00+08:00"; got.Format(time.RFC3339) != want {
		t.Fatalf("NextBoundary() = %s, want %s", got.Format(time.RFC3339), want)
	}
}
