package httpapi

import (
	"net/http"

	"github.com/catclaw-cloud/synday/backend/internal/auth"
)

func (a *API) requestAccountDeletion(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	requestedAt, err := a.repo.RequestAccountDeletion(r.Context(), user.ID)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]any{
		"requested_at": requestedAt,
		"purge_after":  requestedAt.AddDate(0, 0, 7),
	})
}

func (a *API) cancelAccountDeletion(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	if err := a.repo.CancelAccountDeletion(r.Context(), user.ID); err != nil {
		writeInternalError(w)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) unbindCouple(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	if err := a.repo.UnbindCouple(r.Context(), user.ID); err != nil {
		writeRepositoryError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
