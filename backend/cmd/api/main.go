package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/ai"
	"github.com/catclaw-cloud/synday/backend/internal/config"
	"github.com/catclaw-cloud/synday/backend/internal/httpapi"
	"github.com/catclaw-cloud/synday/backend/internal/push"
	"github.com/catclaw-cloud/synday/backend/internal/realtime"
	"github.com/catclaw-cloud/synday/backend/internal/repository"
	"github.com/catclaw-cloud/synday/backend/internal/scheduler"
	"github.com/catclaw-cloud/synday/backend/internal/service"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--healthcheck" {
		runHealthcheck()
		return
	}

	cfg, err := config.Load()
	if err != nil {
		slog.Error("load configuration", "error", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	repo, err := repository.NewPostgres(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("connect database", "error", err)
		os.Exit(1)
	}
	defer repo.Close()

	aiClient := ai.NewClient(cfg.DeepSeekAPIKey, cfg.DeepSeekBaseURL, cfg.DeepSeekModel)
	aiService := service.NewAIService(aiClient, repo, cfg.DeepSeekModel)
	apns, err := push.NewAPNs(cfg.APNsKeyID, cfg.APNsTeamID, cfg.APNsBundleID, cfg.APNsPrivateKey)
	if err != nil {
		slog.Error("configure APNs", "error", err)
		os.Exit(1)
	}
	fcm, err := push.NewFCM(cfg.FCMProjectID, cfg.FCMCredentialsJSON)
	if err != nil {
		slog.Error("configure FCM", "error", err)
		os.Exit(1)
	}
	goEasyKey := cfg.GoEasyRestKey
	if goEasyKey == "" {
		goEasyKey = cfg.GoEasyAppKey
	}
	goEasy := realtime.NewGoEasy(cfg.GoEasyRestURL, goEasyKey)
	notificationService := service.NewNotificationService(repo, apns, fcm, goEasy)
	jobs := scheduler.New(repo, cfg.BusinessLocation, aiService, notificationService)
	if err := jobs.Start(); err != nil {
		slog.Error("start scheduler", "error", err)
		os.Exit(1)
	}

	handler := httpapi.New(cfg, repo, aiService, notificationService)
	server := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      20 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		slog.Info("SynDay API listening", "address", cfg.ListenAddr)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("serve HTTP", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := jobs.Stop(shutdownCtx); err != nil {
		slog.Error("stop scheduler", "error", err)
	}
	if err := server.Shutdown(shutdownCtx); err != nil {
		slog.Error("graceful shutdown", "error", err)
	}
}

func runHealthcheck() {
	client := &http.Client{Timeout: 3 * time.Second}
	response, err := client.Get("http://127.0.0.1:8080/healthz")
	if err != nil {
		os.Exit(1)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		os.Exit(1)
	}
}
