package storage

import (
	"context"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestIntegrationCreateAndGetRecommendation(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	recStore := NewRecommendationStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM recommendation_sources")
		_, _ = pool.Exec(ctx, "DELETE FROM recommendations")
	})

	rec := &models.Recommendation{
		Type:                 models.RecTypeBook,
		Title:                "Test Book",
		Creator:              "Author Name",
		SourceNewsletterName: "Weekly Newsletter",
		SourceDate:           time.Now().UTC().Truncate(time.Microsecond),
		ContextSnippet:       "Mentioned in the latest edition",
		Status:               models.RecStatusNew,
		DuplicateCount:       1,
	}

	created, err := recStore.CreateRecommendation(ctx, rec)
	if err != nil {
		t.Fatalf("CreateRecommendation() error: %v", err)
	}
	if created.ID == "" {
		t.Error("expected generated ID")
	}

	detail, err := recStore.GetRecommendation(ctx, created.ID)
	if err != nil {
		t.Fatalf("GetRecommendation() error: %v", err)
	}
	if detail.Recommendation.Title != "Test Book" {
		t.Errorf("expected title 'Test Book', got %q", detail.Recommendation.Title)
	}
	if detail.Recommendation.Creator != "Author Name" {
		t.Errorf("expected creator 'Author Name', got %q", detail.Recommendation.Creator)
	}
	if len(detail.DuplicateSources) != 0 {
		t.Errorf("expected 0 duplicate sources, got %d", len(detail.DuplicateSources))
	}
}

func TestIntegrationListRecommendations(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	recStore := NewRecommendationStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM recommendation_sources")
		_, _ = pool.Exec(ctx, "DELETE FROM recommendations")
	})

	// Create recommendations of different types
	for _, recType := range []string{models.RecTypeBook, models.RecTypeMovie, models.RecTypeBook} {
		rec := &models.Recommendation{
			Type:                 recType,
			Title:                "Rec " + recType,
			SourceNewsletterName: "Newsletter",
			SourceDate:           time.Now().UTC().Truncate(time.Microsecond),
			Status:               models.RecStatusNew,
			DuplicateCount:       1,
		}
		if _, err := recStore.CreateRecommendation(ctx, rec); err != nil {
			t.Fatalf("CreateRecommendation: %v", err)
		}
	}

	// List all
	resp, err := recStore.ListRecommendations(ctx, RecommendationListOptions{Limit: 10})
	if err != nil {
		t.Fatalf("ListRecommendations() error: %v", err)
	}
	if len(resp.Data) != 3 {
		t.Errorf("expected 3 recommendations, got %d", len(resp.Data))
	}

	// Filter by type
	resp, err = recStore.ListRecommendations(ctx, RecommendationListOptions{
		Type:  models.RecTypeBook,
		Limit: 10,
	})
	if err != nil {
		t.Fatalf("ListRecommendations(type=book) error: %v", err)
	}
	if len(resp.Data) != 2 {
		t.Errorf("expected 2 book recommendations, got %d", len(resp.Data))
	}
}

func TestIntegrationListRecommendationsPagination(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	recStore := NewRecommendationStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM recommendation_sources")
		_, _ = pool.Exec(ctx, "DELETE FROM recommendations")
	})

	for i := 0; i < 5; i++ {
		rec := &models.Recommendation{
			Type:                 models.RecTypeBook,
			Title:                "Book " + string(rune('A'+i)),
			SourceNewsletterName: "Newsletter",
			SourceDate:           time.Now().UTC().Truncate(time.Microsecond),
			Status:               models.RecStatusNew,
			DuplicateCount:       1,
		}
		if _, err := recStore.CreateRecommendation(ctx, rec); err != nil {
			t.Fatalf("CreateRecommendation: %v", err)
		}
	}

	page1, err := recStore.ListRecommendations(ctx, RecommendationListOptions{Limit: 2})
	if err != nil {
		t.Fatalf("page 1 error: %v", err)
	}
	if len(page1.Data) != 2 {
		t.Fatalf("expected 2 on page 1, got %d", len(page1.Data))
	}
	if !page1.HasMore {
		t.Error("expected HasMore=true")
	}

	page2, err := recStore.ListRecommendations(ctx, RecommendationListOptions{
		Limit:  2,
		Cursor: page1.NextCursor,
	})
	if err != nil {
		t.Fatalf("page 2 error: %v", err)
	}
	if len(page2.Data) != 2 {
		t.Fatalf("expected 2 on page 2, got %d", len(page2.Data))
	}

	// Verify no overlap
	if page1.Data[0].ID == page2.Data[0].ID {
		t.Error("pages overlap")
	}
}

