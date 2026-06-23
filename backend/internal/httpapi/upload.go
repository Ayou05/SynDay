package httpapi

import (
	"net/http"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/upload"
)

func (a *API) uploadToken(w http.ResponseWriter, r *http.Request) {
	if a.cfg.QiniuAccessKey == "" || a.cfg.QiniuSecretKey == "" || a.cfg.QiniuDomain == "" {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "图片存储未配置"})
		return
	}
	scene := r.URL.Query().Get("scene")
	keyPrefix := "uploads/"
	switch scene {
	case "chat":
		keyPrefix = "chat/"
	case "avatar":
		keyPrefix = "avatar/"
	case "album":
		keyPrefix = "album/"
	}
	token, err := upload.QiniuUploadToken(
		a.cfg.QiniuAccessKey,
		a.cfg.QiniuSecretKey,
		a.cfg.QiniuBucket,
		a.cfg.QiniuDomain,
		keyPrefix,
		30*time.Minute,
	)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusOK, token)
}
