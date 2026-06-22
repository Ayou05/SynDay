package push

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const firebaseMessagingScope = "https://www.googleapis.com/auth/firebase.messaging"

type fcmCredentials struct {
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
	TokenURI    string `json:"token_uri"`
}

type FCM struct {
	projectID   string
	email       string
	privateKey  *rsa.PrivateKey
	tokenURI    string
	client      *http.Client
	mu          sync.Mutex
	accessToken string
	tokenExpiry time.Time
}

func NewFCM(projectID, credentialsJSON string) (*FCM, error) {
	f := &FCM{
		projectID: strings.TrimSpace(projectID),
		client:    &http.Client{Timeout: 8 * time.Second},
	}
	if f.projectID == "" || strings.TrimSpace(credentialsJSON) == "" {
		return f, nil
	}
	var credentials fcmCredentials
	if err := json.Unmarshal([]byte(credentialsJSON), &credentials); err != nil {
		return nil, fmt.Errorf("decode FCM credentials: %w", err)
	}
	block, _ := pem.Decode([]byte(strings.ReplaceAll(credentials.PrivateKey, `\n`, "\n")))
	if block == nil {
		return nil, errors.New("decode FCM private key PEM")
	}
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse FCM private key: %w", err)
	}
	rsaKey, ok := key.(*rsa.PrivateKey)
	if !ok {
		return nil, errors.New("FCM private key is not RSA")
	}
	f.email = credentials.ClientEmail
	f.privateKey = rsaKey
	f.tokenURI = credentials.TokenURI
	if f.tokenURI == "" {
		f.tokenURI = "https://oauth2.googleapis.com/token"
	}
	return f, nil
}

func (f *FCM) Configured() bool {
	return f.projectID != "" && f.email != "" && f.privateKey != nil
}

func (f *FCM) Send(
	ctx context.Context,
	deviceToken, title, body, sound string,
	data map[string]any,
) error {
	if !f.Configured() {
		return ErrNotConfigured
	}
	accessToken, err := f.token(ctx)
	if err != nil {
		return err
	}
	stringData := make(map[string]string, len(data))
	for key, value := range data {
		stringData[key] = fmt.Sprint(value)
	}
	payload := map[string]any{
		"message": map[string]any{
			"token": deviceToken,
			"notification": map[string]string{
				"title": title,
				"body":  body,
			},
			"data": stringData,
			"android": map[string]any{
				"priority": "high",
				"notification": map[string]string{
					"channel_id": channelForPayload(data),
					"sound":      strings.TrimSuffix(sound, ".wav"),
				},
			},
		},
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	endpoint := fmt.Sprintf(
		"https://fcm.googleapis.com/v1/projects/%s/messages:send",
		url.PathEscape(f.projectID),
	)
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(encoded))
	if err != nil {
		return err
	}
	request.Header.Set("Authorization", "Bearer "+accessToken)
	request.Header.Set("Content-Type", "application/json")
	response, err := f.client.Do(request)
	if err != nil {
		return fmt.Errorf("send FCM request: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		message, _ := io.ReadAll(io.LimitReader(response.Body, 2048))
		return fmt.Errorf("FCM returned status %d: %s", response.StatusCode, strings.TrimSpace(string(message)))
	}
	return nil
}

func (f *FCM) token(ctx context.Context) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.accessToken != "" && time.Until(f.tokenExpiry) > 5*time.Minute {
		return f.accessToken, nil
	}
	now := time.Now()
	header, _ := json.Marshal(map[string]string{"alg": "RS256", "typ": "JWT"})
	claims, _ := json.Marshal(map[string]any{
		"iss":   f.email,
		"scope": firebaseMessagingScope,
		"aud":   f.tokenURI,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	})
	unsigned := rawURL(header) + "." + rawURL(claims)
	digest := sha256.Sum256([]byte(unsigned))
	signature, err := rsa.SignPKCS1v15(rand.Reader, f.privateKey, crypto.SHA256, digest[:])
	if err != nil {
		return "", fmt.Errorf("sign FCM assertion: %w", err)
	}
	assertion := unsigned + "." + base64.RawURLEncoding.EncodeToString(signature)
	values := url.Values{
		"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"},
		"assertion":  {assertion},
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, f.tokenURI, strings.NewReader(values.Encode()))
	if err != nil {
		return "", err
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	response, err := f.client.Do(request)
	if err != nil {
		return "", fmt.Errorf("request FCM OAuth token: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return "", fmt.Errorf("FCM OAuth returned status %d", response.StatusCode)
	}
	var result struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(response.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("decode FCM OAuth token: %w", err)
	}
	if result.AccessToken == "" {
		return "", errors.New("empty FCM OAuth token")
	}
	f.accessToken = result.AccessToken
	f.tokenExpiry = now.Add(time.Duration(result.ExpiresIn) * time.Second)
	return f.accessToken, nil
}

func channelForPayload(data map[string]any) string {
	kind, _ := data["kind"].(string)
	switch kind {
	case "review_reminder":
		return "review"
	case "bedtime_reminder":
		return "bedtime"
	case "partner_task_completed":
		return "partner_task"
	case "partner_joined_focus":
		return "partner_join"
	case "streak_milestone":
		return "streak"
	default:
		return "partner_task"
	}
}
