-- Add recommendation_count column to emails table for tracking extracted recommendations.
ALTER TABLE emails ADD COLUMN IF NOT EXISTS recommendation_count INTEGER DEFAULT 0;
