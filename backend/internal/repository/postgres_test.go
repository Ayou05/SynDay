package repository

import (
	"testing"

	"github.com/jackc/pgx/v5"
)

func TestPostgresPoolConfigUsesSimpleProtocolForTransactionPooler(t *testing.T) {
	config, err := postgresPoolConfig("postgres://user:password@example.com:6543/postgres")
	if err != nil {
		t.Fatal(err)
	}
	if config.ConnConfig.DefaultQueryExecMode != pgx.QueryExecModeSimpleProtocol {
		t.Fatalf("unexpected query mode: %v", config.ConnConfig.DefaultQueryExecMode)
	}
	if config.MaxConns != 8 {
		t.Fatalf("unexpected max connections: %d", config.MaxConns)
	}
}

func TestPostgresPoolConfigKeepsPreparedStatementsForDirectConnection(t *testing.T) {
	config, err := postgresPoolConfig("postgres://user:password@example.com:5432/postgres")
	if err != nil {
		t.Fatal(err)
	}
	if config.ConnConfig.DefaultQueryExecMode == pgx.QueryExecModeSimpleProtocol {
		t.Fatal("direct connection unexpectedly uses simple protocol")
	}
}
