-- 004_drafts.sql
-- Drafts table for saved email compositions.

CREATE TABLE IF NOT EXISTS drafts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id      UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    to_addresses    JSONB NOT NULL DEFAULT '[]'::jsonb,
    cc_addresses    JSONB NOT NULL DEFAULT '[]'::jsonb,
    bcc_addresses   JSONB NOT NULL DEFAULT '[]'::jsonb,
    subject         TEXT NOT NULL DEFAULT '',
    body            TEXT NOT NULL DEFAULT '',
    html_body       TEXT NOT NULL DEFAULT '',
    in_reply_to     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_drafts_account_id ON drafts(account_id);
CREATE INDEX IF NOT EXISTS idx_drafts_updated_at ON drafts(updated_at DESC);