func TestIntegrationUpdateRecommendationStatus(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	recStore := NewRecommendationStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM recommendation_sources")
		_, _ = pool.Exec(ctx, "DELETE FROM recommendations")
	})

	rec := &models.Recommendation{
		Type:                 models.RecTypeMovie,
		Title:                "Great Movie",
		SourceNewsletterName: "Film Newsletter",
		SourceDate:           time.Now().UTC().Truncate(time.Microsecond),
		Status:               models.RecStatusNew,
		DuplicateCount:       1,
	}
	created, err := recStore.CreateRecommendation(ctx, rec)
	if err != nil {
		t.Fatalf("CreateRecommendation: %v", err)
	}

	if err := recStore.UpdateRecommendationStatus(ctx, created.ID, models.RecStatusSaved); err != nil {
		t.Fatalf("UpdateRecommendationStatus() error: %v", err)
	}

	detail, err := recStore.GetRecommendation(ctx, created.ID)
	if err != nil {
		t.Fatalf("GetRecommendation: %v", err)
	}
	if detail.Recommendation.Status != models.RecStatusSaved {
		t.Errorf("expected status saved, got %s", detail.Recommendation.Status)
	}
}

func TestIntegrationFindSimilarRecommendation(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	recStore := NewRecommendationStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM recommendation_sources")
		_, _ = pool.Exec(ctx, "DELETE FROM recommendations")
	})

	rec := &models.Recommendation{
		Type:                 models.RecTypeBook,
		Title:                "The Great Gatsby",
		SourceNewsletterName: "Book Club",
		SourceDate:           time.Now().UTC().Truncate(time.Microsecond),
		Status:               models.RecStatusNew,
		DuplicateCount:       1,
	}
	if _, err := recStore.CreateRecommendation(ctx, rec); err != nil {
		t.Fatalf("CreateRecommendation: %v", err)
	}

	// Should find by case-insensitive match
	found, err := recStore.FindSimilarRecommendation(ctx, "  the great gatsby  ", models.RecTypeBook)
	if err != nil {
		t.Fatalf("FindSimilarRecommendation() error: %v", err)
	}
	if found.Title != "The Great Gatsby" {
		t.Errorf("expected 'The Great Gatsby', got %q", found.Title)
	}

	// Should not find with different type
	_, err = recStore.FindSimilarRecommendation(ctx, "The Great Gatsby", models.RecTypeMovie)
	if err == nil {
		t.Error("expected error for different type")
	}
}

func TestIntegrationDuplicateSources(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	recStore := NewRecommendationStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM recommendation_sources")
		_, _ = pool.Exec(ctx, "DELETE FROM recommendations")
	})

	rec := &models.Recommendation{
		Type:                 models.RecTypeBook,
		Title:                "Dedup Test Book",
		SourceNewsletterName: "Newsletter A",
		SourceDate:           time.Now().UTC().Truncate(time.Microsecond),
		Status:               models.RecStatusNew,
		DuplicateCount:       1,
	}
	created, err := recStore.CreateRecommendation(ctx, rec)
	if err != nil {
		t.Fatalf("CreateRecommendation: %v", err)
	}

	// Add duplicate source
	err = recStore.AddDuplicateSource(ctx, created.ID, "", "Newsletter B",
		"Also recommended here", time.Now().UTC().Truncate(time.Microsecond))
	if err != nil {
		t.Fatalf("AddDuplicateSource() error: %v", err)
	}

	// Increment duplicate count
	if err := recStore.IncrementDuplicateCount(ctx, created.ID); err != nil {
		t.Fatalf("IncrementDuplicateCount() error: %v", err)
	}

	sources, err := recStore.GetDuplicateSources(ctx, created.ID)
	if err != nil {
		t.Fatalf("GetDuplicateSources() error: %v", err)
	}
	if len(sources) != 1 {
		t.Errorf("expected 1 duplicate source, got %d", len(sources))
	}
	if len(sources) > 0 && sources[0].NewsletterName != "Newsletter B" {
		t.Errorf("expected 'Newsletter B', got %q", sources[0].NewsletterName)
	}

	// Verify duplicate count was incremented
	detail, err := recStore.GetRecommendation(ctx, created.ID)
	if err != nil {
		t.Fatalf("GetRecommendation: %v", err)
	}
	if detail.Recommendation.DuplicateCount != 2 {
		t.Errorf("expected duplicate_count=2, got %d", detail.Recommendation.DuplicateCount)
	}
}
