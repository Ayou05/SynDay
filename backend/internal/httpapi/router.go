package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/catclaw-cloud/synday/backend/internal/auth"
	"github.com/catclaw-cloud/synday/backend/internal/config"
	"github.com/catclaw-cloud/synday/backend/internal/model"
	"github.com/catclaw-cloud/synday/backend/internal/repository"
	"github.com/catclaw-cloud/synday/backend/internal/service"
	"github.com/catclaw-cloud/synday/backend/internal/timeutil"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

type API struct {
	cfg           config.Config
	repo          *repository.Postgres
	auth          *auth.Verifier
	ai            *service.AIService
	notifications *service.NotificationService
}

func New(
	cfg config.Config,
	repo *repository.Postgres,
	aiService *service.AIService,
	notificationService *service.NotificationService,
) http.Handler {
	api := &API{
		cfg:           cfg,
		repo:          repo,
		auth:          auth.NewVerifier(cfg.SupabaseURL, cfg.SupabasePublishable),
		ai:            aiService,
		notifications: notificationService,
	}
	router := chi.NewRouter()
	router.Use(middleware.RequestID)
	router.Use(middleware.RealIP)
	router.Use(middleware.Recoverer)
	router.Use(middleware.Timeout(25 * time.Second))
	router.Use(cors(cfg.AllowedOrigins))

	router.Get("/healthz", api.health)
	router.Get("/readyz", api.ready)
	router.Route("/v1", func(r chi.Router) {
		r.Get("/time", api.serverTime)
		r.Group(func(protected chi.Router) {
			protected.Use(api.auth.Middleware)
			protected.Get("/today", api.today)
			protected.Post("/streak/milestones/{milestone}/seen", api.markMilestoneSeen)
			protected.Get("/plans", api.plans)
			protected.Post("/plans", api.createPlan)
			protected.Put("/plans/{planID}", api.updatePlan)
			protected.Delete("/plans/{planID}", api.disablePlan)
			protected.Post("/tasks", api.createTask)
			protected.Patch("/tasks/{taskID}", api.updateTask)
			protected.Delete("/tasks/{taskID}", api.deleteTask)
			protected.Post("/focus/start", api.startFocus)
			protected.Post("/focus/stop", api.stopFocus)
			protected.Get("/focus/active", api.activeFocus)
			protected.Post("/focus/join", api.joinSharedFocus)
			protected.Post("/couple/pairings", api.createPairing)
			protected.Post("/couple/pairings/claim", api.claimPairing)
			protected.Post("/couple/pairings/{pairingID}/confirm", api.confirmPairing)
			protected.Get("/couple/partner", api.partnerOverview)
			protected.Get("/couple/reports", api.coupleMonthlyReport)
			protected.Delete("/couple/binding", api.unbindCouple)
			protected.Get("/reviews/current", api.review)
			protected.Put("/reviews/{reviewID}", api.updateReview)
			protected.Get("/calendar", api.calendar)
			protected.Get("/settings", api.settings)
			protected.Put("/settings", api.updateSettings)
			protected.Post("/settings/leave-days", api.createLeave)
			protected.Delete("/settings/leave-days/{leaveID}", api.deleteLeave)
			protected.Put("/devices/current", api.registerDevice)
			protected.Delete("/devices/current", api.unregisterDevice)
			protected.Get("/realtime/session", api.realtimeSession)
			protected.Get("/upload/token", api.uploadToken)
			protected.Get("/notifications", api.unreadNotifications)
			protected.Put("/notifications/{notificationID}/read", api.readNotification)
			protected.Delete("/account", api.requestAccountDeletion)
			protected.Post("/account/deletion/cancel", api.cancelAccountDeletion)
		})
	})
	return router
}

