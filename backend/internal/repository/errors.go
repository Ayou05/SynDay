package repository

import (
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"
)

func asInvalidState(err error) error {
	if err == nil {
		return nil
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch pgErr.Code {
		case "P0001", "23505", "23514", "23P01":
			return fmt.Errorf("%w: %s", ErrInvalidState, pgErr.Message)
		}
	}
	return err
}
