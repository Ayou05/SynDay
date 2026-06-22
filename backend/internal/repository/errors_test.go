package repository

import (
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
)

func TestAsInvalidStateMapsPolicyAndConstraintErrors(t *testing.T) {
	for _, code := range []string{"P0001", "23505", "23514", "23P01"} {
		err := asInvalidState(&pgconn.PgError{Code: code, Message: "policy rejected"})
		if !errors.Is(err, ErrInvalidState) {
			t.Fatalf("code %s was not mapped to ErrInvalidState: %v", code, err)
		}
	}
}

func TestAsInvalidStatePreservesOtherErrors(t *testing.T) {
	source := errors.New("connection lost")
	if got := asInvalidState(source); !errors.Is(got, source) {
		t.Fatalf("unexpected error mapping: %v", got)
	}
}
