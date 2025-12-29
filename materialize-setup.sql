-- Materialize Setup Script for Kafka Integration
-- Run this after starting all services with: docker exec -i materialize psql -U materialize -h localhost -p 6875

-- Create a connection to Kafka
CREATE CONNECTION kafka_connection TO KAFKA (
    BROKER 'kafka:29092'
);

-- Create a source from the Kafka topic
CREATE SOURCE user_events_source
FROM KAFKA CONNECTION kafka_connection (TOPIC 'user_events')
FORMAT JSON
ENVELOPE NONE;

-- Create a materialized view with all events
CREATE MATERIALIZED VIEW user_events AS
SELECT
    (data->>'event_id')::text AS event_id,
    (data->>'user_id')::text AS user_id,
    (data->>'event_type')::text AS event_type,
    (data->>'timestamp')::timestamp AS timestamp,
    (data->>'session_id')::text AS session_id,
    (data->>'page')::text AS page,
    (data->>'duration_seconds')::int AS duration_seconds,
    (data->>'button_id')::text AS button_id,
    (data->>'form_id')::text AS form_id,
    (data->>'success')::bool AS success,
    (data->>'product')::text AS product,
    (data->>'amount')::numeric AS amount,
    (data->>'currency')::text AS currency,
    (data->>'ip_address')::text AS ip_address
FROM user_events_source;

-- Create a materialized view for event counts by type
CREATE MATERIALIZED VIEW event_counts_by_type AS
SELECT
    event_type,
    COUNT(*) AS event_count
FROM user_events
GROUP BY event_type;

-- Create a materialized view for user activity summary
CREATE MATERIALIZED VIEW user_activity_summary AS
SELECT
    user_id,
    COUNT(*) AS total_events,
    COUNT(DISTINCT event_type) AS unique_event_types,
    MIN(timestamp) AS first_event,
    MAX(timestamp) AS last_event
FROM user_events
GROUP BY user_id;

-- Create a materialized view for purchase analytics
CREATE MATERIALIZED VIEW purchase_analytics AS
SELECT
    user_id,
    COUNT(*) AS purchase_count,
    SUM(amount) AS total_spent,
    AVG(amount) AS avg_purchase_amount,
    MAX(timestamp) AS last_purchase
FROM user_events
WHERE event_type = 'purchase'
GROUP BY user_id;

-- Create a materialized view for page views with duration stats
CREATE MATERIALIZED VIEW page_view_stats AS
SELECT
    page,
    COUNT(*) AS view_count,
    AVG(duration_seconds) AS avg_duration,
    MIN(duration_seconds) AS min_duration,
    MAX(duration_seconds) AS max_duration
FROM user_events
WHERE event_type = 'page_view'
GROUP BY page;

-- Create a materialized view for recent events (last 5 minutes)
CREATE MATERIALIZED VIEW recent_events AS
SELECT
    event_id,
    user_id,
    event_type,
    timestamp,
    CASE
        WHEN event_type = 'page_view' THEN page
        WHEN event_type = 'purchase' THEN product
        ELSE event_type
    END AS detail
FROM user_events
WHERE timestamp > NOW() - INTERVAL '5 minutes';
