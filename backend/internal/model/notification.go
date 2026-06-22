package model

type DeviceTokenInput struct {
	Platform string `json:"platform"`
	Provider string `json:"provider"`
	Token    string `json:"token"`
	DeviceID string `json:"device_id"`
}

type DeviceToken struct {
	Provider string
	Token    string
}

type Notification struct {
	ID      string         `json:"id"`
	Kind    string         `json:"kind"`
	Title   string         `json:"title"`
	Body    string         `json:"body"`
	Payload map[string]any `json:"payload"`
}
