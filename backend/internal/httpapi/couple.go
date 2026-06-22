package httpapi

import (
	"net/http"
	"strings"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/auth"
	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/catclaw-cloud/synday/backend/internal/timeutil"
	"github.com/go-chi/chi/v5"
)

func (a *API) createPairing(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	pairing, err := a.repo.CreatePairingToken(r.Context(), user.ID, 5*time.Minute)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusCreated, pairing)
}

func (a *API) claimPairing(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.PairingClaimInput
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	input.Token = strings.TrimSpace(input.Token)
	input.Code = strings.TrimSpace(input.Code)
	if input.Token == "" && input.Code == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "星图令牌或 6 位码必填"})
		return
	}
	pairing, err := a.repo.ClaimPairingToken(r.Context(), user.ID, input)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, pairing)
}

func (a *API) confirmPairing(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	result, err := a.repo.ConfirmPairing(r.Context(), user.ID, chi.URLParam(r, "pairingID"))
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (a *API) partnerOverview(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	overview, err := a.repo.PartnerOverview(
		r.Context(),
		user.ID,
		timeutil.BusinessDate(time.Now(), a.cfg.BusinessLocation),
	)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, overview)
}

func (a *API) coupleMonthlyReport(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	raw := r.URL.Query().Get("month")
	if raw == "" {
		now := time.Now().In(a.cfg.BusinessLocation)
		raw = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, a.cfg.BusinessLocation).Format("2006-01-02")
	}
	month, err := time.ParseInLocation("2006-01-02", raw, a.cfg.BusinessLocation)
	if err != nil || month.Day() != 1 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "month 必须是月份首日"})
		return
	}
	report, err := a.repo.CoupleMonthlyReport(r.Context(), user.ID, month)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, report)
}
