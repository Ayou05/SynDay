package auth

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"
)

var ErrInvalidToken = errors.New("invalid access token")

type User struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

type cacheEntry struct {
	user      User
	expiresAt time.Time
}

// Verifier validates Supabase access tokens through the Auth user endpoint and
// caches successful validations briefly. This supports both legacy HS256 and
// current asymmetric signing keys without placing signing secrets in clients.
type Verifier struct {
	baseURL        string
	publishableKey string
	client         *http.Client
	mu             sync.RWMutex
	cache          map[string]cacheEntry
}

func NewVerifier(baseURL, publishableKey string) *Verifier {
	return &Verifier{
		baseURL:        strings.TrimRight(baseURL, "/"),
		publishableKey: publishableKey,
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
		cache: make(map[string]cacheEntry),
	}
}

func (v *Verifier) Verify(ctx context.Context, token string) (User, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return User{}, ErrInvalidToken
	}

	cacheKey := tokenHash(token)
	now := time.Now()
	v.mu.RLock()
	entry, ok := v.cache[cacheKey]
	v.mu.RUnlock()
	if ok && now.Before(entry.expiresAt) {
		return entry.user, nil
	}

	request, err := http.NewRequestWithContext(ctx, http.MethodGet, v.baseURL+"/auth/v1/user", nil)
	if err != nil {
		return User{}, fmt.Errorf("build auth request: %w", err)
	}
	request.Header.Set("apikey", v.publishableKey)
	request.Header.Set("Authorization", "Bearer "+token)

	response, err := v.client.Do(request)
	if err != nil {
		return User{}, fmt.Errorf("verify token: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return User{}, ErrInvalidToken
	}

	var user User
	if err := json.NewDecoder(response.Body).Decode(&user); err != nil {
		return User{}, fmt.Errorf("decode auth user: %w", err)
	}
	if user.ID == "" {
		return User{}, ErrInvalidToken
	}

	v.mu.Lock()
	v.cache[cacheKey] = cacheEntry{user: user, expiresAt: now.Add(5 * time.Minute)}
	if len(v.cache) > 2048 {
		for key, candidate := range v.cache {
			if now.After(candidate.expiresAt) {
				delete(v.cache, key)
			}
		}
	}
	v.mu.Unlock()
	return user, nil
}

func tokenHash(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
