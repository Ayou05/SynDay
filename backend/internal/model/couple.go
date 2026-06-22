package model

import (
	"encoding/json"
	"time"
)

type PairingToken struct {
	ID            string    `json:"id"`
	Token         string    `json:"token,omitempty"`
	Code          string    `json:"code"`
	ExpiresAt     time.Time `json:"expires_at"`
	ClaimedBy     *string   `json:"claimed_by,omitempty"`
	CreatorReady  bool      `json:"creator_ready"`
	ClaimantReady bool      `json:"claimant_ready"`
}

type PairingClaimInput struct {
	Token string `json:"token"`
	Code  string `json:"code"`
}

type PairingConfirmation struct {
	PairingID string `json:"pairing_id"`
	Status    string `json:"status"`
	BindingID string `json:"binding_id,omitempty"`
}

type PartnerOverview struct {
	UserID            string     `json:"user_id"`
	DisplayName       string     `json:"display_name"`
	CompletionPercent int        `json:"completion_percent"`
	CurrentStreak     int        `json:"current_streak"`
	IsFocusing        bool       `json:"is_focusing"`
	FocusStartedAt    *time.Time `json:"focus_started_at,omitempty"`
	FocusMode         *string    `json:"focus_mode,omitempty"`
	FocusRoomID       *string    `json:"focus_room_id,omitempty"`
	Tasks             []Task     `json:"tasks"`
}

type JoinFocusInput struct {
	RoomID      string `json:"room_id"`
	Mode        string `json:"mode"`
	OperationID string `json:"operation_id"`
}

type CoupleMonthlyReport struct {
	Month       string          `json:"month"`
	Metrics     json.RawMessage `json:"metrics"`
	GeneratedAt time.Time       `json:"generated_at"`
}
