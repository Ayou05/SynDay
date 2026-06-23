package config

import (
	"errors"
	"os"
	"strings"
	"time"
	_ "time/tzdata"
)

type Config struct {
	Environment         string
	ListenAddr          string
	DatabaseURL         string
	SupabaseURL         string
	SupabasePublishable string
	SupabaseJWTSecret   string
	SupabaseServiceRole string
	DeepSeekAPIKey      string
	DeepSeekBaseURL     string
	DeepSeekModel       string
	GoEasyHost          string
	GoEasyAppKey        string
	GoEasyRestKey       string
	GoEasyRestURL       string
	QiniuAccessKey      string
	QiniuSecretKey      string
	QiniuBucket         string
	QiniuDomain         string
	APNsKeyID           string
	APNsTeamID          string
	APNsBundleID        string
	APNsPrivateKey      string
	APNsEnvironment     string
	OPPOAppKey          string
	OPPOMasterSecret    string
	OPPOPushEndpoint    string
	FCMProjectID        string
	FCMCredentialsJSON  string
	AllowedOrigins      []string
	BusinessLocation    *time.Location
}

func Load() (Config, error) {
	location, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		return Config{}, err
	}

	cfg := Config{
		Environment:         env("APP_ENV", "development"),
		ListenAddr:          env("LISTEN_ADDR", ":8080"),
		DatabaseURL:         strings.TrimSpace(os.Getenv("DATABASE_URL")),
		SupabaseURL:         strings.TrimRight(strings.TrimSpace(os.Getenv("SUPABASE_URL")), "/"),
		SupabasePublishable: strings.TrimSpace(os.Getenv("SUPABASE_PUBLISHABLE_KEY")),
		SupabaseJWTSecret:   strings.TrimSpace(os.Getenv("SUPABASE_JWT_SECRET")),
		SupabaseServiceRole: strings.TrimSpace(os.Getenv("SUPABASE_SERVICE_ROLE_KEY")),
		DeepSeekAPIKey:      strings.TrimSpace(os.Getenv("DEEPSEEK_API_KEY")),
		DeepSeekBaseURL:     env("DEEPSEEK_BASE_URL", "https://api.deepseek.com"),
		DeepSeekModel:       env("DEEPSEEK_MODEL", "deepseek-v4-flash"),
		GoEasyHost:          env("GOEASY_HOST", "hangzhou.goeasy.io"),
		GoEasyAppKey:        strings.TrimSpace(os.Getenv("GOEASY_APP_KEY")),
		GoEasyRestKey:       strings.TrimSpace(os.Getenv("GOEASY_REST_KEY")),
		GoEasyRestURL:       env("GOEASY_REST_URL", "https://rest-hangzhou.goeasy.io/v2/pubsub/publish"),
		QiniuAccessKey:      strings.TrimSpace(os.Getenv("QINIU_ACCESS_KEY")),
		QiniuSecretKey:      strings.TrimSpace(os.Getenv("QINIU_SECRET_KEY")),
		QiniuBucket:         env("QINIU_BUCKET", "synday"),
		QiniuDomain:         strings.TrimRight(strings.TrimSpace(os.Getenv("QINIU_DOMAIN")), "/"),
		APNsKeyID:           strings.TrimSpace(os.Getenv("APNS_KEY_ID")),
		APNsTeamID:          strings.TrimSpace(os.Getenv("APNS_TEAM_ID")),
		APNsBundleID:        env("APNS_BUNDLE_ID", "cloud.catclaw.synday"),
		APNsPrivateKey:      strings.TrimSpace(os.Getenv("APNS_PRIVATE_KEY")),
		APNsEnvironment:     env("APNS_ENVIRONMENT", "development"),
		OPPOAppKey:          strings.TrimSpace(os.Getenv("OPPO_APP_KEY")),
		OPPOMasterSecret:    strings.TrimSpace(os.Getenv("OPPO_MASTER_SECRET")),
		OPPOPushEndpoint:    strings.TrimSpace(os.Getenv("OPPO_PUSH_ENDPOINT")),
		FCMProjectID:        strings.TrimSpace(os.Getenv("FCM_PROJECT_ID")),
		FCMCredentialsJSON:  strings.TrimSpace(os.Getenv("FCM_CREDENTIALS_JSON")),
		AllowedOrigins: splitCSV(env(
			"ALLOWED_ORIGINS",
			"tauri://localhost,http://tauri.localhost,https://tauri.localhost,http://localhost:1420",
		)),
		BusinessLocation: location,
	}

	if cfg.DatabaseURL == "" {
		return Config{}, errors.New("DATABASE_URL is required")
	}
	if cfg.SupabaseURL == "" {
		return Config{}, errors.New("SUPABASE_URL is required")
	}
	if cfg.SupabasePublishable == "" {
		return Config{}, errors.New("SUPABASE_PUBLISHABLE_KEY is required")
	}
	return cfg, nil
}

func splitCSV(value string) []string {
	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

func env(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}
