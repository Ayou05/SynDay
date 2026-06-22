package model

import "time"

type Task struct {
	ID            string     `json:"id"`
	BusinessDate  string     `json:"business_date"`
	Title         string     `json:"title"`
	Category      string     `json:"category"`
	Status        string     `json:"status"`
	PlannedTime   *string    `json:"planned_time,omitempty"`
	IsPinned      bool       `json:"is_pinned"`
	SortOrder     int        `json:"sort_order"`
	CompletedAt   *time.Time `json:"completed_at,omitempty"`
	Encouragement *string    `json:"encouragement,omitempty"`
	Version       int64      `json:"version"`
	CreatedAt     time.Time  `json:"created_at"`
}

type TodaySummary struct {
	BusinessDate      string `json:"business_date"`
	TotalTasks        int    `json:"total_tasks"`
	CompletedTasks    int    `json:"completed_tasks"`
	CompletionPercent int    `json:"completion_percent"`
	FocusSeconds      int    `json:"focus_seconds"`
	CurrentStreak     int    `json:"current_streak"`
	PendingMilestone  int    `json:"pending_milestone,omitempty"`
}

type CreateTaskInput struct {
	Title       string  `json:"title"`
	Category    string  `json:"category"`
	PlannedTime *string `json:"planned_time"`
	IsPinned    bool    `json:"is_pinned"`
	OperationID string  `json:"operation_id"`
}

type UpdateTaskInput struct {
	Action      string `json:"action"`
	Version     int64  `json:"version"`
	OperationID string `json:"operation_id"`
}
