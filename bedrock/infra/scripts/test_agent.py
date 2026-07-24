#!/usr/bin/env python3
"""
Test script for Verify Ticket Agent.
Usage:
    python3 scripts/test_agent.py "Verify ticket CU-12345"
    python3 scripts/test_agent.py "What related tickets for payment-service?" "my-session-id"
"""

import boto3
import sys

AGENT_ID = "LWET2O1MG6"
AGENT_ALIAS_ID = "FUYHYJSTJQ"
REGION = "ap-southeast-1"


def invoke_agent(query: str, session_id: str = "demo-001"):
    client = boto3.client("bedrock-agent-runtime", region_name=REGION)

    print(f"Agent ID:  {AGENT_ID}")
    print(f"Alias:     {AGENT_ALIAS_ID}")
    print(f"Session:   {session_id}")
    print(f"Query:     {query}")
    print("=" * 60)

    response = client.invoke_agent(
        agentId=AGENT_ID,
        agentAliasId=AGENT_ALIAS_ID,
        sessionId=session_id,
        inputText=query,
    )

    result = ""
    for event in response["completion"]:
        if "chunk" in event:
            chunk = event["chunk"]
            if "bytes" in chunk:
                result += chunk["bytes"].decode("utf-8")

    print(result)
    print("=" * 60)
    return result


if __name__ == "__main__":
    query = sys.argv[1] if len(sys.argv) > 1 else "Verify ticket CU-12345"
    session = sys.argv[2] if len(sys.argv) > 2 else "demo-001"
    invoke_agent(query, session)
