-- Enable extensions used by the emailer schema.
-- gen_random_uuid() is available natively in PostgreSQL 13+, but
-- we enable pgcrypto for additional crypto functions if needed.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
