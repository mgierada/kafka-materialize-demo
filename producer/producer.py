import os
import json
import time
import random
import uuid
from datetime import datetime
from kafka import KafkaProducer
from kafka.errors import KafkaError

# Configuration from environment variables
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
KAFKA_TOPIC = os.getenv('KAFKA_TOPIC', 'user_events')
MESSAGES_PER_MINUTE = int(os.getenv('MESSAGES_PER_MINUTE', '30'))

# Calculate sleep time between messages
SLEEP_TIME = 60.0 / MESSAGES_PER_MINUTE

# Sample data for generating realistic events
PAGES = ['home', 'products', 'checkout', 'profile', 'about', 'contact', 'blog', 'search']
BUTTON_IDS = ['btn_add_cart', 'btn_checkout', 'btn_subscribe', 'btn_share', 'btn_like', 'btn_follow']
FORM_IDS = ['form_login', 'form_signup', 'form_contact', 'form_checkout', 'form_profile']
PRODUCTS = ['laptop', 'smartphone', 'headphones', 'keyboard', 'mouse', 'monitor', 'tablet', 'camera']
CURRENCIES = ['USD', 'EUR', 'GBP']
USER_IDS = list(range(1, 101))  # 100 users
IP_ADDRESSES = [f'192.168.{random.randint(1, 255)}.{random.randint(1, 255)}' for _ in range(50)]

# Session management
user_sessions = {}


def get_session_id(user_id):
    """Get or create a session ID for a user"""
    if user_id not in user_sessions:
        user_sessions[user_id] = str(uuid.uuid4())
    # Occasionally reset session (10% chance)
    elif random.random() < 0.1:
        user_sessions[user_id] = str(uuid.uuid4())
    return user_sessions[user_id]


def generate_event():
    """Generate a random user event"""
    user_id = random.choice(USER_IDS)
    session_id = get_session_id(user_id)
    event_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat() + 'Z'

    # Choose event type with weighted probabilities
    event_type = random.choices(
        ['page_view', 'button_click', 'form_submit', 'purchase', 'login', 'logout'],
        weights=[40, 25, 15, 10, 5, 5],
        k=1
    )[0]

    base_event = {
        'event_id': event_id,
        'user_id': user_id,
        'event_type': event_type,
        'timestamp': timestamp,
        'session_id': session_id
    }

    # Add event-specific data
    if event_type == 'page_view':
        base_event['page'] = random.choice(PAGES)
        base_event['duration_seconds'] = random.randint(5, 300)

    elif event_type == 'button_click':
        base_event['button_id'] = random.choice(BUTTON_IDS)
        base_event['page'] = random.choice(PAGES)

    elif event_type == 'form_submit':
        base_event['form_id'] = random.choice(FORM_IDS)
        base_event['success'] = random.choice([True, True, True, False])  # 75% success rate

    elif event_type == 'purchase':
        base_event['product'] = random.choice(PRODUCTS)
        base_event['amount'] = round(random.uniform(10.0, 999.99), 2)
        base_event['currency'] = random.choice(CURRENCIES)

    elif event_type in ['login', 'logout']:
        base_event['ip_address'] = random.choice(IP_ADDRESSES)

    return base_event


def create_producer():
    """Create and configure Kafka producer"""
    return KafkaProducer(
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        key_serializer=lambda k: str(k).encode('utf-8') if k else None,
        acks='all',
        retries=3,
        max_in_flight_requests_per_connection=1
    )


def main():
    print(f'Starting Kafka producer...')
    print(f'Bootstrap servers: {KAFKA_BOOTSTRAP_SERVERS}')
    print(f'Topic: {KAFKA_TOPIC}')
    print(f'Messages per minute: {MESSAGES_PER_MINUTE}')
    print(f'Sleep time between messages: {SLEEP_TIME:.2f} seconds')
    print('-' * 60)

    # Wait for Kafka to be ready
    max_retries = 30
    retry_count = 0

    while retry_count < max_retries:
        try:
            producer = create_producer()
            print('Successfully connected to Kafka!')
            break
        except KafkaError as e:
            retry_count += 1
            print(f'Waiting for Kafka... (attempt {retry_count}/{max_retries})')
            time.sleep(2)
    else:
        print('Failed to connect to Kafka after maximum retries')
        return

    message_count = 0

    try:
        while True:
            try:
                # Generate and send event
                event = generate_event()

                # Use user_id as the key for partitioning
                future = producer.send(
                    KAFKA_TOPIC,
                    key=event['user_id'],
                    value=event
                )

                # Wait for the message to be sent
                record_metadata = future.get(timeout=10)

                message_count += 1
                print(f'[{message_count}] Sent {event["event_type"]} event for user_{event["user_id"]} '
                      f'to partition {record_metadata.partition} at offset {record_metadata.offset}')

                # Sleep to maintain the desired rate
                time.sleep(SLEEP_TIME)

            except KafkaError as e:
                print(f'Error sending message: {e}')
                time.sleep(1)
            except KeyboardInterrupt:
                print('\nShutting down gracefully...')
                break

    finally:
        producer.flush()
        producer.close()
        print(f'Producer stopped. Total messages sent: {message_count}')


if __name__ == '__main__':
    main()
