package llm

import "fmt"

const classificationSystemPrompt = `You are an email classifier. Classify each email into exactly one category.

Categories:
- ACTION: The sender expects a response from the recipient. Contains questions, requests, deadlines, or calls to action directed at the reader. When in doubt, choose ACTION.
- NEWSLETTER: Informational content sent to a list. Contains recommendations, news, analysis, or curated links. Not expecting a reply. Has unsubscribe link.
- FILTERED: Unsolicited marketing, promotions, spam, or junk. Promotional language without substantive content.
- TRANSACTIONAL: Automated messages: receipts, shipping notifications, password resets, calendar invites, two-factor codes, order confirmations.

CRITICAL: When uncertain between ACTION and any other category, always choose ACTION. Missing an email that needs a response is far worse than a false positive.

Respond in JSON format:
{
    "classification": "ACTION|NEWSLETTER|FILTERED|TRANSACTIONAL",
    "confidence": 0.0-1.0,
    "reasoning": "brief explanation"
}`

const extractionSystemPrompt = `Extract all recommendations from this newsletter. A recommendation is when the author suggests, endorses, praises, or highlights a specific item.

For each recommendation found, extract:
- type: one of "book", "movie_tv", "music", "article", "podcast", "other"
- title: the name of the recommended item
- creator: author, director, artist, etc. (if mentioned)
- context: the sentence or phrase where the recommendation appears (quote directly from the text)
- confidence: "high" (explicit endorsement), "medium" (positive mention), or "low" (passing reference)

Only include items the author is clearly recommending or endorsing. Do not include items merely mentioned in passing without positive sentiment. Do not include self-promotions or advertisements.

Respond in JSON format:
{
    "recommendations": [
        {
            "type": "book",
            "title": "Example Title",
            "creator": "Author Name",
            "context": "quoted text from newsletter",
            "confidence": "high"
        }
    ]
}`

// maxBodyLength is the maximum body length sent to the LLM.
const maxBodyLength = 6000

// BuildClassificationPrompt builds the user prompt for email classification.
func BuildClassificationPrompt(req ClassifyRequest) string {
	body := req.Body
	if len(body) > maxBodyLength {
		body = body[:maxBodyLength]
	}

	return fmt.Sprintf(`Subject: %s
From: %s <%s>
To/CC position: %s
Body (truncated):
%s`,
		req.Subject,
		req.FromName,
		req.From,
		req.ToPosition,
		body,
	)
}

// BuildExtractionPrompt builds the user prompt for recommendation extraction.
func BuildExtractionPrompt(req ExtractRequest) string {
	body := req.Body
	if len(body) > maxBodyLength {
		body = body[:maxBodyLength]
	}

	return fmt.Sprintf(`Newsletter: %s
From: %s

%s`,
		req.Subject,
		req.From,
		body,
	)
}
