# --- Required Variables ---

variable "arch" {
  type        = string
  description = "Architecture of the provisioner (amd64 or arm64)"
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

variable "owner_name" {
  type        = string
  description = "Workspace owner username"
}

variable "owner_id" {
  type        = string
  description = "Workspace owner ID"
}

variable "owner_email" {
  type        = string
  description = "Workspace owner email"
}

variable "owner_full_name" {
  type        = string
  description = "Workspace owner full name"
}

variable "project_dir" {
  type        = string
  description = "Working directory for IDEs and Claude Code"
}

variable "container_image" {
  type        = string
  description = "Docker image for the workspace container"
}

variable "setup_script" {
  type        = string
  description = "Script to run as post_install_script in Claude Code module"
}

variable "system_prompt" {
  type        = string
  description = "System prompt for Claude Code"
}

variable "ai_prompt" {
  type        = string
  description = "AI task prompt from coder_task"
}

# --- Optional Variables ---

variable "oauth_token" {
  type        = string
  description = "OAuth token for Claude Code"
  sensitive   = true
  default     = ""
}

variable "preview_port" {
  type        = number
  description = "Port for the preview app"
  default     = 4000
}

variable "preview_display_name" {
  type        = string
  description = "Display name for the preview app"
  default     = "Preview"
}

variable "preview_icon" {
  type        = string
  description = "Icon URL for the preview app"
  default     = ""
}

variable "mcp" {
  type        = string
  description = "MCP configuration JSON for Claude Code (from playwright-mcp or custom)"
  default     = ""
}

variable "docker_runtime" {
  type        = string
  description = "Docker runtime for the workspace container (e.g. sysbox-runc for Docker-in-Docker)"
  default     = ""
}

variable "sctp_port" {
  type        = number
  description = "SCTP port to expose from container to host (0 = disabled)"
  default     = 0
}

variable "udp_ports" {
  type        = list(number)
  description = "UDP ports to expose from container to host (e.g. [8805] for PFCP)"
  default     = []
}

variable "agent_env" {
  type        = map(string)
  description = "Additional environment variables for the workspace agent"
  default     = {}
}
