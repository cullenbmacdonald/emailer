package sanitizer

import (
	"strings"
	"testing"
)

func TestSanitize_RemovesScriptTags(t *testing.T) {
	input := `<p>Hello</p><script>alert('xss')</script><p>World</p>`
	got := Sanitize(input)
	if strings.Contains(got, "<script") || strings.Contains(got, "alert") {
		t.Errorf("script tag not removed: %s", got)
	}
	if !strings.Contains(got, "<p>Hello</p>") || !strings.Contains(got, "<p>World</p>") {
		t.Errorf("content was incorrectly removed: %s", got)
	}
}

func TestSanitize_RemovesMultilineScript(t *testing.T) {
	input := `<p>Before</p><script type="text/javascript">
		var x = 1;
		console.log(x);
	</script><p>After</p>`
	got := Sanitize(input)
	if strings.Contains(got, "script") {
		t.Errorf("multiline script not removed: %s", got)
	}
}

func TestSanitize_RemovesEventHandlers(t *testing.T) {
	input := `<div onclick="alert('xss')" onload="hack()">Content</div>`
	got := Sanitize(input)
	if strings.Contains(got, "onclick") || strings.Contains(got, "onload") {
		t.Errorf("event handlers not removed: %s", got)
	}
	if !strings.Contains(got, "Content") {
		t.Errorf("content removed with event handlers: %s", got)
	}
}

func TestSanitize_RemovesTrackingPixels(t *testing.T) {
	tests := []struct {
		name  string
		input string
	}{
		{
			"1x1 pixel",
			`<p>Text</p><img src="https://tracker.com/open.gif" width="1" height="1" /><p>More</p>`,
		},
		{
			"hidden pixel",
			`<p>Text</p><img src="https://tracker.com/open.gif" style="display:none" /><p>More</p>`,
		},
		{
			"zero-size pixel",
			`<p>Text</p><img src="https://tracker.com/open.gif" style="width:0;height:0" /><p>More</p>`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Sanitize(tt.input)
			if strings.Contains(got, "tracker.com") {
				t.Errorf("tracking pixel not removed: %s", got)
			}
			if !strings.Contains(got, "<p>Text</p>") || !strings.Contains(got, "<p>More</p>") {
				t.Errorf("content incorrectly removed: %s", got)
			}
		})
	}
}

func TestSanitize_RemovesKnownTrackingDomainImages(t *testing.T) {
	input := `<p>Text</p><img src="https://track.mailchimp.com/open/12345.gif" /><p>More</p>`
	got := Sanitize(input)
	if strings.Contains(got, "mailchimp.com") {
		t.Errorf("known tracking domain image not removed: %s", got)
	}
}

func TestSanitize_PreservesNormalImages(t *testing.T) {
	input := `<img src="https://example.com/photo.jpg" width="600" height="400" alt="Photo" />`
	got := Sanitize(input)
	if !strings.Contains(got, "photo.jpg") {
		t.Errorf("normal image was incorrectly removed: %s", got)
	}
}

func TestSanitize_PreservesInlineImages(t *testing.T) {
	input := `<img src="cid:image001.png" width="200" height="100" />`
	got := Sanitize(input)
	if !strings.Contains(got, "cid:image001.png") {
		t.Errorf("inline image was incorrectly removed: %s", got)
	}
}

func TestSanitize_RemovesStyleImports(t *testing.T) {
	input := `<style>@import url('https://evil.com/style.css'); body { color: red; }</style><p>Content</p>`
	got := Sanitize(input)
	if strings.Contains(got, "@import") {
		t.Errorf("style import not removed: %s", got)
	}
	if !strings.Contains(got, "Content") {
		t.Errorf("content removed: %s", got)
	}
}

func TestSanitize_PreservesNormalStyles(t *testing.T) {
	input := `<style>body { font-family: Arial; }</style><p>Content</p>`
	got := Sanitize(input)
	if !strings.Contains(got, "<style>") {
		t.Errorf("normal style tag was removed: %s", got)
	}
}

func TestSanitize_EmptyInput(t *testing.T) {
	got := Sanitize("")
	if got != "" {
		t.Errorf("expected empty string, got %q", got)
	}
}

func TestSanitize_RemovesNoscript(t *testing.T) {
	input := `<p>Text</p><noscript><img src="tracker.gif" /></noscript><p>More</p>`
	got := Sanitize(input)
	if strings.Contains(got, "noscript") {
		t.Errorf("noscript not removed: %s", got)
	}
}
