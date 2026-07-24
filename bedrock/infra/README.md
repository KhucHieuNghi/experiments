# Verify Ticket Agent - AWS Bedrock Demo

Demo deployment of a Bedrock Agent that verifies tickets by combining ClickUp data (mock), codebase knowledge (RAG), and verification history (DynamoDB memory).

## Architecture Diagram

[View on Eraser](https://app.eraser.io/workspace/1pmeGIwmvNUdmJg3UcHn?diagram=ebULjbW40uspYYmz5pP0&layout=canvas)

## Current Deployment Status

| Component | Status | Details |
|---|---|---|
| Bedrock Agent | Running | ID: `LWET2O1MG6`, Alias: `FUYHYJSTJQ` |
| Model | Amazon Nova Pro | `apac.amazon.nova-pro-v1:0` (APAC Inference Profile) |
| ClickUp Action Group | Mock mode | Lambda returns hardcoded sample tickets (no API calls) |
| Memory Action Group | Working | DynamoDB with 4 pre-seeded verification records |
| Knowledge Base | Ingestion pending | Embedding model (Cohere) needs Marketplace access to enable |
| S3 Documents | Uploaded | 5 sample architecture/QA docs |
| OpenSearch Serverless | Created | Vector index ready, waiting for KB ingestion |
| DynamoDB | Working | PAY_PER_REQUEST, GSI on service_name |
| Secrets Manager | Placeholder | Token stored but not used in mock mode |

## AWS Stacks Overview

### Bedrock Services (Fully Managed, No VPC)

| Service | Resource | Purpose |
|---|---|---|
| **Bedrock Agent** | `verify-ticket-verify-ticket` | Orchestrates tool calls, reasoning, and response synthesis |
| **Foundation Model** | `apac.amazon.nova-pro-v1:0` | LLM reasoning via APAC inference profile (cross-region) |
| **Knowledge Base** | `verify-ticket-codebase-docs` | RAG retrieval with citations from codebase documents |
| **Data Source** | S3-backed | Connects S3 documents to Knowledge Base for chunking/embedding |

### Compute (Lambda, No VPC)

| Service | Resource | Purpose |
|---|---|---|
| **Lambda** | `verify-ticket-clickup-handler` | Action group: returns mock ClickUp task data (getTask, getTaskComments, searchTasks) |
| **Lambda** | `verify-ticket-memory-handler` | Action group: reads/writes verification history from DynamoDB (getVerificationHistory, getRelatedTickets, saveVerificationContext) |

### Storage

| Service | Resource | Purpose |
|---|---|---|
| **S3** | `verify-ticket-kb-documents-931990754082` | Stores documents for RAG: architecture docs, QA history, runbooks |
| **DynamoDB** | `verify-ticket-verification-memory` | Long-term verification memory. PK: ticket_id, SK: timestamp. GSI: service_name |
| **OpenSearch Serverless** | `verify-ticket-kb-vectors` | Vector store for Knowledge Base embeddings (FAISS, HNSW, dim=1024) |
| **Secrets Manager** | `verify-ticket/clickup-api-token` | Stores ClickUp API token (placeholder in mock mode) |

### Security & IAM

| Role | Trust Principal | Permissions |
|---|---|---|
| `verify-ticket-bedrock-agent-role` | `bedrock.amazonaws.com` | InvokeModel (*), Retrieve from KB |
| `verify-ticket-kb-role` | `bedrock.amazonaws.com` | S3 GetObject/ListBucket, AOSS APIAccessAll, InvokeModel (embed) |
| `verify-ticket-lambda-action-group-role` | `lambda.amazonaws.com` | CloudWatch Logs, DynamoDB CRUD, SecretsManager GetSecretValue |

### Networking & Access

| Resource | Network | Access |
|---|---|---|
| Bedrock Agent | AWS Managed (no VPC) | Invoked via AWS SDK (bedrock-agent-runtime) |
| Lambda Functions | No VPC (default) | Invoked by Bedrock Agent only (resource policy) |
| S3 Bucket | N/A | Private. Public access blocked. SSE-AES256 |
| DynamoDB | AWS Managed | Accessed by Lambda role only |
| OpenSearch Serverless | Public endpoint | Data access policy restricts to KB role + account root |
| Secrets Manager | AWS Managed | Accessed by Lambda role only |

**Note:** This demo does NOT use VPC, Security Groups, or NAT Gateways. All services are fully managed with IAM-based access control. For production, Lambda functions accessing external APIs (ClickUp) would need VPC + NAT Gateway or VPC Endpoints.

## Quick Start

### Prerequisites

- AWS CLI configured (`~/.aws/credentials` with `default` profile)
- Python 3.9+ with boto3 (`pip3 install boto3`)
- Terraform >= 1.5 (only needed if redeploying)

### Run Demo

```bash
cd infra

# Test 1: Verify a ticket (uses ClickUp mock + Memory)
python3 scripts/test_agent.py "Verify ticket CU-12345"

# Test 2: Ask about related verified tickets (uses Memory)
python3 scripts/test_agent.py "What related tickets for payment-service were verified before?" "demo-001"

# Test 3: Search tasks (uses ClickUp mock search)
python3 scripts/test_agent.py "Search for tickets about notification" "demo-002"

# Test 4: Follow-up in same session (uses session context)
python3 scripts/test_agent.py "What are the main risks?" "demo-001"

# Test 5: Verify a different ticket
python3 scripts/test_agent.py "Verify ticket CU-12500" "demo-003"
```

### Available Mock Tickets

| Ticket ID | Title | Status |
|---|---|---|
| CU-12345 | Add retry logic to payment service | in review |
| CU-12340 | Fix timeout configuration in payment service | closed |
| CU-12288 | Add health check endpoint to payment service | closed |
| CU-12500 | Implement user notification preferences API | in progress |

### Seed Memory (if table is empty)

```bash
python3 scripts/seed_memory.py
```

## Project Structure

```
infra/
├── README.md                          # This file
├── PLAN.md                            # Infrastructure planning document
├── DEMO-SPEC.md                       # Demo specification and script
├── main.tf                            # All Terraform resources
├── variables.tf                       # Input variables
├── outputs.tf                         # Outputs (IDs, commands)
├── terraform.tfvars                   # Active config (gitignored)
├── terraform.tfvars.example           # Template for credentials
├── .gitignore                         # Protects secrets and state
├── schemas/
│   ├── clickup-api-schema.json        # OpenAPI schema for ClickUp actions
│   └── memory-api-schema.json         # OpenAPI schema for Memory actions
├── lambda/
│   ├── clickup-handler/
│   │   ├── handler.py                 # Mock ClickUp data (4 tickets + comments)
│   │   └── requirements.txt
│   └── memory-handler/
│       ├── handler.py                 # DynamoDB read/write + auto-seed
│       └── requirements.txt
├── sample-docs/                       # Documents uploaded to S3 for RAG
│   ├── payment-service-architecture.md
│   ├── error-handling-guidelines.md
│   ├── qa-verification-history.md
│   ├── deployment-runbook.md
│   └── project-overview.md
└── scripts/
    ├── test_agent.py                  # CLI tool to invoke the agent
    └── seed_memory.py                 # Seeds DynamoDB with sample data
```

## How It Works

```
1. User sends: "Verify ticket CU-12345"
        │
        ▼
2. Bedrock Agent (Nova Pro) receives query, plans actions
        │
        ├──► ClickUp Action Group (Lambda)
        │       └── Returns mock task: title, description, assignee, comments
        │
        ├──► Memory Action Group (Lambda)
        │       └── Queries DynamoDB for verification history
        │
        └──► (Knowledge Base - when ingestion enabled)
                └── RAG search over codebase docs
        │
        ▼
3. Agent synthesizes structured Verification Context:
   - Ticket Summary
   - Risk Assessment (HIGH/MEDIUM/LOW)
   - Suggested Test Areas
   - Previous Verification Memory
   - Confidence Score
```

## Cost (Demo/Dev Usage)

| Service | Estimated Monthly |
|---|---|
| Amazon Nova Pro (model) | ~$2-10 (token-based) |
| OpenSearch Serverless | ~$7-10 (min 0.5 OCU indexing + 0.5 OCU search) |
| Lambda | < $1 |
| DynamoDB (on-demand) | < $1 |
| S3 | < $1 |
| Secrets Manager | < $1 |
| **Total** | **~$12-25/month** |

## Redeploy / Modify

```bash
cd infra

# Re-init (if providers changed)
terraform init

# Preview changes
terraform plan

# Apply
terraform apply

# Upload new docs to KB
aws s3 sync ./sample-docs s3://verify-ticket-kb-documents-931990754082/documents/

# Re-sync Knowledge Base (when embedding model is enabled)
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id 4TWWLPJ2DT \
  --data-source-id 3VMV3T9KFS \
  --region ap-southeast-1
```

## Enable Knowledge Base (RAG)

To enable full RAG:
1. Go to AWS Console > Bedrock > Model Access
2. Request access for **Cohere Embed Multilingual v3** (requires Marketplace subscription)
3. Wait for approval (~minutes)
4. Re-run ingestion job (command above)

## Enable Claude (Better Reasoning)

To use Claude 3.5 Sonnet instead of Nova Pro:
1. Go to AWS Console > Bedrock > Model Access
2. Request access for **Anthropic Claude 3.5 Sonnet v2**
3. Update agent model:
   ```bash
   aws bedrock-agent update-agent \
     --agent-id LWET2O1MG6 \
     --agent-name "verify-ticket-verify-ticket" \
     --agent-resource-role-arn "arn:aws:iam::931990754082:role/verify-ticket-bedrock-agent-role" \
     --foundation-model "apac.anthropic.claude-3-5-sonnet-20241022-v2:0" \
     --idle-session-ttl-in-seconds 600 \
     --region ap-southeast-1
   aws bedrock-agent prepare-agent --agent-id LWET2O1MG6 --region ap-southeast-1
   aws bedrock-agent update-agent-alias --agent-id LWET2O1MG6 --agent-alias-id FUYHYJSTJQ --agent-alias-name live --region ap-southeast-1
   ```

## Cleanup

```bash
cd infra
terraform destroy
```

This will remove ALL resources. OpenSearch Serverless collection deletion may take a few minutes.
