"""Publishes mock clickstream events to Pub/Sub."""
import json
import os
import random
import time
import uuid
from datetime import datetime, timezone

from google.cloud import pubsub_v1

PROJECT_ID = os.environ["PROJECT_ID"]
TOPIC_ID = os.environ.get("TOPIC", "clickstream-events")
EVENTS_PER_SECOND = int(os.environ.get("EVENTS_PER_SECOND", "20"))
EVENT_TYPES = ["page_view", "add_to_cart", "checkout", "purchase"]

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)


def make_event():
    now = datetime.now(timezone.utc)
    return {
        "user_id": f"user_{random.randint(1, 500)}",
        "event_type": random.choice(EVENT_TYPES),
        # yyyy-MM-dd HH:mm:ss.SSS, the default timestamp format of Flink's JSON format
        "event_ts": now.strftime("%Y-%m-%d %H:%M:%S.") + f"{now.microsecond // 1000:03d}",
        "session_id": uuid.uuid4().hex[:8],
    }


def main():
    while True:
        for _ in range(EVENTS_PER_SECOND):
            publisher.publish(topic_path, json.dumps(make_event()).encode("utf-8"))
        time.sleep(1)


if __name__ == "__main__":
    main()
