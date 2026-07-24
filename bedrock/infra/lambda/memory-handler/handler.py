"""
Memory Action Group Handler for Bedrock Agent.
Handles: getVerificationHistory, getRelatedTickets, saveVerificationContext

Uses DynamoDB for persistence. Pre-seeded with mock data on first call if table is empty.
"""

import json
import os
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key


TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "verify-ticket-verification-memory")

# =============================================================================
# SEED DATA - Pre-populated verification records for demo
# =============================================================================

SEED_RECORDS = [
    {
        "ticket_id": "CU-12340",
        "timestamp": "2026-07-10T14:30:00Z",
        "service_name": "payment-service",
        "verification_context": (
            "Verified: Timeout configuration change from 5s to 15s. "
            "Tested with slow network simulation in staging. "
            "No premature timeouts observed. CloudWatch metrics confirmed. "
            "Env var PAYMENT_TIMEOUT_MS works correctly per environment."
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
            "503 with details when DB or Stripe unreachable. "
            "Includes version and uptime in response body. "
            "Tested by killing DB connection - correct 503 returned within 2s."
        ),
        "confidence_score": "0.95",
        "ttl": 1758000000,
    },
    {
        "ticket_id": "CU-12100",
        "timestamp": "2026-06-15T09:00:00Z",
        "service_name": "notification-service",
        "verification_context": (
            "Verified: Email notification delivery. SES integration tested. "
            "Templates render correctly. Unsubscribe link works. "
            "Rate limiting applied: max 10 emails/user/hour."
        ),
        "confidence_score": "0.85",
        "ttl": 1758000000,
    },
    {
        "ticket_id": "CU-11950",
        "timestamp": "2026-06-01T16:45:00Z",
        "service_name": "payment-service",
        "verification_context": (
            "Verified: Stripe webhook signature validation. "
            "Invalid signatures correctly rejected with 400. "
            "Valid signatures processed. Replay attacks prevented by timestamp check. "
            "Edge case: clock skew > 5min also rejected."
        ),
        "confidence_score": "0.92",
        "ttl": 1758000000,
    },
]


def get_table():
    """Get DynamoDB table resource."""
    dynamodb = boto3.resource("dynamodb")
    return dynamodb.Table(TABLE_NAME)


def ensure_seed_data():
    """Seed demo data if table is empty."""
    table = get_table()

    # Check if table has data
    response = table.scan(Limit=1)
    if response.get("Items"):
        return  # Already has data

    print("[SEED] Populating verification memory with demo data")
    for record in SEED_RECORDS:
        table.put_item(Item=record)
    print(f"[SEED] Added {len(SEED_RECORDS)} seed records")


def handle_get_verification_history(ticket_id):
    """Get past verification records for a ticket."""
    # Normalize ticket_id
    if not ticket_id.startswith("CU-"):
        ticket_id = f"CU-{ticket_id}"

    table = get_table()

    response = table.query(
        KeyConditionExpression=Key("ticket_id").eq(ticket_id),
        ScanIndexForward=False,  # Most recent first
        Limit=10,
    )

    records = []
    for item in response.get("Items", []):
        records.append(
            {
                "ticket_id": item.get("ticket_id", ""),
                "timestamp": item.get("timestamp", ""),
                "verification_context": item.get("verification_context", ""),
                "confidence_score": float(item.get("confidence_score", 0)),
                "service_name": item.get("service_name", ""),
            }
        )

    if not records:
        return {"records": [], "message": f"No verification history found for {ticket_id}"}

    return {"records": records}


def handle_get_related_tickets(service_name, limit=5):
    """Find related verified tickets by service name."""
    table = get_table()

    response = table.query(
        IndexName="service-index",
        KeyConditionExpression=Key("service_name").eq(service_name),
        ScanIndexForward=False,
        Limit=int(limit),
    )

    related = []
    for item in response.get("Items", []):
        related.append(
            {
                "ticket_id": item.get("ticket_id", ""),
                "service_name": item.get("service_name", ""),
                "timestamp": item.get("timestamp", ""),
                "summary": item.get("verification_context", "")[:200],
            }
        )

    if not related:
        return {"related_tickets": [], "message": f"No related tickets found for service: {service_name}"}

    return {"related_tickets": related}


def handle_save_verification_context(ticket_id, service_name, verification_context, confidence_score=0.5):
    """Save a verification context record."""
    # Normalize ticket_id
    if not ticket_id.startswith("CU-"):
        ticket_id = f"CU-{ticket_id}"

    table = get_table()
    timestamp = datetime.now(timezone.utc).isoformat()

    # TTL: 90 days from now
    ttl = int(datetime.now(timezone.utc).timestamp()) + (90 * 24 * 60 * 60)

    item = {
        "ticket_id": ticket_id,
        "timestamp": timestamp,
        "service_name": service_name,
        "verification_context": verification_context,
        "confidence_score": str(confidence_score),
        "ttl": ttl,
    }

    table.put_item(Item=item)

    return {"success": True, "record_id": f"{ticket_id}#{timestamp}"}


def lambda_handler(event, context):
    """Main Lambda handler for Bedrock Agent action group."""
    print(f"Event: {json.dumps(event)}")

    # Ensure seed data exists on every invocation (idempotent)
    try:
        ensure_seed_data()
    except Exception as e:
        print(f"[SEED] Warning: could not seed data: {e}")

    action_group = event.get("actionGroup", "")
    api_path = event.get("apiPath", "")
    parameters = event.get("parameters", [])
    request_body = event.get("requestBody", {})

    # Build params dict from parameters array
    params = {}
    for p in parameters:
        params[p["name"]] = p["value"]

    # Also extract from request body if present (for POST)
    if request_body:
        body_content = request_body.get("content", {})
        json_body = body_content.get("application/json", {})
        if "properties" in json_body:
            for prop in json_body["properties"]:
                params[prop["name"]] = prop["value"]

    # Route to handler
    if api_path == "/getVerificationHistory":
        result = handle_get_verification_history(params.get("ticketId", ""))
    elif api_path == "/getRelatedTickets":
        result = handle_get_related_tickets(
            params.get("serviceName", ""),
            params.get("limit", 5),
        )
    elif api_path == "/saveVerificationContext":
        result = handle_save_verification_context(
            ticket_id=params.get("ticketId", ""),
            service_name=params.get("serviceName", ""),
            verification_context=params.get("verificationContext", ""),
            confidence_score=float(params.get("confidenceScore", 0.5)),
        )
    else:
        result = {"error": f"Unknown action: {api_path}"}

    # Return in Bedrock Agent action group response format
    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": action_group,
            "apiPath": api_path,
            "httpMethod": event.get("httpMethod", "GET"),
            "httpStatusCode": 200,
            "responseBody": {"application/json": {"body": json.dumps(result)}},
        },
    }
