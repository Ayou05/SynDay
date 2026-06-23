package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("usage: go run ./cmd/migrate migrations/006_example.sql [...]")
	}
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()
	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("connect database: %v", err)
	}

	conn, err := pool.Acquire(ctx)
	if err != nil {
		log.Fatalf("acquire migration connection: %v", err)
	}
	defer conn.Release()

	if _, err := conn.Exec(ctx, `select pg_advisory_lock(hashtext('synday-schema-migrations'))`); err != nil {
		log.Fatal(err)
	}
	defer conn.Exec(ctx, `select pg_advisory_unlock(hashtext('synday-schema-migrations'))`)

	if _, err := conn.Exec(ctx, `
		create table if not exists public.schema_migrations (
		  name text primary key,
		  checksum text not null,
		  applied_at timestamptz not null default now()
		)
	`); err != nil {
		log.Fatalf("create migration ledger: %v", err)
	}

	for _, path := range os.Args[1:] {
		if err := apply(ctx, conn, path); err != nil {
			log.Fatal(err)
		}
	}
}

func apply(ctx context.Context, conn *pgxpool.Conn, path string) error {
	content, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read %s: %w", path, err)
	}
	sum := sha256.Sum256(content)
	checksum := hex.EncodeToString(sum[:])
	name := filepath.Base(path)

	var stored string
	err = conn.QueryRow(ctx, `
		select checksum from public.schema_migrations where name = $1
	`, name).Scan(&stored)
	if err == nil {
		if stored != checksum {
			return fmt.Errorf("%s was already applied with a different checksum", name)
		}
		log.Printf("skip %s (already applied)", name)
		return nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("check %s: %w", name, err)
	}

	if _, err := conn.Exec(ctx, string(content)); err != nil {
		return fmt.Errorf("apply %s: %w", name, err)
	}
	if _, err := conn.Exec(ctx, `
		insert into public.schema_migrations (name, checksum) values ($1, $2)
	`, name, checksum); err != nil {
		return fmt.Errorf("record %s: %w", name, err)
	}
	log.Printf("applied %s", name)
	return nil
}
