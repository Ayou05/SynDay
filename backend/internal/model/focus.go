package model

import "time"

type FocusSession struct {
	ID               string     `json:"id"`
	BusinessDate     string     `json:"business_date"`
	Mode             string     `json:"mode"`
	Status           string     `json:"status"`
	StartedAt        time.Time  `json:"started_at"`
	PlannedSeconds   *int       `json:"planned_seconds,omitempty"`
	EndedAt          *time.Time `json:"ended_at,omitempty"`
	DurationSeconds  int        `json:"duration_seconds"`
	IsValid          bool       `json:"is_valid"`
	ShareWithPartner bool       `json:"share_with_partner"`
	SharedRoomID     *string    `json:"shared_room_id,omitempty"`
	Version          int64      `json:"version"`
}

type StartFocusInput struct {
	Mode             string `json:"mode"`
	PlannedSeconds   *int   `json:"planned_seconds"`
	ShareWithPartner bool   `json:"share_with_partner"`
	OperationID      string `json:"operation_id"`
}

type StopFocusInput struct {
	OperationID string `json:"operation_id"`
}
