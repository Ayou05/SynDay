package upload

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"
)

// QiniuPutPolicy 七牛上传策略
type QiniuPutPolicy struct {
	Scope      string `json:"scope"`
	Deadline   int64  `json:"deadline"`
	ReturnBody string `json:"returnBody,omitempty"`
	MimeLimit  string `json:"mimeLimit,omitempty"`
	FSizeLimit int64  `json:"fsizeLimit,omitempty"`
	SaveKey    string `json:"saveKey,omitempty"`
}

// QiniuUploadToken 生成七牛上传凭证
func QiniuUploadToken(accessKey, secretKey, bucket, domain, keyPrefix string, ttl time.Duration) (map[string]string, error) {
	if keyPrefix == "" {
		keyPrefix = "uploads/"
	}
	saveKey := fmt.Sprintf("%s$(year)/$(mon)/$(day)/$(uuid)", keyPrefix)
	deadline := time.Now().Add(ttl).Unix()

	policy := QiniuPutPolicy{
		Scope:      bucket,
		Deadline:   deadline,
		ReturnBody: `{"key":"$(key)","hash":"$(etag)","fsize":$(fsize),"mimeType":"$(mimeType)"}`,
		MimeLimit:  "image/*", // 只允许图片
		FSizeLimit: 20 << 20,  // 最大20MB
		SaveKey:    saveKey,
	}

	policyJSON, err := json.Marshal(policy)
	if err != nil {
		return nil, fmt.Errorf("序列化上传策略失败: %w", err)
	}

	encodedPolicy := base64URLEncode(policyJSON)
	sign := hmacSHA1(secretKey, encodedPolicy)
	encodedSign := base64URLEncode(sign)

	token := fmt.Sprintf("%s:%s:%s", accessKey, encodedSign, encodedPolicy)
	uploadURL := "https://up-z2.qiniup.com" // 华东-浙江

	return map[string]string{
		"token":     token,
		"key":       saveKey,
		"domain":    domain,
		"uploadUrl": uploadURL,
	}, nil
}

func base64URLEncode(data []byte) string {
	return base64.URLEncoding.WithPadding(base64.NoPadding).EncodeToString(data)
}

func hmacSHA1(secretKey, data string) []byte {
	mac := hmac.New(sha1.New, []byte(secretKey))
	mac.Write([]byte(data))
	return mac.Sum(nil)
}
