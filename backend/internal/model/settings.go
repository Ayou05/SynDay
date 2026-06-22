package model

type Settings struct {
	DisplayName                string  `json:"display_name"`
	AITone                     string  `json:"ai_tone"`
	ExternalCheckinEnabled     bool    `json:"external_checkin_enabled"`
	Bedtime                    *string `json:"bedtime,omitempty"`
	NotificationReviewEnabled  bool    `json:"notification_review_enabled"`
	NotificationBedtimeEnabled bool    `json:"notification_bedtime_enabled"`
	NotificationPartnerEnabled bool    `json:"notification_partner_enabled"`
	NotificationStreakEnabled  bool    `json:"notification_streak_enabled"`
}

type LeaveDay struct {
	ID           string  `json:"id"`
	Kind         string  `json:"kind"`
	BusinessDate *string `json:"business_date,omitempty"`
	Weekday      *int16  `json:"weekday,omitempty"`
}

type LeaveInput struct {
	Kind         string  `json:"kind"`
	BusinessDate *string `json:"business_date"`
	Weekday      *int16  `json:"weekday"`
}
