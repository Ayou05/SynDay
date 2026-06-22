package model

import "time"

type Plan struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Category    string    `json:"category"`
	Recurrence  string    `json:"recurrence"`
	StartsOn    string    `json:"starts_on"`
	EndsOn      *string   `json:"ends_on,omitempty"`
	Weekdays    []int16   `json:"weekdays"`
	PlannedTime *string   `json:"planned_time,omitempty"`
	IsPinned    bool      `json:"is_pinned"`
	IsActive    bool      `json:"is_active"`
	Version     int64     `json:"version"`
	CreatedAt   time.Time `json:"created_at"`
}

type PlanInput struct {
	Title       string  `json:"title"`
	Category    string  `json:"category"`
	Recurrence  string  `json:"recurrence"`
	StartsOn    string  `json:"starts_on"`
	EndsOn      *string `json:"ends_on"`
	Weekdays    []int16 `json:"weekdays"`
	PlannedTime *string `json:"planned_time"`
	IsPinned    bool    `json:"is_pinned"`
	Version     int64   `json:"version"`
}
