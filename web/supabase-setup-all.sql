-- =====================================================================
-- Otis / call-auditor — ONE-SHOT database setup for a NEW Supabase project.
-- Supabase → SQL Editor → New query → paste this whole file → Run.
-- If asked about Row Level Security, choose "Run without RLS".
-- Safe to run twice (everything is IF NOT EXISTS).
--
-- The original migrations assume an `audits` table already exists, so this
-- file creates it first, then runs the migrations in order, then adds the
-- columns the code uses that no migration created.
-- =====================================================================

CREATE TABLE IF NOT EXISTS audits (
    id                    TEXT PRIMARY KEY,
    timestamp             TEXT NOT NULL,
    source                TEXT,
    target                TEXT,
    preset                TEXT,
    strictness            TEXT,
    custom_focus          TEXT,
    llm_provider          TEXT,
    llm_fallback_reason   TEXT,
    overall_score         DOUBLE PRECISION,
    summary               TEXT,
    scores_json           TEXT,
    strengths             TEXT,
    what_was_lacking      TEXT,
    recommendations_json  TEXT,
    compliance_json       TEXT,
    transcript            TEXT
);

CREATE INDEX IF NOT EXISTS idx_audits_timestamp ON audits(timestamp DESC);
ALTER TABLE audits DISABLE ROW LEVEL SECURITY;


-- ---------------------------------------------------------------------
-- from supabase-migration.sql
-- ---------------------------------------------------------------------
-- Run this once in Supabase → SQL Editor → New query.
-- It's idempotent: safe to run twice, won't touch existing rows that already
-- have these columns.

ALTER TABLE audits
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'completed';

ALTER TABLE audits
  ADD COLUMN IF NOT EXISTS transcript_id TEXT;

ALTER TABLE audits
  ADD COLUMN IF NOT EXISTS error_message TEXT;

CREATE INDEX IF NOT EXISTS idx_audits_status ON audits(status);
CREATE INDEX IF NOT EXISTS idx_audits_transcript_id ON audits(transcript_id);

-- Status values used by the app:
--   'transcribing'  — submitted to AssemblyAI, awaiting webhook
--   'scoring'       — transcription done, running LLM
--   'completed'     — fully scored
--   'failed'        — see error_message column


-- ---------------------------------------------------------------------
-- from supabase-agents-migration.sql
-- ---------------------------------------------------------------------
-- Run once in Supabase → SQL Editor. Idempotent.

