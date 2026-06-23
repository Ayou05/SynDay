package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

var ErrUnavailable = errors.New("ai unavailable")

type Client struct {
	apiKey  string
	baseURL string
	model   string
	http    *http.Client
}

func NewClient(apiKey, baseURL, model string) *Client {
	return &Client{
		apiKey:  strings.TrimSpace(apiKey),
		baseURL: strings.TrimRight(baseURL, "/"),
		model:   model,
		http: &http.Client{
			Timeout: 4 * time.Second,
		},
	}
}

func (c *Client) Available() bool {
	return c.apiKey != ""
}

type chatRequest struct {
	Model          string          `json:"model"`
	Messages       []chatMessage   `json:"messages"`
	MaxTokens      int             `json:"max_tokens"`
	Temperature    float64         `json:"temperature"`
	Stream         bool            `json:"stream"`
	Thinking       thinkingMode    `json:"thinking"`
	ResponseFormat *responseFormat `json:"response_format,omitempty"`
}

type thinkingMode struct {
	Type string `json:"type"`
}

type responseFormat struct {
	Type string `json:"type"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
}

func (c *Client) Complete(ctx context.Context, system, prompt string, maxTokens int) (string, error) {
	return c.complete(ctx, system, prompt, maxTokens, false)
}

func (c *Client) complete(
	ctx context.Context,
	system string,
	prompt string,
	maxTokens int,
	jsonOutput bool,
) (string, error) {
	if !c.Available() {
		return "", ErrUnavailable
	}
	var format *responseFormat
	if jsonOutput {
		format = &responseFormat{Type: "json_object"}
	}
	body, err := json.Marshal(chatRequest{
		Model: c.model,
		Messages: []chatMessage{
			{Role: "system", Content: system},
			{Role: "user", Content: prompt},
		},
		MaxTokens:      maxTokens,
		Temperature:    0.5,
		Stream:         false,
		Thinking:       thinkingMode{Type: "disabled"},
		ResponseFormat: format,
	})
	if err != nil {
		return "", err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	request.Header.Set("Authorization", "Bearer "+c.apiKey)
	request.Header.Set("Content-Type", "application/json")
	response, err := c.http.Do(request)
	if err != nil {
		return "", fmt.Errorf("deepseek request: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		message, _ := io.ReadAll(io.LimitReader(response.Body, 1024))
		return "", fmt.Errorf("deepseek status %d: %s", response.StatusCode, strings.TrimSpace(string(message)))
	}
	var payload chatResponse
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		return "", fmt.Errorf("decode deepseek response: %w", err)
	}
	if len(payload.Choices) == 0 {
		return "", ErrUnavailable
	}
	content := strings.TrimSpace(payload.Choices[0].Message.Content)
	if content == "" {
		return "", ErrUnavailable
	}
	return content, nil
}

func (c *Client) Encouragement(ctx context.Context, title, tone string) (string, error) {
	toneInstruction := map[string]string{
		"restrained": "克制温和，不夸张",
		"companion":  "像熟悉的朋友陪伴，但不撒娇",
		"concise":    "简短有力",
	}[tone]
	if toneInstruction == "" {
		toneInstruction = "克制温和，不夸张"
	}
	content, err := c.Complete(
		ctx,
		"你为学习自律应用生成任务完成后的即时短句。禁止感叹号堆叠、说教、空泛鸡汤和重复任务标题。",
		fmt.Sprintf("任务：%s\n语气：%s\n只输出一句不超过24个汉字的中文短句。", title, toneInstruction),
		64,
	)
	if err != nil {
		return "", err
	}
	return strings.Trim(content, "\"“”\n "), nil
}

type ReviewResult struct {
	Full    string
	Compact string
}

func (c *Client) Review(ctx context.Context, structuredJSON []byte) (ReviewResult, error) {
	content, err := c.complete(
		ctx,
		`你负责生成每日学习复盘。输入数字绝不能改写或臆造。语气中立、不指责、不写长文。
严格输出 JSON：{"full":"四段式完整复盘","compact":"适合微信打卡的一段精简摘要"}。full 必须依次包含当日总览、分类明细、未完成客观分析、次日优化建议；次日建议只给一条。`,
		string(structuredJSON),
		700,
		true,
	)
	if err != nil {
		return ReviewResult{}, err
	}
	content = strings.TrimSpace(content)
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimPrefix(content, "```")
	content = strings.TrimSuffix(content, "```")
	var result ReviewResult
	var payload struct {
		Full    string `json:"full"`
		Compact string `json:"compact"`
	}
	if err := json.Unmarshal([]byte(strings.TrimSpace(content)), &payload); err != nil {
		return ReviewResult{}, fmt.Errorf("decode review JSON: %w", err)
	}
	result.Full = strings.TrimSpace(payload.Full)
	result.Compact = strings.TrimSpace(payload.Compact)
	if result.Full == "" || result.Compact == "" {
		return ReviewResult{}, ErrUnavailable
	}
	return result, nil
}
