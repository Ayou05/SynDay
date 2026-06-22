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

func (a *API) plans(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	plans, err := a.repo.Plans(r.Context(), user.ID)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"plans": plans})
}

func validPlan(input model.PlanInput) bool {
	if strings.TrimSpace(input.Title) == "" || len([]rune(strings.TrimSpace(input.Title))) > 200 {
		return false
	}
	if input.Category != "course" && input.Category != "self_study" && input.Category != "temporary" {
		return false
	}
	if input.Recurrence != "once" && input.Recurrence != "daily" && input.Recurrence != "weekly" {
		return false
	}
	if _, err := time.Parse("2006-01-02", input.StartsOn); err != nil {
		return false
	}
	if input.EndsOn != nil {
		end, err := time.Parse("2006-01-02", *input.EndsOn)
		start, _ := time.Parse("2006-01-02", input.StartsOn)
		if err != nil || end.Before(start) {
			return false
		}
	}
	if input.Recurrence == "weekly" {
		if len(input.Weekdays) == 0 || len(input.Weekdays) > 7 {
			return false
		}
		seen := map[int16]bool{}
		for _, weekday := range input.Weekdays {
			if weekday < 1 || weekday > 7 || seen[weekday] {
				return false
			}
			seen[weekday] = true
		}
	}
	return true
}

func (a *API) createPlan(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.PlanInput
	if err := decodeJSON(r, &input); err != nil || !validPlan(input) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "计划内容不完整"})
		return
	}
	plan, err := a.repo.CreatePlan(r.Context(), user.ID, input)
	if err != nil {
		writeInternalError(w)
		return
	}
	today := timeutil.BusinessDate(time.Now(), a.cfg.BusinessLocation)
	_, _ = a.repo.GenerateDay(r.Context(), today)
	writeJSON(w, http.StatusCreated, plan)
}

func (a *API) updatePlan(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.PlanInput
	if err := decodeJSON(r, &input); err != nil || !validPlan(input) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "计划内容不完整"})
		return
	}
	plan, err := a.repo.UpdatePlan(r.Context(), user.ID, chi.URLParam(r, "planID"), input)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, plan)
}

func (a *API) disablePlan(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	if err := a.repo.DisablePlan(r.Context(), user.ID, chi.URLParam(r, "planID")); err != nil {
		writeRepositoryError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
