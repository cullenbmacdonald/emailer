-- 001_initial.sql
-- Core database tables for the emailer server.
-- All tables use UUID primary keys, TIMESTAMPTZ for timestamps, and
-- enforce referential integrity via foreign keys.

-- ============================================================================
-- 1. accounts — email account configuration
-- ============================================================================
CREATE TABLE IF NOT EXISTS accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    email           TEXT NOT NULL UNIQUE,
    provider        TEXT NOT NULL,
    account_type    TEXT NOT NULL CHECK (account_type IN ('work', 'personal')),
    color           TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('online', 'offline', 'error', 'syncing')),
    status_message  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 2. emails — email metadata and cached bodies
-- ============================================================================
CREATE TABLE IF NOT EXISTS emails (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id      UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    message_id      TEXT,
    thread_id       TEXT,
    uid             INTEGER,
    folder          TEXT NOT NULL,
    from_address    TEXT NOT NULL,
    from_name       TEXT,
    to_addresses    JSONB,
    cc_addresses    JSONB,
    subject         TEXT NOT NULL DEFAULT '',
    snippet         TEXT,
    text_body       TEXT,
    html_body       TEXT,
    received_at     TIMESTAMPTZ NOT NULL,
    processed_at    TIMESTAMPTZ,
    has_attachments BOOLEAN NOT NULL DEFAULT FALSE,
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
    labels          JSONB,
    last_read_at    TIMESTAMPTZ,
    read_progress   REAL,
    raw_headers     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_emails_account_id ON emails(account_id);
CREATE INDEX IF NOT EXISTS idx_emails_received_at ON emails(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_emails_message_id ON emails(message_id);
CREATE INDEX IF NOT EXISTS idx_emails_from_address ON emails(from_address);
CREATE UNIQUE INDEX IF NOT EXISTS idx_emails_account_folder_uid ON emails(account_id, folder, uid);

-- ============================================================================
-- 3. classifications — classification results per email (1:1)
-- ============================================================================
CREATE TABLE IF NOT EXISTS classifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_id        UUID NOT NULL UNIQUE REFERENCES emails(id) ON DELETE CASCADE,
    classification  TEXT NOT NULL CHECK (classification IN ('action_required', 'newsletter', 'filtered', 'transactional')),
    confidence      REAL NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    classified_by   TEXT NOT NULL CHECK (classified_by IN ('rules', 'features', 'llm', 'user')),
    reason          TEXT,
    is_overridden   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_classifications_classification ON classifications(classification);

-- ============================================================================
-- 4. classification_training — user override training signals
-- ============================================================================
CREATE TABLE IF NOT EXISTS classification_training (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_id                UUID NOT NULL REFERENCES emails(id) ON DELETE CASCADE,
    previous_classification TEXT NOT NULL,
    new_classification      TEXT NOT NULL,
    is_confirm              BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_classification_training_email_id ON classification_training(email_id);

-- ============================================================================
-- 5. snooze_states — snooze records per email
-- ============================================================================
CREATE TABLE IF NOT EXISTS snooze_states (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_id        UUID NOT NULL REFERENCES emails(id) ON DELETE CASCADE,
    snoozed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    return_at       TIMESTAMPTZ NOT NULL,
    snooze_count    INTEGER NOT NULL DEFAULT 1 CHECK (snooze_count >= 1),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_snooze_states_return_at_active ON snooze_states(return_at) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_snooze_states_email_id ON snooze_states(email_id);

-- ============================================================================
-- 6. recommendations — extracted recommendations from newsletters
-- ============================================================================
CREATE TABLE IF NOT EXISTS recommendations (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_id                UUID REFERENCES emails(id) ON DELETE SET NULL,
    type                    TEXT NOT NULL CHECK (type IN ('book', 'movie', 'tv', 'music', 'article', 'podcast', 'other')),
    title                   TEXT NOT NULL,
    creator                 TEXT,
    source_newsletter_name  TEXT NOT NULL DEFAULT '',
    source_date             TIMESTAMPTZ,
    context_snippet         TEXT NOT NULL DEFAULT '',
    full_context            TEXT,
    status                  TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'saved', 'done', 'dismissed')),
    duplicate_count         INTEGER NOT NULL DEFAULT 1 CHECK (duplicate_count >= 1),
    is_user_added           BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recommendations_status ON recommendations(status);
CREATE INDEX IF NOT EXISTS idx_recommendations_type ON recommendations(type);

-- ============================================================================
-- 7. recommendation_sources — duplicate source tracking (M:N)
-- ============================================================================
CREATE TABLE IF NOT EXISTS recommendation_sources (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recommendation_id   UUID NOT NULL REFERENCES recommendations(id) ON DELETE CASCADE,
    email_id            UUID REFERENCES emails(id) ON DELETE SET NULL,
    newsletter_name     TEXT NOT NULL,
    date                TIMESTAMPTZ,
    context_snippet     TEXT NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recommendation_sources_recommendation_id ON recommendation_sources(recommendation_id);

-- ============================================================================
-- 8. digests — generated daily digests (payload as JSONB)
-- ============================================================================
CREATE TABLE IF NOT EXISTS digests (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    digest_type     TEXT NOT NULL CHECK (digest_type IN ('morning', 'evening')),
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    payload         JSONB NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_digests_generated_at ON digests(generated_at DESC);

-- ============================================================================
-- 9. vip_senders — VIP sender list
-- ============================================================================
CREATE TABLE IF NOT EXISTS vip_senders (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT NOT NULL,
    name        TEXT,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_vip_senders_email ON vip_senders(email);

-- ============================================================================
-- 10. sender_stats — sender behavior statistics for feature classification
-- ============================================================================
CREATE TABLE IF NOT EXISTS sender_stats (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_email     TEXT NOT NULL UNIQUE,
    total_received   INTEGER NOT NULL DEFAULT 0,
    total_replied    INTEGER NOT NULL DEFAULT 0,
    last_received_at TIMESTAMPTZ,
    last_replied_at  TIMESTAMPTZ,
    avg_reply_time   REAL,
    most_common_class TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
