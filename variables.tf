variable "arch" {
  type        = string
  description = "Provisioner architecture (amd64, arm64)"
}

variable "workspace_id" {
  type        = string
  description = "Coder workspace ID"
}

variable "workspace_name" {
  type        = string
  description = "Coder workspace name"
}

variable "workspace_start_count" {
  type        = number
  description = "1 when workspace is starting, 0 when stopping"
}

variable "workspace_access_url" {
  type        = string
  description = "Coder access URL for IDE connections"
}

variable "owner_name" {
  type        = string
  description = "Workspace owner username"
}

variable "owner_id" {
  type        = string
  description = "Workspace owner UUID"
}

variable "owner_email" {
  type        = string
  description = "Workspace owner email"
}

variable "owner_full_name" {
  type        = string
  description = "Workspace owner display name"
}

variable "oauth_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Claude Code OAuth token"
}

variable "ai_prompt" {
  type        = string
  default     = ""
  description = "AI task prompt from coder_task"
}
