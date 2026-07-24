# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "default"
}

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "verify-ticket"
}

variable "bedrock_model_id" {
  description = "Bedrock foundation model ID for the agent"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

# -----------------------------------------------------------------------------
# ClickUp Integration
# -----------------------------------------------------------------------------

variable "clickup_api_token" {
  description = "ClickUp Personal API Token"
  type        = string
  sensitive   = true
}

variable "clickup_team_id" {
  description = "ClickUp Team/Workspace ID"
  type        = string
  default     = ""
}
