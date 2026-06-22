package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/catclaw-cloud/synday/backend/internal/push"
	"github.com/catclaw-cloud/synday/backend/internal/realtime"
	"github.com/catclaw-cloud/synday/backend/internal/repository"
)

type NotificationService struct {
	repo     *repository.Postgres
	apns     *push.APNs
	fcm      *push.FCM
	realtime *realtime.GoEasy
}

func NewNotificationService(
	repo *repository.Postgres,
	apns *push.APNs,
	fcm *push.FCM,
	goEasy *realtime.GoEasy,
) *NotificationService {
	return &NotificationService{repo: repo, apns: apns, fcm: fcm, realtime: goEasy}
}

func (s *NotificationService) NotifyPartner(
	ctx context.Context,
	actorID, kind, title, body, dedupeKey, sound string,
	payload map[string]any,
) error {
	partnerID, err := s.repo.PartnerForNotification(ctx, actorID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil
		}
		return err
	}
	notification, err := s.repo.CreateNotification(ctx, partnerID, &actorID, kind, title, body, dedupeKey, payload)
	if err != nil {
		return err
	}
	payload["notification_id"] = notification.ID
	payload["kind"] = kind
	if err := s.realtime.Publish(ctx, "user:"+partnerID, kind, payload); err != nil {
		slog.Warn("publish realtime notification", "error", err)
	}
	tokens, err := s.repo.UserDeviceTokens(ctx, partnerID)
	if err != nil {
		return err
	}
	for _, token := range tokens {
		switch token.Provider {
		case "apns":
			if err := s.apns.Send(ctx, token.Token, title, body, sound, payload); err != nil && !errors.Is(err, push.ErrNotConfigured) {
				slog.Warn("send APNs notification", "error", err)
			}
		case "oppo", "fcm":
			if token.Provider == "fcm" {
				if err := s.fcm.Send(ctx, token.Token, title, body, sound, payload); err != nil && !errors.Is(err, push.ErrNotConfigured) {
					slog.Warn("send FCM notification", "error", err)
				}
			} else {
				// OPPO PUSH is enabled after the OPPO developer application is
				// approved. Durable notification rows and GoEasy prevent loss.
				slog.Debug("OPPO push adapter pending platform credentials")
			}
		default:
			return fmt.Errorf("unsupported push provider %q", token.Provider)
		}
	}
	return nil
}
