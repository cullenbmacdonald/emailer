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

// OllamaProvider implements the Provider interface using a local Ollama instance.
type OllamaProvider struct {
	baseURL string
	model   string
	client  *http.Client
}

// NewOllamaProvider creates a new Ollama LLM provider.
func NewOllamaProvider(baseURL, model string) *OllamaProvider {
	return &OllamaProvider{
		baseURL: baseURL,
		model:   model,
		client:  &http.Client{Timeout: 120 * time.Second},
	}
}

// ollamaChatRequest is the request body for Ollama's /api/chat endpoint.
type ollamaChatRequest struct {
	Model    string          `json:"model"`
	Messages []ollamaMessage `json:"messages"`
	Format   string          `json:"format,omitempty"`
	Options  ollamaOptions   `json:"options,omitempty"`
	Stream   bool            `json:"stream"`
}

type ollamaMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ollamaOptions struct {
	Temperature float64 `json:"temperature"`
}

// ollamaChatResponse is the response from Ollama's /api/chat endpoint.
type ollamaChatResponse struct {
	Message ollamaMessage `json:"message"`
}

func (o *OllamaProvider) Name() string { return "ollama" }

func (o *OllamaProvider) Classify(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error) {
	prompt := BuildClassificationPrompt(req)

	ollamaReq := ollamaChatRequest{
		Model: o.model,
		Messages: []ollamaMessage{
			{Role: "system", Content: classificationSystemPrompt},
			{Role: "user", Content: prompt},
		},
		Format:  "json",
		Options: ollamaOptions{Temperature: 0.1},
		Stream:  false,
	}

	content, err := o.doChat(ctx, ollamaReq)
	if err != nil {
		return nil, err
	}

	return ParseClassifyResponse(content)
}

func (o *OllamaProvider) ExtractRecommendations(ctx context.Context, req ExtractRequest) (*ExtractResponse, error) {
	prompt := BuildExtractionPrompt(req)

	ollamaReq := ollamaChatRequest{
		Model: o.model,
		Messages: []ollamaMessage{
			{Role: "system", Content: extractionSystemPrompt},
			{Role: "user", Content: prompt},
		},
		Format:  "json",
		Options: ollamaOptions{Temperature: 0.2},
		Stream:  false,
	}

	content, err := o.doChat(ctx, ollamaReq)
	if err != nil {
		return nil, err
	}

	return ParseExtractResponse(content)
}

// doChat sends a chat request to Ollama and returns the response content.
func (o *OllamaProvider) doChat(ctx context.Context, req ollamaChatRequest) (string, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return "", fmt.Errorf("marshal ollama request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, o.baseURL+"/api/chat", bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("create ollama request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := o.client.Do(httpReq)
	if err != nil {
		return "", &ConnectionError{Err: err}
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("ollama returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var ollamaResp ollamaChatResponse
	if err := json.NewDecoder(resp.Body).Decode(&ollamaResp); err != nil {
		return "", fmt.Errorf("decode ollama response: %w", err)
	}

	return ollamaResp.Message.Content, nil
}
