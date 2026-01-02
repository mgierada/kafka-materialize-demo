# Kafka + Materialize Demo

This demo showcases real-time stream processing using Apache Kafka and Materialize. A mock producer generates approximately 30 user events per minute, which are streamed through Kafka and can be queried in real-time using SQL through Materialize.

## Architecture

- **Zookeeper**: Coordinates the Kafka cluster
- **Kafka**: Message broker for event streaming
- **Producer**: Python service that generates mock user events
- **Materialize**: Streaming SQL database that reads from Kafka and provides real-time materialized views

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB of available RAM

## Quick Start

### 1. Start all services

```bash
docker-compose up -d
```

This will start:
- Zookeeper on port 2181
- Kafka on ports 9092 (host) and 29092 (internal)
- Materialize on port 6875
- Producer service (automatically starts producing events)

### 2. Verify services are running

```bash
docker-compose ps
```

All services should show as "Up" or "healthy".

### 3. Check producer logs

```bash
docker-compose logs -f producer
```

You should see messages like:
```
[1] Sent page_view event for user_42 to partition 0 at offset 0
[2] Sent purchase event for user_7 to partition 0 at offset 1
```

Press Ctrl+C to exit logs.

### 4. Set up Materialize

Connect to Materialize and create sources and views:

```bash
docker exec -i materialize psql -U materialize -h localhost -p 6875 -d materialize < materialize-setup.sql
```

This creates:
- A Kafka connection with PLAINTEXT security protocol
- A source reading from the `user_events` topic
- Multiple materialized views for different analytics

Note: The setup uses the latest version of Materialize which includes improved permissions and security configurations.

## Querying Data

Connect to Materialize using psql:

```bash
docker exec -it materialize psql -U materialize -h localhost -p 6875
```

### Example Queries

**View all events:**
```sql
SELECT * FROM user_events ORDER BY timestamp DESC LIMIT 10;
```

**Event counts by type:**
```sql
SELECT * FROM event_counts_by_type ORDER BY event_count DESC;
```

**User activity summary:**
```sql
SELECT * FROM user_activity_summary ORDER BY total_events DESC LIMIT 10;
```

**Purchase analytics:**
```sql
SELECT * FROM purchase_analytics ORDER BY total_spent DESC LIMIT 10;
```

**Page view statistics:**
```sql
SELECT * FROM page_view_stats ORDER BY view_count DESC;
```

**Recent events (last 5 minutes):**
```sql
SELECT * FROM recent_events ORDER BY timestamp DESC;
```

**Real-time aggregation - events per minute:**
```sql
SELECT
    DATE_TRUNC('minute', timestamp) AS minute,
    event_type,
    COUNT(*) AS event_count
FROM user_events
GROUP BY DATE_TRUNC('minute', timestamp), event_type
ORDER BY minute DESC
LIMIT 10;
```

**Top users by purchase amount:**
```sql
SELECT
    user_id,
    purchase_count,
    total_spent,
    ROUND(avg_purchase_amount, 2) AS avg_amount
FROM purchase_analytics
WHERE purchase_count > 0
ORDER BY total_spent DESC
LIMIT 5;
```

### Subscribe to Real-time Updates

Materialize supports `SUBSCRIBE` for real-time updates:

```sql
COPY (SUBSCRIBE (SELECT event_type, COUNT(*) FROM user_events GROUP BY event_type)) TO STDOUT;
```

COPY (SUBSCRIBE (SELECT * FROM user_activity_summary ORDER BY total_events DESC)) TO STDOUT;

This will continuously stream updates as new events arrive. Press Ctrl+C to stop.

## Event Types

The producer generates the following event types:

1. **page_view**: User viewing a page
   - Fields: `page`, `duration_seconds`

2. **button_click**: User clicking a button
   - Fields: `button_id`, `page`

3. **form_submit**: User submitting a form
   - Fields: `form_id`, `success`

4. **purchase**: User making a purchase
   - Fields: `product`, `amount`, `currency`

5. **login/logout**: User authentication events
   - Fields: `ip_address`

All events include: `event_id`, `user_id`, `event_type`, `timestamp`, `session_id`

## Configuration

### Adjusting Message Rate

Edit the `docker-compose.yml` file and change the `MESSAGES_PER_MINUTE` environment variable for the producer service:

```yaml
producer:
  environment:
    MESSAGES_PER_MINUTE: 60  # Change to desired rate
```

Then restart the producer:

```bash
docker-compose restart producer
```

### Topic Name

To change the Kafka topic name, update both:
1. `KAFKA_TOPIC` in `docker-compose.yml` (producer service)
2. Topic name in `materialize-setup.sql`

## Troubleshooting

**Producer not sending messages:**
```bash
docker-compose logs producer
```

**Kafka not ready:**
```bash
docker-compose logs kafka
```

**Materialize connection issues:**
```bash
docker-compose logs materialize
```

**Reset everything:**
```bash
docker-compose down -v
docker-compose up -d
```

## Stopping the Demo

Stop all services:
```bash
docker-compose down
```

Stop and remove all data:
```bash
docker-compose down -v
```

## Resources

- [Materialize Documentation](https://materialize.com/docs/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## License

MIT
