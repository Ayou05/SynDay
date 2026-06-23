package upload

import (
	"strings"
	"testing"
	"time"
)

func TestQiniuUploadToken(t *testing.T) {
	token, err := QiniuUploadToken("ak", "sk", "synday", "https://cdn.synday.catclaw.cloud", "chat/", time.Hour)
	if err != nil {
		t.Fatalf("生成 token 失败: %v", err)
	}
	if token["token"] == "" {
		t.Fatal("token 为空")
	}
	parts := strings.Split(token["token"], ":")
	if len(parts) != 3 {
		t.Fatalf("token 格式错误，应为 AK:Sign:EncodedPolicy，实际 %d 段", len(parts))
	}
	if parts[0] != "ak" {
		t.Errorf("token 第一段应为 accessKey，实际 %s", parts[0])
	}
	if token["domain"] != "https://cdn.synday.catclaw.cloud" {
		t.Errorf("domain 返回错误: %s", token["domain"])
	}
	if !strings.HasPrefix(token["key"], "chat/") {
		t.Errorf("key 前缀错误: %s", token["key"])
	}
	if token["uploadUrl"] == "" {
		t.Error("uploadUrl 为空")
	}
}

func TestQiniuUploadTokenDifferentScenes(t *testing.T) {
	scenes := []string{"chat", "avatar", "album", ""}
	for _, scene := range scenes {
		token, err := QiniuUploadToken("ak", "sk", "synday", "https://cdn.synday.catclaw.cloud", prefixForScene(scene), time.Hour)
		if err != nil {
			t.Fatalf("scene=%q 生成失败: %v", scene, err)
		}
		if token["token"] == "" {
			t.Fatalf("scene=%q token 为空", scene)
		}
	}
}

func prefixForScene(scene string) string {
	switch scene {
	case "chat":
		return "chat/"
	case "avatar":
		return "avatar/"
	case "album":
		return "album/"
	default:
		return "uploads/"
	}
}
