package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// LMStudioProvider implements the Provider interface using a local LM Studio instance.
// LM Studio exposes an OpenAI-compatible API.
type LMStudioProvider struct {
	baseURL string
	model   string
	client  *http.Client
}

// NewLMStudioProvider creates a new LM Studio LLM provider.
// If baseURL is empty, it defaults to "http://localhost:1234".
func NewLMStudioProvider(baseURL, model string) *LMStudioProvider {
	if baseURL == "" {
		baseURL = "http://localhost:1234"
	}
	return &LMStudioProvider{
		baseURL: baseURL,
		model:   model,
		client:  &http.Client{Timeout: 120 * time.Second},
	}
}

// openAIChatRequest is the request body for the OpenAI-compatible chat completions endpoint.
type openAIChatRequest struct {
	Model          string            `json:"model"`
	Messages       []openAIMessage   `json:"messages"`
	Temperature    float64           `json:"temperature"`
	MaxTokens      int               `json:"max_tokens,omitempty"`
	ResponseFormat *openAIRespFormat `json:"response_format,omitempty"`
}

type openAIMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type openAIRespFormat struct {
	Type       string              `json:"type"`
	JSONSchema *openAIJSONSchema   `json:"json_schema,omitempty"`
}

type openAIJSONSchema struct {
	Name   string         `json:"name"`
	Strict bool           `json:"strict"`
	Schema map[string]any `json:"schema"`
}

var classifyResponseFormat = &openAIRespFormat{
	Type: "json_schema",
	JSONSchema: &openAIJSONSchema{
		Name:   "classification",
		Strict: true,
		Schema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"classification": map[string]any{"type": "string"},
				"confidence":     map[string]any{"type": "number"},
				"reasoning":      map[string]any{"type": "string"},
			},
			"required":             []string{"classification", "confidence", "reasoning"},
			"additionalProperties": false,
		},
	},
}

var extractResponseFormat = &openAIRespFormat{
	Type: "json_schema",
	JSONSchema: &openAIJSONSchema{
		Name:   "recommendations",
		Strict: true,
		Schema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"recommendations": map[string]any{
					"type": "array",
					"items": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"type":       map[string]any{"type": "string"},
							"title":      map[string]any{"type": "string"},
							"creator":    map[string]any{"type": "string"},
							"context":    map[string]any{"type": "string"},
							"confidence": map[string]any{"type": "string"},
						},
						"required":             []string{"type", "title", "creator", "context", "confidence"},
						"additionalProperties": false,
					},
				},
			},
			"required":             []string{"recommendations"},
			"additionalProperties": false,
		},
	},
}

// openAIChatResponse is the response from the OpenAI-compatible chat completions endpoint.
type openAIChatResponse struct {
	Choices []openAIChoice `json:"choices"`
}

type openAIChoice struct {
	Message openAIMessage `json:"message"`
}

func (l *LMStudioProvider) Name() string { return "lmstudio" }

func (l *LMStudioProvider) Classify(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error) {
	prompt := BuildClassificationPrompt(req)

	chatReq := openAIChatRequest{
		Model: l.model,
		Messages: []openAIMessage{
			{Role: "system", Content: classificationSystemPrompt},
			{Role: "user", Content: prompt},
		},
		Temperature:    0.1,
		ResponseFormat: classifyResponseFormat,
	}

	content, err := l.doChat(ctx, chatReq)
	if err != nil {
		return nil, err
	}

	return ParseClassifyResponse(content)
}

func (l *LMStudioProvider) ExtractRecommendations(ctx context.Context, req ExtractRequest) (*ExtractResponse, error) {
	prompt := BuildExtractionPrompt(req)

	chatReq := openAIChatRequest{
		Model: l.model,
		Messages: []openAIMessage{
			{Role: "system", Content: extractionSystemPrompt},
			{Role: "user", Content: prompt},
		},
		Temperature:    0.2,
		MaxTokens:      4096,
		ResponseFormat: extractResponseFormat,
	}

	content, err := l.doChat(ctx, chatReq)
	if err != nil {
		return nil, err
	}

	return ParseExtractResponse(content)
}

// doChat sends a chat completion request to LM Studio and returns the response content.
func (l *LMStudioProvider) doChat(ctx context.Context, req openAIChatRequest) (string, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return "", fmt.Errorf("marshal lmstudio request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, l.baseURL+"/v1/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("create lmstudio request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := l.client.Do(httpReq)
	if err != nil {
		return "", &ConnectionError{Err: err}
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("lmstudio returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var chatResp openAIChatResponse
	if err := json.NewDecoder(resp.Body).Decode(&chatResp); err != nil {
		return "", fmt.Errorf("decode lmstudio response: %w", err)
	}

	if len(chatResp.Choices) == 0 {
		return "", fmt.Errorf("lmstudio returned no choices")
	}

	return chatResp.Choices[0].Message.Content, nil
}
