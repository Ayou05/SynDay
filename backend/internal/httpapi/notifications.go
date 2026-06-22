package httpapi

import (
	"net/http"
	"strings"

	"github.com/catclaw-cloud/synday/backend/internal/auth"
	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/go-chi/chi/v5"
)

func (a *API) registerDevice(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.DeviceTokenInput
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	input.Token = strings.TrimSpace(input.Token)
	input.DeviceID = strings.TrimSpace(input.DeviceID)
	if input.Token == "" || input.DeviceID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "token 和 device_id 必填"})
		return
	}
	if input.Platform != "ios" && input.Platform != "android" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "无效设备平台"})
		return
	}
	if input.Provider != "apns" && input.Provider != "oppo" && input.Provider != "fcm" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "无效推送服务"})
		return
	}
	if err := a.repo.RegisterDevice(r.Context(), user.ID, input); err != nil {
		writeInternalError(w)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) unreadNotifications(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	items, err := a.repo.UnreadNotifications(r.Context(), user.ID, 100)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"notifications": items})
}

func (a *API) readNotification(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	if err := a.repo.MarkNotificationRead(r.Context(), user.ID, chi.URLParam(r, "notificationID")); err != nil {
		writeRepositoryError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
