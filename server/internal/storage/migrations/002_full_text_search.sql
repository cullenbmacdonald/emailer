-- 002_full_text_search.sql
-- Add PostgreSQL full-text search to the emails table using tsvector/tsquery.
-- Weights: A = subject, B = from_name + from_address, C = text_body.

-- Add generated tsvector column for full-text search.
-- Using DO block for idempotency (ALTER TABLE ADD COLUMN IF NOT EXISTS
-- does not support GENERATED columns in all PG versions).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'emails' AND column_name = 'search_vector'
    ) THEN
        ALTER TABLE emails ADD COLUMN search_vector TSVECTOR
            GENERATED ALWAYS AS (
                setweight(to_tsvector('english', coalesce(subject, '')), 'A') ||
                setweight(to_tsvector('english', coalesce(from_name, '')), 'B') ||
                setweight(to_tsvector('english', coalesce(from_address, '')), 'B') ||
                setweight(to_tsvector('english', coalesce(text_body, '')), 'C')
            ) STORED;
    END IF;
END
$$;

-- GIN index for fast full-text search queries.
CREATE INDEX IF NOT EXISTS idx_emails_search_vector ON emails USING GIN (search_vector);