func cors(allowedOrigins []string) func(http.Handler) http.Handler {
	allowed := make(map[string]struct{}, len(allowedOrigins))
	for _, origin := range allowedOrigins {
		allowed[origin] = struct{}{}
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if _, ok := allowed[origin]; ok {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Vary", "Origin")
				w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Request-ID")
				w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
				w.Header().Set("Access-Control-Max-Age", "86400")
			}
			if r.Method == http.MethodOptions {
				if origin != "" {
					if _, ok := allowed[origin]; !ok {
						writeJSON(w, http.StatusForbidden, map[string]string{"error": "origin not allowed"})
						return
					}
				}
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func (a *API) health(w http.ResponseWriter, r *http.Request) {
	if err := a.repo.Health(r.Context()); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{
			"status": "unavailable",
			"error":  "database unavailable",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

func (a *API) ready(w http.ResponseWriter, r *http.Request) {
	if err := a.repo.Health(r.Context()); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{
			"status":   "unavailable",
			"database": false,
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":   "ready",
		"database": true,
		"capabilities": map[string]bool{
			"ai":       a.cfg.DeepSeekAPIKey != "",
			"realtime": a.cfg.GoEasyRestKey != "" || a.cfg.GoEasyAppKey != "",
			"apns": a.cfg.APNsKeyID != "" &&
				a.cfg.APNsTeamID != "" &&
				a.cfg.APNsPrivateKey != "",
			"fcm":   a.cfg.FCMProjectID != "" && a.cfg.FCMCredentialsJSON != "",
			"oppo":  a.cfg.OPPOAppKey != "" && a.cfg.OPPOMasterSecret != "",
			"qiniu": a.cfg.QiniuAccessKey != "" && a.cfg.QiniuSecretKey != "" && a.cfg.QiniuDomain != "",
		},
	})
}

func (a *API) serverTime(w http.ResponseWriter, _ *http.Request) {
	now := time.Now()
	writeJSON(w, http.StatusOK, map[string]any{
		"server_time":   now.UTC().Format(time.RFC3339Nano),
		"timezone":      "Asia/Shanghai",
		"business_date": timeutil.BusinessDateString(now, a.cfg.BusinessLocation),
	})
}

func (a *API) today(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	businessDate := timeutil.BusinessDate(time.Now(), a.cfg.BusinessLocation)
	tasks, summary, err := a.repo.Today(r.Context(), user.ID, businessDate)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"tasks":   tasks,
		"summary": summary,
	})
}

func (a *API) markMilestoneSeen(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var milestone int
	switch chi.URLParam(r, "milestone") {
	case "30":
		milestone = 30
	case "100":
		milestone = 100
	case "365":
		milestone = 365
	default:
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "无效里程碑"})
		return
	}
	if err := a.repo.MarkMilestoneSeen(r.Context(), user.ID, milestone); err != nil {
		writeRepositoryError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) createTask(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.CreateTaskInput
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	input.Title = strings.TrimSpace(input.Title)
	if input.Title == "" || len([]rune(input.Title)) > 200 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "任务标题需为 1–200 个字符"})
		return
	}
	if input.Category != "course" && input.Category != "self_study" && input.Category != "temporary" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "无效任务分类"})
		return
	}
	if input.OperationID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "operation_id 必填"})
		return
	}

	task, err := a.repo.CreateTask(
		r.Context(),
		user.ID,
		timeutil.BusinessDate(time.Now(), a.cfg.BusinessLocation),
		input,
	)
	if err != nil {
		writeInternalError(w)
		return
	}
	if a.ai != nil && a.ai.Available() {
		date := task.BusinessDate
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			a.ai.PrefetchEncouragements(ctx, date)
		}()
	}
	writeJSON(w, http.StatusCreated, task)
}

func (a *API) updateTask(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.UpdateTaskInput
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	if input.OperationID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "operation_id 必填"})
		return
	}
	task, err := a.repo.UpdateTask(
		r.Context(),
		user.ID,
		chi.URLParam(r, "taskID"),
		input,
		time.Now(),
	)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	if input.Action == "complete" && a.notifications != nil {
		taskID := task.ID
		taskTitle := task.Title
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
			defer cancel()
			_ = a.notifications.NotifyPartner(
				ctx,
				user.ID,
				"partner_task_completed",
				"TA 完成了一项任务",
				taskTitle,
				"task-completed:"+taskID,
				"partner_task.wav",
				map[string]any{"task_id": taskID},
			)
		}()
	}
	writeJSON(w, http.StatusOK, task)
}

func (a *API) deleteTask(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	if err := a.repo.DeleteTask(r.Context(), user.ID, chi.URLParam(r, "taskID")); err != nil {
		writeRepositoryError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) startFocus(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.StartFocusInput
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	switch input.Mode {
	case "solo_countup", "solo_countdown", "shared_countup", "shared_countdown":
	default:
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "无效专注模式"})
		return
	}
	if input.OperationID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "operation_id 必填"})
		return
	}
	if strings.Contains(input.Mode, "countdown") && (input.PlannedSeconds == nil || *input.PlannedSeconds < 60) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "倒计时至少 60 秒"})
		return
	}
	now := time.Now()
	session, err := a.repo.StartFocus(
		r.Context(),
		user.ID,
		timeutil.AttributionDate(now, a.cfg.BusinessLocation),
		now,
		input,
	)
	if err != nil {
		writeInternalError(w)
		return
	}
	writeJSON(w, http.StatusCreated, session)
}

func (a *API) stopFocus(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	var input model.StopFocusInput
	if err := decodeJSON(r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	if input.OperationID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "operation_id 必填"})
		return
	}
	session, err := a.repo.StopFocus(r.Context(), user.ID, time.Now(), 60, input.OperationID)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, session)
}

func (a *API) activeFocus(w http.ResponseWriter, r *http.Request) {
	user, _ := auth.UserFromContext(r.Context())
	session, err := a.repo.ActiveFocus(r.Context(), user.ID)
	if err != nil {
		writeRepositoryError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, session)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func decodeJSON(r *http.Request, target any) error {
	decoder := json.NewDecoder(io.LimitReader(r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return errors.New("请求内容格式错误")
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return errors.New("请求只能包含一个 JSON 对象")
	}
	return nil
}

func writeRepositoryError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, repository.ErrNotFound):
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "未找到"})
	case errors.Is(err, repository.ErrVersionConflict):
		writeJSON(w, http.StatusConflict, map[string]string{"error": "数据已在其他设备更新，请刷新后重试"})
	case errors.Is(err, repository.ErrInvalidState):
		writeJSON(w, http.StatusUnprocessableEntity, map[string]string{"error": "当前状态不允许该操作"})
	default:
		writeInternalError(w)
	}
}

func writeInternalError(w http.ResponseWriter) {
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "服务暂时不可用"})
}
