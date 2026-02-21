data "coder_parameter" "repo_url" {
  name         = "repo_url"
  display_name = "Repository URL"
  description  = "Git repository URL to clone"
  type         = "string"
  form_type    = "input"
  mutable      = false
  default_value = ""
}

data "coder_parameter" "project_dir" {
  name         = "project_dir"
  display_name = "Project Directory"
  description  = "Clone destination path inside the container"
  type         = "string"
  form_type    = "input"
  mutable      = false
  default_value = "/home/coder/project"
}

data "coder_parameter" "setup_script" {
  name         = "setup_script"
  display_name = "Setup Script"
  description  = "Project-specific setup script (runs after base init)"
  type         = "string"
  form_type    = "textarea"
  mutable      = false
  required     = true
  default_value = ""
}

data "coder_parameter" "system_prompt" {
  name         = "system_prompt"
  display_name = "System Prompt"
  description  = "AI system prompt for Claude Code"
  type         = "string"
  form_type    = "textarea"
  mutable      = false
  required     = true
  default_value = ""
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "The port the web app is running on to preview"
  type         = "number"
  form_type    = "input"
  mutable      = false
  default_value = "4000"
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  description  = "Docker image for the workspace"
  type         = "string"
  form_type    = "input"
  mutable      = false
  default_value = "codercom/enterprise-base:ubuntu"
}
