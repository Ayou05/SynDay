package httpapi

import (
	"context"
	"net/http"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/auth"
	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/catclaw-cloud/synday/backend/internal/timeutil"
)

func (a *API) joinSharedFocus(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.JoinFocusInput
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	if input.RoomID == "" || input.OperationID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "room_id 和 operation_id 必填"})
		return
	}
	now := time.Now()
	session, err := a.repo.JoinSharedFocus(
		r.Context(),
		user.ID,
		timeutil.AttributionDate(now, a.cfg.BusinessLocation),
		now,
		input,
	)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	if a.notifications != nil {
		sessionID := session.ID
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
			defer cancel()
			_ = a.notifications.NotifyPartner(
				ctx,
				user.ID,
				"partner_joined_focus",
				"你们开始一起学习了",
				"TA 加入了你的专注",
				"partner-joined-focus:"+sessionID,
				"partner_join.wav",
				map[string]any{"session_id": sessionID, "room_id": input.RoomID},
			)
		}()
	}
	writeJSON(w, http.StatusCreated, session)
}
