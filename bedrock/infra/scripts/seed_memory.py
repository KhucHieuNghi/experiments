#!/usr/bin/env python3
"""
Seed DynamoDB verification memory with sample records for demo.
Run once after terraform apply.

Usage:
    python3 scripts/seed_memory.py
"""

import boto3

REGION = "ap-southeast-1"
TABLE_NAME = "verify-ticket-verification-memory"

SEED_RECORDS = [
    {
        "ticket_id": "CU-12340",
        "timestamp": "2026-07-10T14:30:00Z",
        "service_name": "payment-service",
        "verification_context": (
            "Verified: Timeout configuration change from 5s to 15s. "
            "Tested with slow network simulation in staging. "
            "No premature timeouts observed. CloudWatch metrics confirmed."
        ),
        "confidence_score": "0.9",
        "ttl": 1758000000,
    },
    {
        "ticket_id": "CU-12288",
        "timestamp": "2026-06-28T10:15:00Z",
        "service_name": "payment-service",
        "verification_context": (
            "Verified: Health check endpoint /health returns 200 when all deps healthy, "
            "503 with details when DB or Stripe unreachable."
        ),
        "confidence_score": "0.95",
        "ttl": 1758000000,
    },
    {
        "ticket_id": "CU-11950",
        "timestamp": "2026-06-01T16:45:00Z",
        "service_name": "payment-service",
        "verification_context": (
            "Verified: Stripe webhook signature validation. "
            "Invalid signatures correctly rejected with 400. "
            "Replay attacks prevented by timestamp check."
        ),
        "confidence_score": "0.92",
        "ttl": 1758000000,
    },
    {
        "ticket_id": "CU-12100",
        "timestamp": "2026-06-15T09:00:00Z",
        "service_name": "notification-service",
        "verification_context": (
            "Verified: Email notification delivery. SES integration tested. "
            "Templates render correctly. Unsubscribe link works."
        ),
        "confidence_score": "0.85",
        "ttl": 1758000000,
    },
]


def main():
    dynamodb = boto3.resource("dynamodb", region_name=REGION)
    table = dynamodb.Table(TABLE_NAME)

    print(f"Seeding table: {TABLE_NAME}")
    for record in SEED_RECORDS:
        table.put_item(Item=record)
        print(f"  + {record['ticket_id']} ({record['service_name']})")

    print(f"\nDone! {len(SEED_RECORDS)} records seeded.")


if __name__ == "__main__":
    main()
