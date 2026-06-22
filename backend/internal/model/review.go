package model

import (
	"encoding/json"
	"time"
)

type Review struct {
	ID             string          `json:"id"`
	BusinessDate   string          `json:"business_date"`
	Title          string          `json:"title"`
	FullText       string          `json:"full_text"`
	CompactText    string          `json:"compact_text"`
	StructuredData json.RawMessage `json:"structured_data"`
	AIStatus       string          `json:"ai_status"`
	GeneratedAt    *time.Time      `json:"generated_at,omitempty"`
	FinalizedAt    *time.Time      `json:"finalized_at,omitempty"`
	Version        int64           `json:"version"`
}

type UpdateReviewInput struct {
	FullText string `json:"full_text"`
	Version  int64  `json:"version"`
}

type CalendarDay struct {
	BusinessDate string `json:"business_date"`
	Qualified    bool   `json:"qualified"`
	Exempt       bool   `json:"exempt"`
	TaskCount    int    `json:"task_completed_count"`
	FocusSeconds int    `json:"focus_seconds"`
}
