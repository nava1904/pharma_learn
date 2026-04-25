-- Migration: Add QR token fields to training_sessions
-- Gap G1: Per-session signed QR token for secure check-in
-- Reference: Design Decision Q4

ALTER TABLE training_sessions
ADD COLUMN IF NOT EXISTS qr_token TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS qr_expires_at TIMESTAMPTZ;

COMMENT ON COLUMN training_sessions.qr_token IS 
  'HMAC-signed token: base64url(session_id|expires_at).HMAC-SHA256. Generated when session starts.';

COMMENT ON COLUMN training_sessions.qr_expires_at IS 
  'Token expiry timestamp, typically session end_time + grace period.';

-- Index for token lookup during check-in
CREATE INDEX IF NOT EXISTS idx_training_sessions_qr_token 
  ON training_sessions(qr_token) 
  WHERE qr_token IS NOT NULL;
