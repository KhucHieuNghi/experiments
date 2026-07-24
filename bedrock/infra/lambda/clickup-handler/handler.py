"""
ClickUp Action Group Handler for Bedrock Agent.
MOCK MODE: Returns realistic sample data for demo purposes.
Handles: getTask, getTaskComments, searchTasks
"""

import json
import os

# =============================================================================
# MOCK DATA - Simulates ClickUp responses for demo
# =============================================================================

MOCK_TASKS = {
    "12345": {
        "id": "12345",
        "name": "Add retry logic to payment service",
        "description": (
            "## Description\n"
            "Implement retry logic for payment gateway calls in the payment service.\n\n"
            "## Acceptance Criteria\n"
            "- Retry up to 3 times on transient failures (5xx, timeout)\n"
            "- Use exponential backoff: 1s, 2s, 4s\n"
            "- Must be idempotent - no double charges\n"
            "- Circuit breaker after 5 consecutive failures\n"
            "- Log each retry attempt with correlation ID\n\n"
            "## Technical Notes\n"
            "- Payment gateway: Stripe API\n"
            "- Affected service: src/services/payment/\n"
            "- Related config: src/config/payment.ts\n"
        ),
        "status": "in review",
        "assignee": "david.nguyen",
        "priority": "high",
        "date_created": "1721520000000",
        "date_updated": "1721865600000",
        "tags": ["backend", "payment", "reliability"],
    },
    "12340": {
        "id": "12340",
        "name": "Fix timeout configuration in payment service",
        "description": (
            "## Description\n"
            "Payment service timeout is too short (5s) causing failures on slow network.\n"
            "Increase to 15s and add configurable timeout per environment.\n\n"
            "## Acceptance Criteria\n"
            "- Timeout configurable via env var PAYMENT_TIMEOUT_MS\n"
            "- Default: 15000ms for production, 5000ms for test\n"
            "- Add timeout metrics to CloudWatch\n"
        ),
        "status": "closed",
        "assignee": "david.nguyen",
        "priority": "medium",
        "date_created": "1720310400000",
        "date_updated": "1720742400000",
        "tags": ["backend", "payment", "config"],
    },
    "12288": {
        "id": "12288",
        "name": "Add health check endpoint to payment service",
        "description": (
            "## Description\n"
            "Add /health endpoint that checks DB connection and Stripe API reachability.\n\n"
            "## Acceptance Criteria\n"
            "- GET /health returns 200 if all deps healthy\n"
            "- Returns 503 with details if any dep unhealthy\n"
            "- Response includes version and uptime\n"
        ),
        "status": "closed",
        "assignee": "lisa.tran",
        "priority": "medium",
        "date_created": "1719187200000",
        "date_updated": "1719619200000",
        "tags": ["backend", "payment", "infra"],
    },
    "12500": {
        "id": "12500",
        "name": "Implement user notification preferences API",
        "description": (
            "## Description\n"
            "Create REST API for managing user notification preferences.\n\n"
            "## Acceptance Criteria\n"
            "- GET /users/:id/preferences - retrieve current prefs\n"
            "- PUT /users/:id/preferences - update prefs\n"
            "- Support: email, push, sms, in-app channels\n"
            "- Validate channel-specific settings\n"
        ),
        "status": "in progress",
        "assignee": "anna.le",
        "priority": "medium",
        "date_created": "1721606400000",
        "date_updated": "1721779200000",
        "tags": ["backend", "notifications", "api"],
    },
}

MOCK_COMMENTS = {
    "12345": [
        {
            "id": "c001",
            "comment_text": "Make sure we handle the case where Stripe returns 402 (payment required) - that should NOT be retried since it means insufficient funds.",
            "user": "lisa.tran",
            "date": "1721606400000",
        },
        {
            "id": "c002",
            "comment_text": "Agreed. Only retry on 5xx and network timeouts. 4xx errors are client errors and should fail immediately. I'll add a retryable error codes allowlist.",
            "user": "david.nguyen",
            "date": "1721692800000",
        },
        {
            "id": "c003",
            "comment_text": "QA note: Please ensure we have logging for each retry attempt so we can trace payment flows in production. Also need to verify idempotency key is sent on retry.",
            "user": "minh.qa",
            "date": "1721779200000",
        },
    ],
    "12340": [
        {
            "id": "c010",
            "comment_text": "Verified: timeout now configurable. Tested with 15s in staging, no more premature timeouts on slow Stripe responses.",
            "user": "minh.qa",
            "date": "1720656000000",
        },
    ],
}


def handle_get_task(task_id):
    """Fetch a single task - returns mock data."""
    clean_id = task_id.replace("CU-", "").replace("cu-", "").strip()

    task = MOCK_TASKS.get(clean_id)
    if task:
        return task

    # Return a generic mock for unknown IDs
    return {
        "id": clean_id,
        "name": f"[Mock] Task {clean_id}",
        "description": "This is a mock task. No real ClickUp data available for this ID.",
        "status": "open",
        "assignee": "unassigned",
        "priority": "none",
        "date_created": "1721520000000",
        "date_updated": "1721520000000",
        "tags": [],
    }


def handle_get_comments(task_id):
    """Fetch comments for a task - returns mock data."""
    clean_id = task_id.replace("CU-", "").replace("cu-", "").strip()

    comments = MOCK_COMMENTS.get(clean_id, [])
    if not comments:
        return {
            "comments": [
                {
                    "id": "c000",
                    "comment_text": "[Mock] No comments found for this task.",
                    "user": "system",
                    "date": "1721520000000",
                }
            ]
        }

    return {"comments": comments}


def handle_search_tasks(query):
    """Search tasks - returns mock results matching query."""
    query_lower = query.lower()
    results = []

    for task in MOCK_TASKS.values():
        # Simple keyword matching
        searchable = f"{task['name']} {task['description']} {' '.join(task['tags'])}".lower()
        if query_lower in searchable:
            results.append(
                {
                    "id": task["id"],
                    "name": task["name"],
                    "status": task["status"],
                    "date_updated": task["date_updated"],
                }
            )

    if not results:
        results = [
            {
                "id": "12345",
                "name": "Add retry logic to payment service",
                "status": "in review",
                "date_updated": "1721865600000",
            }
        ]

    return {"tasks": results}


def lambda_handler(event, context):
    """Main Lambda handler for Bedrock Agent action group."""
    print(f"Event: {json.dumps(event)}")
    print("[MOCK MODE] Using simulated ClickUp data")

    # Extract action and parameters from Bedrock Agent event
    action_group = event.get("actionGroup", "")
    api_path = event.get("apiPath", "")
    parameters = event.get("parameters", [])

    # Build params dict
    params = {}
    for p in parameters:
        params[p["name"]] = p["value"]

    # Route to handler
    if api_path == "/getTask":
        result = handle_get_task(params.get("taskId", ""))
    elif api_path == "/getTaskComments":
        result = handle_get_comments(params.get("taskId", ""))
    elif api_path == "/searchTasks":
        result = handle_search_tasks(params.get("query", ""))
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
