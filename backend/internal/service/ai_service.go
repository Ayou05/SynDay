package service

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/ai"
	"github.com/catclaw-cloud/synday/backend/internal/repository"
)

type AIService struct {
	client *ai.Client
	repo   *repository.Postgres
	model  string
}

func NewAIService(client *ai.Client, repo *repository.Postgres, model string) *AIService {
	return &AIService{client: client, repo: repo, model: model}
}

func (s *AIService) Available() bool {
	return s.client.Available()
}

func (s *AIService) PrefetchEncouragements(ctx context.Context, businessDate string) {
	if !s.Available() {
		return
	}
	tasks, err := s.repo.MissingEncouragements(ctx, businessDate, 100)
	if err != nil {
		slog.Error("query AI encouragement work", "error", err)
		return
	}
	semaphore := make(chan struct{}, 3)
	var wait sync.WaitGroup
	for _, task := range tasks {
		task := task
		wait.Add(1)
		go func() {
			defer wait.Done()
			semaphore <- struct{}{}
			defer func() { <-semaphore }()
			itemCtx, cancel := context.WithTimeout(ctx, 4*time.Second)
			defer cancel()
			content, err := s.client.Encouragement(itemCtx, task.Title, task.Tone)
			if err != nil {
				slog.Warn("generate encouragement", "task_id", task.ID, "error", err)
				return
			}
			if err := s.repo.SaveEncouragement(itemCtx, task, content, s.model); err != nil {
				slog.Error("save encouragement", "task_id", task.ID, "error", err)
			}
		}()
	}
	wait.Wait()
}

func (s *AIService) EnhanceReviews(ctx context.Context, businessDate string) {
	if !s.Available() {
		return
	}
	reviews, err := s.repo.PendingReviews(ctx, businessDate, 20)
	if err != nil {
		slog.Error("query AI review work", "error", err)
		return
	}
	for _, review := range reviews {
		itemCtx, cancel := context.WithTimeout(ctx, 8*time.Second)
		result, err := s.client.Review(itemCtx, review.StructuredData)
		cancel()
		if err != nil {
			_ = s.repo.MarkReviewAIFailed(ctx, review.ID)
			slog.Warn("enhance daily review", "review_id", review.ID, "error", err)
			continue
		}
		if err := s.repo.SaveAIReview(ctx, review.ID, result.Full, result.Compact, s.model); err != nil {
			slog.Error("save AI review", "review_id", review.ID, "error", err)
		}
	}
}
