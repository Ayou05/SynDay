package realtime

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type GoEasy struct {
	endpoint string
	appKey   string
	client   *http.Client
}

func NewGoEasy(endpoint, appKey string) *GoEasy {
	return &GoEasy{
		endpoint: strings.TrimSpace(endpoint),
		appKey:   strings.TrimSpace(appKey),
		client:   &http.Client{Timeout: 5 * time.Second},
	}
}

func (g *GoEasy) Publish(ctx context.Context, channel, event string, payload map[string]any) error {
	if g.endpoint == "" || g.appKey == "" {
		return nil
	}
	content, err := json.Marshal(map[string]any{"event": event, "payload": payload})
	if err != nil {
		return err
	}
	values := url.Values{
		"appkey":  {g.appKey},
		"channel": {channel},
		"content": {string(content)},
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, g.endpoint, strings.NewReader(values.Encode()))
	if err != nil {
		return err
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	response, err := g.client.Do(request)
	if err != nil {
		return fmt.Errorf("publish GoEasy event: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return errors.New("GoEasy publish failed")
	}
	return nil
}
