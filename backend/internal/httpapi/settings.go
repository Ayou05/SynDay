package httpapi

import (
	"net/http"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/auth"
	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/go-chi/chi/v5"
)

func (a *API) settings(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	settings, err := a.repo.Settings(r.Context(), user.ID)
	if err != nil {
		writeInternalError(w)
		return
	}
	leaves, err := a.repo.LeaveDays(r.Context(), user.ID)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"settings": settings, "leave_days": leaves})
}

func (a *API) updateSettings(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.Settings
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	if input.AITone != "restrained" && input.AITone != "companion" && input.AITone != "concise" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "无效 AI 语气"})
		return
	}
	settings, err := a.repo.UpdateSettings(r.Context(), user.ID, input)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusOK, settings)
}

func (a *API) createLeave(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.LeaveInput
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	if input.Kind != "weekly_rest" && input.Kind != "temporary_leave" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "无效休息类型"})
		return
	}
	if input.Kind == "weekly_rest" {
		if input.Weekday == nil || *input.Weekday < 1 || *input.Weekday > 7 || input.BusinessDate != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "固定休息日需要有效星期"})
			return
		}
	} else {
		if input.BusinessDate == nil || input.Weekday != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "临时请假需要有效日期"})
			return
		}
		if _, err := time.Parse("2006-01-02", *input.BusinessDate); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "请假日期格式错误"})
			return
		}
	}
	day, err := a.repo.CreateLeaveDay(r.Context(), user.ID, input)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusCreated, day)
}

func (a *API) deleteLeave(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	if err := a.repo.DeleteLeaveDay(r.Context(), user.ID, chi.URLParam(r, "leaveID")); err != nil {
		writeRepositoryError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
