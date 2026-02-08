package digest

import (
	"context"
	"fmt"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/rs/zerolog/log"
)

// SchedulerConfig holds the digest scheduling configuration.
type SchedulerConfig struct {
	MorningTime string // "HH:MM" format, e.g. "06:00"
	EveningTime string // "HH:MM" format, e.g. "19:00"
	Timezone    string // IANA timezone, e.g. "America/Los_Angeles"
}

// Scheduler manages the timing of digest generation.
type Scheduler struct {
	cfg       SchedulerConfig
	generator *Generator
	loc       *time.Location
}

// NewScheduler creates a new digest scheduler.
func NewScheduler(cfg SchedulerConfig, generator *Generator) (*Scheduler, error) {
	loc, err := time.LoadLocation(cfg.Timezone)
	if err != nil {
		return nil, fmt.Errorf("load timezone %s: %w", cfg.Timezone, err)
	}

	return &Scheduler{
		cfg:       cfg,
		generator: generator,
		loc:       loc,
	}, nil
}

// Run starts the scheduler loop. It blocks until ctx is cancelled.
// On startup, it checks for any missed digests for today.
func (s *Scheduler) Run(ctx context.Context) {
	// Check for missed digests on startup.
	s.generateMissedDigests(ctx)

	for {
		nextTime, nextType := s.nextDigestTime(time.Now().In(s.loc))
		waitDuration := time.Until(nextTime)

		log.Info().
			Str("next_type", nextType).
			Time("next_at", nextTime).
			Dur("wait", waitDuration).
			Msg("digest scheduler: waiting for next digest")

		timer := time.NewTimer(waitDuration)
		select {
		case <-ctx.Done():
			timer.Stop()
			log.Info().Msg("digest scheduler: shutting down")
			return
		case <-timer.C:
			s.generate(ctx, nextType)
		}
	}
}

func (s *Scheduler) generate(ctx context.Context, digestType string) {
	now := time.Now().In(s.loc)
	log.Info().Str("type", digestType).Msg("digest scheduler: generating digest")

	_, err := s.generator.Generate(ctx, digestType, now)
	if err != nil {
		log.Error().Err(err).Str("type", digestType).Msg("digest scheduler: generation failed")
	}
}

func (s *Scheduler) generateMissedDigests(ctx context.Context) {
	now := time.Now().In(s.loc)

	morningHour, morningMin := parseTimeHHMM(s.cfg.MorningTime)
	eveningHour, eveningMin := parseTimeHHMM(s.cfg.EveningTime)

	morningTime := time.Date(now.Year(), now.Month(), now.Day(), morningHour, morningMin, 0, 0, s.loc)
	eveningTime := time.Date(now.Year(), now.Month(), now.Day(), eveningHour, eveningMin, 0, 0, s.loc)

	// Check if morning digest was missed (it's past morning time but no digest exists for today).
	if now.After(morningTime) {
		s.generateIfMissing(ctx, models.DigestTypeMorning, morningTime)
	}

	// Check if evening digest was missed.
	if now.After(eveningTime) {
		s.generateIfMissing(ctx, models.DigestTypeEvening, eveningTime)
	}
}

func (s *Scheduler) generateIfMissing(ctx context.Context, digestType string, scheduledTime time.Time) {
	latest, err := s.generator.saver.GetLatestDigest(ctx, digestType)
	if err != nil {
		// No existing digest found -- generate one.
		log.Info().Str("type", digestType).Msg("digest scheduler: generating missed digest")
		s.generate(ctx, digestType)
		return
	}

	// If the latest digest was generated before today's scheduled time, we missed it.
	if latest.GeneratedAt.In(s.loc).Before(scheduledTime) {
		log.Info().Str("type", digestType).Msg("digest scheduler: generating missed digest")
		s.generate(ctx, digestType)
	}
}

// nextDigestTime returns the next scheduled digest time and type.
func (s *Scheduler) nextDigestTime(now time.Time) (time.Time, string) {
	morningHour, morningMin := parseTimeHHMM(s.cfg.MorningTime)
	eveningHour, eveningMin := parseTimeHHMM(s.cfg.EveningTime)

	todayMorning := time.Date(now.Year(), now.Month(), now.Day(), morningHour, morningMin, 0, 0, s.loc)
	todayEvening := time.Date(now.Year(), now.Month(), now.Day(), eveningHour, eveningMin, 0, 0, s.loc)
	tomorrowMorning := todayMorning.AddDate(0, 0, 1)

	if now.Before(todayMorning) {
		return todayMorning, models.DigestTypeMorning
	}
	if now.Before(todayEvening) {
		return todayEvening, models.DigestTypeEvening
	}
	return tomorrowMorning, models.DigestTypeMorning
}

// parseTimeHHMM parses "HH:MM" into hour and minute. Defaults to 0:0 on error.
func parseTimeHHMM(s string) (int, int) {
	var hour, min int
	_, _ = fmt.Sscanf(s, "%d:%d", &hour, &min)
	return hour, min
}
