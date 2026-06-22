package scheduler

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/repository"
	"github.com/catclaw-cloud/synday/backend/internal/service"
	"github.com/catclaw-cloud/synday/backend/internal/timeutil"
	"github.com/robfig/cron/v3"
)

type Scheduler struct {
	cron     *cron.Cron
	repo     *repository.Postgres
	location *time.Location
	ai       *service.AIService
	notify   *service.NotificationService
}

func New(
	repo *repository.Postgres,
	location *time.Location,
	aiService *service.AIService,
	notificationService *service.NotificationService,
) *Scheduler {
	return &Scheduler{
		cron: cron.New(
			cron.WithLocation(location),
			cron.WithChain(cron.SkipIfStillRunning(cron.DefaultLogger)),
		),
		repo:     repo,
		location: location,
		ai:       aiService,
		notify:   notificationService,
	}
}

func (s *Scheduler) Start() error {
	if _, err := s.cron.AddFunc("0 4 * * *", s.runBoundary); err != nil {
		return err
	}
	if _, err := s.cron.AddFunc("30 23 * * *", s.runReviewDrafts); err != nil {
		return err
	}
	if _, err := s.cron.AddFunc("10 4 1 * *", s.runPreviousMonthReport); err != nil {
		return err
	}
	if _, err := s.cron.AddFunc("20 4 * * *", s.runAccountPurge); err != nil {
		return err
	}
	if _, err := s.cron.AddFunc("* * * * *", s.runDueFocusCompletion); err != nil {
		return err
	}
	s.cron.Start()
	return nil
}

func (s *Scheduler) runDueFocusCompletion() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	count, err := s.repo.CompleteDueFocusSessions(ctx)
	if err != nil {
		slog.Error("complete due focus sessions", "error", err)
		return
	}
	if count > 0 {
		slog.Info("countdown focus sessions completed", "count", count)
	}
}

func (s *Scheduler) Stop(ctx context.Context) error {
	stopContext := s.cron.Stop()
	select {
	case <-stopContext.Done():
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (s *Scheduler) runBoundary() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	now := time.Now().In(s.location)
	today := timeutil.BusinessDate(now, s.location)
	yesterday := today.AddDate(0, 0, -1)

	settlement, err := s.repo.SettleDay(ctx, yesterday)
	if err != nil {
		slog.Error("settle business day", "date", yesterday, "error", err)
		return
	}
	if s.notify != nil {
		milestones, milestoneErr := s.repo.StreakMilestonesForDate(ctx, yesterday)
		if milestoneErr != nil {
			slog.Error("query streak milestones", "date", yesterday, "error", milestoneErr)
		} else {
			for _, milestone := range milestones {
				_ = s.notify.NotifyPartner(
					ctx,
					milestone.UserID,
					"streak_milestone",
					"TA 达成了新的里程碑",
					fmt.Sprintf("连续学习 %d 天，今天值得替 TA 开心。", milestone.Days),
					fmt.Sprintf("streak-milestone:%s:%d", milestone.UserID, milestone.Days),
					"streak_milestone.wav",
					map[string]any{"days": milestone.Days},
				)
			}
		}
	}
	if _, err := s.repo.RefreshReviewData(ctx, yesterday); err != nil {
		slog.Error("finalize review data", "date", yesterday, "error", err)
	}
	generated, err := s.repo.GenerateDay(ctx, today)
	if err != nil {
		slog.Error("generate daily tasks", "date", today, "error", err)
		return
	}
	if s.ai != nil {
		s.ai.PrefetchEncouragements(ctx, today.Format("2006-01-02"))
	}
	slog.Info("business boundary complete", "settlement", string(settlement), "generated_tasks", generated)
}

func (s *Scheduler) runReviewDrafts() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()
	date := timeutil.BusinessDate(time.Now(), s.location)
	count, err := s.repo.GenerateReviewDrafts(ctx, date)
	if err != nil {
		slog.Error("generate review drafts", "date", date, "error", err)
		return
	}
	if s.ai != nil {
		s.ai.EnhanceReviews(ctx, date.Format("2006-01-02"))
	}
	slog.Info("review drafts generated", "date", date, "count", count)
}

func (s *Scheduler) runPreviousMonthReport() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()
	now := time.Now().In(s.location)
	thisMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, s.location)
	previousMonth := thisMonth.AddDate(0, -1, 0)
	count, err := s.repo.GenerateMonthlyReports(ctx, previousMonth)
	if err != nil {
		slog.Error("generate monthly reports", "month", previousMonth, "error", err)
		return
	}
	slog.Info("monthly reports generated", "month", previousMonth, "count", count)
}

func (s *Scheduler) runAccountPurge() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	count, err := s.repo.PurgeDeletedAccounts(ctx)
	if err != nil {
		slog.Error("purge deleted accounts", "error", err)
		return
	}
	if count > 0 {
		slog.Info("deleted accounts purged", "count", count)
	}
}
