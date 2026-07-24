# Terraform Infrastructure Plan - AWS Bedrock Agent MVP

Status: Draft  
Date: 2026-07-24  
Scope: Minimal viable Bedrock Agent setup for "Verify Ticket" demo

## 1. Muc tieu

Setup ha tang AWS toi thieu de demo mot Bedrock Agent co kha nang:
- Nhan ticket context tu ClickUp
- Truy van Knowledge Base (RAG) tu codebase/document history
- Giu memory qua cac session
- Tra ve Verification Context cho QA

## 2. AWS Services can thiet (MVP)

| Service | Muc dich | Terraform resource |
|---|---|---|
| Amazon Bedrock | Model inference (Claude 3.5 Sonnet/Haiku) | `aws_bedrock_model_invocation_logging_configuration` |
| Bedrock Agent | Agent orchestration, tool use | `aws_bedrockagent_agent`, `aws_bedrockagent_agent_alias` |
| Bedrock Knowledge Base | RAG cho codebase docs + history | `aws_bedrockagent_knowledge_base`, `aws_bedrockagent_data_source` |
| S3 | Luu tru documents cho Knowledge Base | `aws_s3_bucket` |
| OpenSearch Serverless | Vector store cho Knowledge Base | `aws_opensearchserverless_collection` |
| Lambda | Action group handler (ClickUp API, custom logic) | `aws_lambda_function` |
| IAM | Roles va policies | `aws_iam_role`, `aws_iam_policy` |
| DynamoDB | Session memory / conversation history | `aws_dynamodb_table` |
| Secrets Manager | ClickUp API token, credentials | `aws_secretsmanager_secret` |

## 3. Architecture Overview

```
User/QA
    |
    v
[Bedrock Agent] <-- Instruction + Action Groups
    |
    |--- [Knowledge Base] --- [S3 docs] + [OpenSearch Serverless vector store]
    |
    |--- [Action Group: ClickUp] --- [Lambda] --- ClickUp API
    |
    |--- [Action Group: Memory] --- [Lambda] --- DynamoDB (conversation history)
    |
    v
Verification Context Response
```

## 4. Terraform Module Structure

```
infra/
├── PLAN.md                    # This file
├── main.tf                    # Provider, backend config
├── variables.tf               # Input variables
├── outputs.tf                 # Outputs (agent ID, KB ID, endpoints)
├── modules/
│   ├── bedrock-agent/         # Agent + alias + instruction
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── knowledge-base/        # KB + S3 + OpenSearch Serverless
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── action-groups/         # Lambda functions for ClickUp + Memory
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/                   # All IAM roles and policies
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── lambda/
│   ├── clickup-handler/       # Python Lambda cho ClickUp integration
│   │   ├── handler.py
│   │   └── requirements.txt
│   └── memory-handler/        # Python Lambda cho memory/DynamoDB
│       ├── handler.py
│       └── requirements.txt
└── terraform.tfvars.example   # Example variables (KHONG commit secrets)
```

## 5. Prerequisites

- AWS Account voi Bedrock model access da enable (us-east-1 hoac us-west-2)
- Terraform >= 1.5
- AWS CLI configured voi Access Key + Secret Key
- ClickUp API token (Personal token hoac OAuth)
- Python 3.11+ (cho Lambda build)

## 6. Variables can cung cap

| Variable | Description | Sensitive |
|---|---|---|
| `aws_access_key` | AWS Access Key ID | Yes |
| `aws_secret_key` | AWS Secret Access Key | Yes |
| `aws_region` | Region (default: us-east-1) | No |
| `clickup_api_token` | ClickUp Personal API Token | Yes |
| `clickup_team_id` | ClickUp Team/Workspace ID | No |
| `project_name` | Ten project (prefix cho resources) | No |
| `bedrock_model_id` | Model ID (default: anthropic.claude-3-5-sonnet-20241022-v2:0) | No |

## 7. Deployment Steps

```bash
# 1. Init
cd infra
terraform init

# 2. Cau hinh credentials
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars voi AWS keys va ClickUp token

# 3. Plan
terraform plan

# 4. Apply
terraform apply

# 5. Upload documents vao S3 cho Knowledge Base
aws s3 sync ./docs s3://<kb-bucket-name>/documents/

# 6. Sync Knowledge Base data source
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id <kb-id> \
  --data-source-id <ds-id>

# 7. Test Agent
aws bedrock-agent-runtime invoke-agent \
  --agent-id <agent-id> \
  --agent-alias-id <alias-id> \
  --session-id "demo-session-001" \
  --input-text "Verify ticket CU-abc123"
```

## 8. Cost Estimate (Demo/Dev)

| Service | Estimated monthly (low usage) |
|---|---|
| Bedrock (Claude 3.5 Sonnet) | ~$5-20 (depends on token volume) |
| OpenSearch Serverless | ~$7-10 (minimum 0.5 OCU) |
| S3 | < $1 |
| Lambda | < $1 |
| DynamoDB (on-demand) | < $1 |
| Secrets Manager | < $1 |
| **Total estimate** | **~$15-35/month** |

## 9. Security Notes

- KHONG commit terraform.tfvars hoac bat ky file chua credentials
- Su dung Secrets Manager cho ClickUp API token
- IAM roles dung least-privilege principle
- S3 bucket private, khong public access
- OpenSearch Serverless co encryption at rest va network policy

## 10. Cleanup

```bash
terraform destroy
```
