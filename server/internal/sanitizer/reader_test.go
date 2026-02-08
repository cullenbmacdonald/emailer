package sanitizer

import (
	"strings"
	"testing"
)

func TestReaderMode_RemovesUnsubscribeFooter(t *testing.T) {
	input := `<div>Article content here</div>
<div>You received this email because you signed up. <a href="#">Unsubscribe</a> from this list.</div>`
	got := ReaderMode(input)
	if strings.Contains(strings.ToLower(got), "unsubscribe") {
		t.Errorf("unsubscribe footer not removed: %s", got)
	}
	if !strings.Contains(got, "Article content here") {
		t.Errorf("article content was removed: %s", got)
	}
}

func TestReaderMode_RemovesViewInBrowser(t *testing.T) {
	input := `<p>Can't see this email? <a href="https://example.com/view">View in your browser</a></p>
<div>Real content</div>`
	got := ReaderMode(input)
	if strings.Contains(strings.ToLower(got), "view in your browser") {
		t.Errorf("view in browser not removed: %s", got)
	}
	if !strings.Contains(got, "Real content") {
		t.Errorf("content was removed: %s", got)
	}
}

func TestReaderMode_RemovesTroubleViewing(t *testing.T) {
	input := `<p>Trouble viewing this email? <a href="#">Click here</a></p><div>Content</div>`
	got := ReaderMode(input)
	if strings.Contains(strings.ToLower(got), "trouble viewing") {
		t.Errorf("trouble viewing not removed: %s", got)
	}
}

func TestReaderMode_RemovesSocialShareButtons(t *testing.T) {
	input := `<div>Article here</div>
<td><a href="https://facebook.com/share"><img src="fb.png"/></a> <a href="https://twitter.com/intent/tweet"><img src="tw.png"/></a></td>
<div>More content</div>`
	got := ReaderMode(input)
	if strings.Contains(got, "facebook.com/share") {
		t.Errorf("social share buttons not removed: %s", got)
	}
}

func TestReaderMode_PreservesArticleContent(t *testing.T) {
	input := `<h1>Newsletter Title</h1>
<p>This is the main article content with <a href="https://example.com">a link</a>.</p>
<blockquote>A great quote from someone</blockquote>
<img src="https://example.com/article-image.jpg" alt="Article image" />
<h2>Section Two</h2>
<p>More content here.</p>`
	got := ReaderMode(input)
	if !strings.Contains(got, "<h1>Newsletter Title</h1>") {
		t.Error("heading was removed")
	}
	if !strings.Contains(got, "<blockquote>") {
		t.Error("blockquote was removed")
	}
	if !strings.Contains(got, "article-image.jpg") {
		t.Error("content image was removed")
	}
	if !strings.Contains(got, "<h2>Section Two</h2>") {
		t.Error("subheading was removed")
	}
}

func TestReaderMode_RemovesRedundantLogos(t *testing.T) {
	input := `<img src="https://example.com/logo.png" />
<p>Content</p>
<img src="https://example.com/footer-logo.png" />
<p>More</p>`
	got := ReaderMode(input)
	// First logo should be kept
	if !strings.Contains(got, "logo.png") {
		t.Error("first logo was removed")
	}
	// Second logo should be removed (redundant)
	if strings.Contains(got, "footer-logo.png") {
		t.Error("redundant footer logo was not removed")
	}
}

func TestReaderMode_KeepsSingleLogo(t *testing.T) {
	input := `<img src="https://example.com/logo.png" /><p>Content</p>`
	got := ReaderMode(input)
	if !strings.Contains(got, "logo.png") {
		t.Error("single logo should be kept")
	}
}

func TestReaderMode_AlsoSanitizes(t *testing.T) {
	input := `<script>evil()</script><p>Content</p>`
	got := ReaderMode(input)
	if strings.Contains(got, "script") {
		t.Error("reader mode should also sanitize")
	}
}

func TestReaderMode_EmptyInput(t *testing.T) {
	got := ReaderMode("")
	if got != "" {
		t.Errorf("expected empty string, got %q", got)
	}
}

func TestReaderMode_PreservesManagePreferencesInContent(t *testing.T) {
	// "manage preferences" inside a larger content block that also has article text
	// should only remove the specific footer block, not the whole page
	input := `<div><h1>Great Article</h1><p>Read about managing preferences in software design.</p></div>`
	got := ReaderMode(input)
	if !strings.Contains(got, "Great Article") {
		t.Error("article content incorrectly removed")
	}
}
