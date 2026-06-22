package httpapi

import (
	"net/http"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/auth"
	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/catclaw-cloud/synday/backend/internal/timeutil"
	"github.com/go-chi/chi/v5"
)

func (a *API) review(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	date := timeutil.BusinessDate(time.Now(), a.cfg.BusinessLocation)
	if raw := r.URL.Query().Get("date"); raw != "" {
		parsed, err := time.ParseInLocation("2006-01-02", raw, a.cfg.BusinessLocation)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "日期格式错误"})
			return
		}
		date = parsed
	}
	review, err := a.repo.Review(r.Context(), user.ID, date)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, review)
}

func (a *API) updateReview(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.UpdateReviewInput
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	review, err := a.repo.UpdateReview(r.Context(), user.ID, chi.URLParam(r, "reviewID"), input)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, review)
}

func (a *API) calendar(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	raw := r.URL.Query().Get("month")
	if raw == "" {
		now := time.Now().In(a.cfg.BusinessLocation)
		raw = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, a.cfg.BusinessLocation).Format("2006-01-02")
	}
	start, err := time.ParseInLocation("2006-01-02", raw, a.cfg.BusinessLocation)
	if err != nil || start.Day() != 1 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "month 必须是月份首日"})
		return
	}
	days, err := a.repo.Calendar(r.Context(), user.ID, start, start.AddDate(0, 1, 0))
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"month": raw, "days": days})
}
