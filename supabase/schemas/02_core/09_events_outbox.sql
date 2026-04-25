-- ===========================================
-- EVENTS OUTBOX
-- Transactional outbox pattern for reliable event publication
-- Prevents dual-write between PostgreSQL and message bus
-- Required for multi-server architecture (create_api, train_api, etc.)
-- ===========================================
--
-- How it works:
-- 1. Every domain operation writes to events_outbox IN THE SAME TRANSACTION
--    as the primary data change (e.g. INSERT training_record + INSERT outbox event)
-- 2. lifecycle_monitor polls events_outbox for unprocessed events
-- 3. It publishes each event to downstream consumers (other API servers, webhooks)
-- 4. On success, marks the event as processed
-- 5. pg_notify('events_outbox', ...) gives a low-latency signal to the monitor
-- ===========================================

CREATE TABLE IF NOT EXISTS events_outbox (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Event identity
    aggregate_type      TEXT NOT NULL,     -- domain entity: 'training_record', 'certificate', etc.
    aggregate_id        UUID NOT NULL,     -- ID of the entity that changed
    event_type          TEXT NOT NULL,     -- verb: 'training_record.completed', 'certificate.revoked'
    event_version       INTEGER NOT NULL DEFAULT 1,

    -- Payload (what changed; serialized domain event)
    payload             JSONB NOT NULL DEFAULT '{}',

    -- Delivery tracking
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at        TIMESTAMPTZ,
    processing_started_at TIMESTAMPTZ,

    -- Retry logic (exponential backoff)
    retry_count         INTEGER NOT NULL DEFAULT 0,
    max_retries         INTEGER NOT NULL DEFAULT 5,
    next_retry_at       TIMESTAMPTZ,
    error_text          TEXT,
    error_detail        JSONB,

    -- Dead letter (give up after max_retries)
    is_dead_letter      BOOLEAN NOT NULL DEFAULT FALSE,

    -- Correlation / tracing
    trace_id            TEXT,    -- OpenTelemetry trace ID for distributed tracing
    correlation_id      UUID,    -- Links related events (e.g. all events from one API call)
    causation_id        UUID,    -- ID of the event that caused this one

    -- Source
    source_server       TEXT,    -- which API server created this event (e.g. 'train_api')
    organization_id     UUID,
    plant_id            UUID
);

-- Partial index: only unprocessed, non-dead-letter events are queried by lifecycle_monitor
CREATE INDEX IF NOT EXISTS idx_events_outbox_pending   ON events_outbox(next_retry_at NULLS FIRST, created_at)
    WHERE processed_at IS NULL AND is_dead_letter = FALSE;
CREATE INDEX IF NOT EXISTS idx_events_outbox_aggregate ON events_outbox(aggregate_type, aggregate_id);
CREATE INDEX IF NOT EXISTS idx_events_outbox_type      ON events_outbox(event_type);
CREATE INDEX IF NOT EXISTS idx_events_outbox_trace     ON events_outbox(trace_id) WHERE trace_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_events_outbox_org       ON events_outbox(organization_id);

-- -------------------------------------------------------
-- TRIGGER: pg_notify on INSERT so lifecycle_monitor
-- gets a low-latency signal (avoids polling delay)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION notify_events_outbox()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify(
        'events_outbox',
        json_build_object(
            'id',         NEW.id,
            'event_type', NEW.event_type,
            'aggregate',  NEW.aggregate_type
        )::TEXT
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_events_outbox_notify ON events_outbox;
CREATE TRIGGER trg_events_outbox_notify
    AFTER INSERT ON events_outbox
    FOR EACH ROW EXECUTE FUNCTION notify_events_outbox();

-- -------------------------------------------------------
-- FUNCTION: publish a domain event to the outbox
-- Call this INSIDE the same transaction as the data change
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION publish_event(
    p_aggregate_type    TEXT,
    p_aggregate_id      UUID,
    p_event_type        TEXT,
    p_payload           JSONB DEFAULT '{}',
    p_trace_id          TEXT DEFAULT NULL,
    p_correlation_id    UUID DEFAULT NULL,
    p_source_server     TEXT DEFAULT NULL,
    p_org_id            UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
BEGIN
    INSERT INTO events_outbox (
        aggregate_type, aggregate_id, event_type,
        payload, trace_id, correlation_id,
        source_server, organization_id
    ) VALUES (
        p_aggregate_type, p_aggregate_id, p_event_type,
        p_payload, p_trace_id, p_correlation_id,
        p_source_server, p_org_id
    )
    RETURNING id INTO v_event_id;
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------
-- FUNCTION: mark event as processed (called by lifecycle_monitor)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_event_processed(p_event_id UUID) RETURNS VOID AS $$
    UPDATE events_outbox
    SET processed_at = NOW()
    WHERE id = p_event_id;
$$ LANGUAGE SQL;

-- -------------------------------------------------------
-- FUNCTION: schedule a retry (called by lifecycle_monitor on failure)
-- Uses exponential backoff: 30s, 60s, 120s, 300s, 600s
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION schedule_event_retry(
    p_event_id  UUID,
    p_error     TEXT
) RETURNS VOID AS $$
DECLARE
    v_event events_outbox%ROWTYPE;
    v_backoff_seconds INTEGER[] := ARRAY[30, 60, 120, 300, 600];
    v_delay INTEGER;
BEGIN
    SELECT * INTO v_event FROM events_outbox WHERE id = p_event_id;

    IF v_event.retry_count >= v_event.max_retries THEN
        UPDATE events_outbox
        SET is_dead_letter = TRUE,
            error_text     = p_error,
            error_detail   = jsonb_build_object('final_error', p_error, 'retry_count', v_event.retry_count)
        WHERE id = p_event_id;
    ELSE
        v_delay := v_backoff_seconds[LEAST(v_event.retry_count + 1, array_length(v_backoff_seconds, 1))];
        UPDATE events_outbox
        SET retry_count         = retry_count + 1,
            next_retry_at       = NOW() + (v_delay || ' seconds')::INTERVAL,
            error_text          = p_error,
            processing_started_at = NULL
        WHERE id = p_event_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE  events_outbox IS 'Transactional outbox for reliable event delivery between domain servers — prevents dual-write';
COMMENT ON COLUMN events_outbox.aggregate_type IS 'Domain entity name (e.g. training_record, certificate)';
COMMENT ON COLUMN events_outbox.event_type IS 'Verb-noun event name (e.g. training_record.completed, certificate.revoked)';
COMMENT ON COLUMN events_outbox.is_dead_letter IS 'TRUE when max_retries exceeded — event goes to dead letter queue for manual inspection';
COMMENT ON COLUMN events_outbox.trace_id IS 'OpenTelemetry trace ID for distributed request correlation';
COMMENT ON FUNCTION publish_event IS 'Publish a domain event to the outbox — must be called within the data-change transaction';
COMMENT ON FUNCTION mark_event_processed IS 'Called by lifecycle_monitor to mark successful delivery';
COMMENT ON FUNCTION schedule_event_retry IS 'Schedule exponential backoff retry on delivery failure';
