terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "demo"
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Data sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# S3 Bucket for Knowledge Base documents
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "kb_documents" {
  bucket = "${var.project_name}-kb-documents-${data.aws_caller_identity.current.account_id}"

  force_destroy = true # Demo only - allows terraform destroy to clean up
}

resource "aws_s3_bucket_versioning" "kb_documents" {
  bucket = aws_s3_bucket.kb_documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kb_documents" {
  bucket = aws_s3_bucket.kb_documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "kb_documents" {
  bucket = aws_s3_bucket.kb_documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# Secrets Manager - ClickUp API Token
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "clickup_token" {
  name                    = "${var.project_name}/clickup-api-token"
  description             = "ClickUp Personal API Token for Verify Ticket Agent"
  recovery_window_in_days = 0 # Demo only - immediate delete on destroy
}

resource "aws_secretsmanager_secret_version" "clickup_token" {
  secret_id     = aws_secretsmanager_secret.clickup_token.id
  secret_string = var.clickup_api_token
}

# -----------------------------------------------------------------------------
# DynamoDB - Verification Memory
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "verification_memory" {
  name         = "${var.project_name}-verification-memory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ticket_id"
  range_key    = "timestamp"

  attribute {
    name = "ticket_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "service_name"
    type = "S"
  }

  global_secondary_index {
    name            = "service-index"
    hash_key        = "service_name"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

# -----------------------------------------------------------------------------
# IAM Role - Bedrock Agent
# -----------------------------------------------------------------------------

resource "aws_iam_role" "bedrock_agent" {
  name = "${var.project_name}-bedrock-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_agent_model" {
  name = "bedrock-model-invoke"
  role = aws_iam_role.bedrock_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_agent_kb" {
  name = "bedrock-kb-retrieve"
  role = aws_iam_role.bedrock_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Role - Knowledge Base
# -----------------------------------------------------------------------------

resource "aws_iam_role" "knowledge_base" {
  name = "${var.project_name}-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "kb_s3_access" {
  name = "kb-s3-access"
  role = aws_iam_role.knowledge_base.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.kb_documents.arn,
          "${aws_s3_bucket.kb_documents.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "kb_model_access" {
  name = "kb-embedding-model"
  role = aws_iam_role.knowledge_base.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "bedrock:InvokeModel"
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/cohere.embed-multilingual-v3"
      }
    ]
  })
}

resource "aws_iam_role_policy" "kb_opensearch_access" {
  name = "kb-opensearch-access"
  role = aws_iam_role.knowledge_base.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "aoss:APIAccessAll"
        Resource = aws_opensearchserverless_collection.kb_vector_store.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Role - Lambda (Action Groups)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda_action_group" {
  name = "${var.project_name}-lambda-action-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_action_group.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "lambda-secrets-access"
  role = aws_iam_role.lambda_action_group.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.clickup_token.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda-dynamodb-access"
  role = aws_iam_role.lambda_action_group.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.verification_memory.arn,
          "${aws_dynamodb_table.verification_memory.arn}/index/*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# OpenSearch Serverless - Vector Store for Knowledge Base
# -----------------------------------------------------------------------------

resource "aws_opensearchserverless_security_policy" "kb_encryption" {
  name = "${var.project_name}-kb-enc"
  type = "encryption"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.project_name}-kb-vectors"]
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "kb_network" {
  name = "${var.project_name}-kb-net"
  type = "network"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.project_name}-kb-vectors"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${var.project_name}-kb-vectors"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "kb_data_access" {
  name = "${var.project_name}-kb-access"
  type = "data"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${var.project_name}-kb-vectors/*"]
          Permission   = ["aoss:CreateIndex", "aoss:UpdateIndex", "aoss:DescribeIndex", "aoss:ReadDocument", "aoss:WriteDocument"]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.project_name}-kb-vectors"]
          Permission   = ["aoss:CreateCollectionItems", "aoss:DescribeCollectionItems", "aoss:UpdateCollectionItems"]
        }
      ]
      Principal = [
        aws_iam_role.knowledge_base.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  ])
}

resource "aws_opensearchserverless_collection" "kb_vector_store" {
  name = "${var.project_name}-kb-vectors"
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.kb_encryption,
    aws_opensearchserverless_security_policy.kb_network,
    aws_opensearchserverless_access_policy.kb_data_access,
  ]
}

# -----------------------------------------------------------------------------
# Bedrock Knowledge Base
# -----------------------------------------------------------------------------

resource "aws_bedrockagent_knowledge_base" "codebase_docs" {
  name     = "${var.project_name}-codebase-docs"
  role_arn = aws_iam_role.knowledge_base.arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/cohere.embed-multilingual-v3"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"

    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.kb_vector_store.arn
      vector_index_name = "bedrock-kb-default-index"

      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "codebase_s3" {
  name                 = "codebase-documents"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.codebase_docs.id
  data_deletion_policy = "DELETE"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn = aws_s3_bucket.kb_documents.arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"

      fixed_size_chunking_configuration {
        max_tokens         = 512
        overlap_percentage = 20
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Lambda - ClickUp Handler
# -----------------------------------------------------------------------------

data "archive_file" "clickup_handler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/clickup-handler"
  output_path = "${path.module}/.build/clickup-handler.zip"
}

resource "aws_lambda_function" "clickup_handler" {
  function_name    = "${var.project_name}-clickup-handler"
  role             = aws_iam_role.lambda_action_group.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.clickup_handler.output_path
  source_code_hash = data.archive_file.clickup_handler.output_base64sha256

  environment {
    variables = {
      MOCK_MODE          = "true"
      CLICKUP_SECRET_ARN = aws_secretsmanager_secret.clickup_token.arn
      CLICKUP_TEAM_ID    = var.clickup_team_id
    }
  }
}

resource "aws_lambda_permission" "clickup_bedrock" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.clickup_handler.function_name
  principal     = "bedrock.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# -----------------------------------------------------------------------------
# Lambda - Memory Handler
# -----------------------------------------------------------------------------

data "archive_file" "memory_handler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/memory-handler"
  output_path = "${path.module}/.build/memory-handler.zip"
}

resource "aws_lambda_function" "memory_handler" {
  function_name    = "${var.project_name}-memory-handler"
  role             = aws_iam_role.lambda_action_group.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.memory_handler.output_path
  source_code_hash = data.archive_file.memory_handler.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.verification_memory.name
    }
  }
}

resource "aws_lambda_permission" "memory_bedrock" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.memory_handler.function_name
  principal     = "bedrock.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# -----------------------------------------------------------------------------
# Bedrock Agent
# -----------------------------------------------------------------------------

resource "aws_bedrockagent_agent" "verify_ticket" {
  agent_name              = "${var.project_name}-verify-ticket"
  agent_resource_role_arn = aws_iam_role.bedrock_agent.arn
  foundation_model        = var.bedrock_model_id
  idle_session_ttl_in_seconds = 600

  instruction = <<-EOT
    You are a QA verification assistant called "Verify Ticket Agent".

    When a user provides a ticket ID (e.g., "Verify ticket CU-12345"):
    1. Use the ClickUp action group to fetch the ticket details including title, description, status, assignee, and comments.
    2. Search the knowledge base for relevant codebase documentation, architecture notes, and historical context related to the ticket.
    3. Check the verification memory for any previous verification records related to this ticket or the affected service.
    4. Synthesize all information into a structured Verification Context Record.

    Your response MUST include these sections:
    - Ticket Summary: key fields from ClickUp
    - Relevant Codebase Context: findings from knowledge base with citations
    - Risk Assessment: HIGH/MEDIUM/LOW risks identified
    - Suggested Test Areas: specific things to verify
    - Previous Verification Memory: related past verifications
    - Confidence: how complete is the context

    Rules:
    - Always cite sources when referencing documents from the knowledge base.
    - If information is not found, explicitly state "Not found in knowledge base" rather than guessing.
    - Never auto-pass or auto-fail a ticket. You provide context, humans decide.
    - Flag ambiguities and missing information clearly.
    - Keep responses structured and scannable.
  EOT
}

resource "aws_bedrockagent_agent_action_group" "clickup" {
  action_group_name          = "ClickUpActions"
  agent_id                   = aws_bedrockagent_agent.verify_ticket.id
  agent_version              = "DRAFT"
  skip_resource_in_use_check = true

  action_group_executor {
    lambda = aws_lambda_function.clickup_handler.arn
  }

  api_schema {
    payload = file("${path.module}/schemas/clickup-api-schema.json")
  }
}

resource "aws_bedrockagent_agent_action_group" "memory" {
  action_group_name          = "MemoryActions"
  agent_id                   = aws_bedrockagent_agent.verify_ticket.id
  agent_version              = "DRAFT"
  skip_resource_in_use_check = true

  action_group_executor {
    lambda = aws_lambda_function.memory_handler.arn
  }

  api_schema {
    payload = file("${path.module}/schemas/memory-api-schema.json")
  }
}

resource "aws_bedrockagent_agent_knowledge_base_association" "codebase" {
  agent_id             = aws_bedrockagent_agent.verify_ticket.id
  knowledge_base_id    = aws_bedrockagent_knowledge_base.codebase_docs.id
  knowledge_base_state = "ENABLED"
  description          = "Codebase documentation, architecture docs, RFCs, and QA history for verification context"
}

# Prepare agent after all configurations
resource "aws_bedrockagent_agent_alias" "live" {
  agent_alias_name = "live"
  agent_id         = aws_bedrockagent_agent.verify_ticket.id
  description      = "Live alias for demo"
}
