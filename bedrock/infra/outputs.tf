# -----------------------------------------------------------------------------
# Outputs - used for testing and demo
# -----------------------------------------------------------------------------

output "agent_id" {
  description = "Bedrock Agent ID"
  value       = aws_bedrockagent_agent.verify_ticket.id
}

output "agent_alias_id" {
  description = "Bedrock Agent Alias ID (live)"
  value       = aws_bedrockagent_agent_alias.live.agent_alias_id
}

output "knowledge_base_id" {
  description = "Knowledge Base ID"
  value       = aws_bedrockagent_knowledge_base.codebase_docs.id
}

output "data_source_id" {
  description = "Knowledge Base Data Source ID"
  value       = aws_bedrockagent_data_source.codebase_s3.data_source_id
}

output "kb_bucket_name" {
  description = "S3 bucket name for KB documents"
  value       = aws_s3_bucket.kb_documents.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for verification memory"
  value       = aws_dynamodb_table.verification_memory.name
}

output "clickup_lambda_arn" {
  description = "ClickUp handler Lambda ARN"
  value       = aws_lambda_function.clickup_handler.arn
}

output "memory_lambda_arn" {
  description = "Memory handler Lambda ARN"
  value       = aws_lambda_function.memory_handler.arn
}

output "opensearch_collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint"
  value       = aws_opensearchserverless_collection.kb_vector_store.collection_endpoint
}

# -----------------------------------------------------------------------------
# Quick-start commands
# -----------------------------------------------------------------------------

output "invoke_command" {
  description = "AWS CLI command to invoke the agent"
  value       = <<-EOT
    aws bedrock-agent-runtime invoke-agent \
      --agent-id ${aws_bedrockagent_agent.verify_ticket.id} \
      --agent-alias-id ${aws_bedrockagent_agent_alias.live.agent_alias_id} \
      --session-id "demo-001" \
      --input-text "Verify ticket CU-12345" \
      --region ${var.aws_region}
  EOT
}

output "sync_kb_command" {
  description = "AWS CLI command to sync Knowledge Base"
  value       = <<-EOT
    aws bedrock-agent start-ingestion-job \
      --knowledge-base-id ${aws_bedrockagent_knowledge_base.codebase_docs.id} \
      --data-source-id ${aws_bedrockagent_data_source.codebase_s3.data_source_id} \
      --region ${var.aws_region}
  EOT
}
