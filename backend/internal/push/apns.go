package push

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"
)

var ErrNotConfigured = errors.New("push provider not configured")

type APNs struct {
	keyID      string
	teamID     string
	bundleID   string
	privateKey *ecdsa.PrivateKey
	client     *http.Client
	mu         sync.Mutex
	jwt        string
	jwtAt      time.Time
}

func NewAPNs(keyID, teamID, bundleID, privateKeyPEM string) (*APNs, error) {
	provider := &APNs{
		keyID:    strings.TrimSpace(keyID),
		teamID:   strings.TrimSpace(teamID),
		bundleID: strings.TrimSpace(bundleID),
		client:   &http.Client{Timeout: 8 * time.Second},
	}
	if provider.keyID == "" || provider.teamID == "" || strings.TrimSpace(privateKeyPEM) == "" {
		return provider, nil
	}
	block, _ := pem.Decode([]byte(strings.ReplaceAll(privateKeyPEM, `\n`, "\n")))
	if block == nil {
		return nil, errors.New("decode APNs private key PEM")
	}
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse APNs private key: %w", err)
	}
	ecdsaKey, ok := key.(*ecdsa.PrivateKey)
	if !ok {
		return nil, errors.New("APNs private key is not ECDSA")
	}
	provider.privateKey = ecdsaKey
	return provider, nil
}

func (a *APNs) Configured() bool {
	return a.privateKey != nil && a.bundleID != ""
}

func (a *APNs) Send(ctx context.Context, deviceToken, title, body, sound string, data map[string]any) error {
	if !a.Configured() {
		return ErrNotConfigured
	}
	token, err := a.providerToken()
	if err != nil {
		return err
	}
	payload := map[string]any{
		"aps": map[string]any{
			"alert": map[string]string{"title": title, "body": body},
			"sound": sound,
		},
	}
	for key, value := range data {
		payload[key] = value
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		"https://api.push.apple.com/3/device/"+deviceToken,
		bytes.NewReader(encoded),
	)
	if err != nil {
		return err
	}
	request.Header.Set("authorization", "bearer "+token)
	request.Header.Set("apns-topic", a.bundleID)
	request.Header.Set("apns-push-type", "alert")
	request.Header.Set("apns-priority", "10")
	request.Header.Set("content-type", "application/json")
	response, err := a.client.Do(request)
	if err != nil {
		return fmt.Errorf("send APNs request: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("APNs returned status %d", response.StatusCode)
	}
	return nil
}

func (a *APNs) providerToken() (string, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.jwt != "" && time.Since(a.jwtAt) < 50*time.Minute {
		return a.jwt, nil
	}
	now := time.Now()
	header, _ := json.Marshal(map[string]string{"alg": "ES256", "kid": a.keyID})
	claims, _ := json.Marshal(map[string]any{"iss": a.teamID, "iat": now.Unix()})
	unsigned := rawURL(header) + "." + rawURL(claims)
	hash := sha256Sum([]byte(unsigned))
	r, s, err := ecdsa.Sign(rand.Reader, a.privateKey, hash)
	if err != nil {
		return "", err
	}
	signature := make([]byte, 64)
	r.FillBytes(signature[:32])
	s.FillBytes(signature[32:])
	a.jwt = unsigned + "." + rawURL(signature)
	a.jwtAt = now
	return a.jwt, nil
}

func rawURL(value []byte) string {
	return base64.RawURLEncoding.EncodeToString(value)
}