CREATE TABLE IF NOT EXISTS agents (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    target          TEXT,
    description     TEXT,
    knowledge_base  TEXT,
    created_at      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_agents_created ON agents(created_at DESC);

-- Link audits to an agent (nullable — agent-less audits stay valid).
ALTER TABLE audits
  ADD COLUMN IF NOT EXISTS agent_id TEXT;

CREATE INDEX IF NOT EXISTS idx_audits_agent ON audits(agent_id);


-- ---------------------------------------------------------------------
-- from supabase-batches-migration.sql
-- ---------------------------------------------------------------------
-- Batch auditing: upload a spreadsheet of recording URLs.
-- Run once in Supabase -> SQL Editor. Idempotent.

CREATE TABLE IF NOT EXISTS batches (
    id            TEXT PRIMARY KEY,
    label         TEXT,
    agent_id      TEXT,
    preset        TEXT,
    strictness    TEXT,
    custom_focus  TEXT,
    url_column    TEXT,
    total         INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_batches_created ON batches(created_at DESC);

ALTER TABLE audits ADD COLUMN IF NOT EXISTS batch_id TEXT;
CREATE INDEX IF NOT EXISTS idx_audits_batch ON audits(batch_id);

-- Match the rest of the app: no row-level security (public, no auth).
-- This avoids the "insert works but reads 404" trap.
ALTER TABLE batches DISABLE ROW LEVEL SECURITY;

-- audits.status now also takes 'queued' (a batch row awaiting submission).


-- ---------------------------------------------------------------------
-- from supabase-duration-migration.sql
-- ---------------------------------------------------------------------
-- Call-recording duration, in seconds, per audit.
-- Powers the dashboard duration filter. Run once in Supabase → SQL Editor.
-- Idempotent: safe to run twice.

ALTER TABLE audits
  ADD COLUMN IF NOT EXISTS duration_seconds INTEGER;

CREATE INDEX IF NOT EXISTS idx_audits_duration ON audits(duration_seconds);

-- New audits fill this in automatically when they finish scoring
-- (from AssemblyAI's audio_duration). Existing rows are backfilled by
-- hitting POST /api/admin/backfill-duration after deploy.


-- ---------------------------------------------------------------------
-- from supabase-audited-at-migration.sql
-- ---------------------------------------------------------------------
-- When an audit finished scoring (distinct from `timestamp`, the upload time).
-- Run once in Supabase → SQL Editor. Idempotent.
--
-- New audits set this automatically on finalize. Existing rows stay NULL;
-- the dashboard/export fall back to the upload timestamp for those.

ALTER TABLE audits
  ADD COLUMN IF NOT EXISTS audited_at TEXT;


-- ---------------------------------------------------------------------
-- from supabase-rubric-migration.sql
-- ---------------------------------------------------------------------
-- Per-agent scoring rubric: the list of dimensions and each one's min/max
-- score range, as JSON. NULL means "use the built-in default 10 dimensions".
-- Run once in Supabase → SQL Editor. Idempotent.

ALTER TABLE agents
  ADD COLUMN IF NOT EXISTS rubric_json TEXT;


-- ---------------------------------------------------------------------
-- from supabase-review-status-migration.sql
-- ---------------------------------------------------------------------
-- Manual review state for each audit: reviewers mark a recording's audit
-- report as reviewed / flagged; anything untouched stays 'not_reviewed'.
-- Run once in Supabase → SQL Editor. Idempotent.

ALTER TABLE audits
  ADD COLUMN IF NOT EXISTS review_status TEXT NOT NULL DEFAULT 'not_reviewed';

CREATE INDEX IF NOT EXISTS idx_audits_review_status
  ON audits(review_status);


-- ---------------------------------------------------------------------
-- from supabase-report-settings-migration.sql
-- ---------------------------------------------------------------------
-- Settings for the automated daily email report. Single row (id = 'default').
-- Run once in Supabase → SQL Editor. Idempotent.

CREATE TABLE IF NOT EXISTS report_settings (
    id              TEXT PRIMARY KEY DEFAULT 'default',
    emails          TEXT,            -- comma-separated recipients
    send_time       TEXT,            -- "HH:MM" in the timezone below
    timezone        TEXT NOT NULL DEFAULT 'IST',
    enabled         BOOLEAN NOT NULL DEFAULT false,
    last_sent_date  TEXT,            -- "YYYY-MM-DD" (IST) the report last went out
    updated_at      TEXT
);

ALTER TABLE report_settings DISABLE ROW LEVEL SECURITY;

INSERT INTO report_settings (id, enabled, timezone)
VALUES ('default', false, 'IST')
ON CONFLICT (id) DO NOTHING;


-- ---------------------------------------------------------------------
-- Columns the code writes that no migration above creates
-- ---------------------------------------------------------------------
ALTER TABLE audits ADD COLUMN IF NOT EXISTS call_id           TEXT;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS mobile_number     TEXT;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS disconnect_reason TEXT;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS needs_review      BOOLEAN DEFAULT false;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS review_reason     TEXT;
ALTER TABLE audits ADD COLUMN IF NOT EXISTS reviewed_at       TEXT;
CREATE INDEX IF NOT EXISTS idx_audits_call_id ON audits(call_id);

ALTER TABLE batches ADD COLUMN IF NOT EXISTS name              TEXT;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS deleted_at        TEXT;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS focus_report_json TEXT;

ALTER TABLE agents DISABLE ROW LEVEL SECURITY;
