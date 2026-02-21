terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.13"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "docker" {}

# --- Data Sources ---

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
data "coder_task" "me" {}

# --- Parameters ---

data "coder_parameter" "system_prompt" {
  name         = "system_prompt"
  display_name = "System Prompt"
  type         = "string"
  form_type    = "textarea"
  description  = "System prompt for the agent with generalized instructions"
  mutable      = false
}

data "coder_parameter" "setup_script" {
  name         = "setup_script"
  display_name = "Setup Script"
  type         = "string"
  form_type    = "textarea"
  description  = "Script to run before running the agent"
  mutable      = false
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  type         = "string"
  default      = "codercom/example-universal:ubuntu"
  mutable      = false
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "The port for preview (not typically used for template work)"
  type         = "number"
  default      = "8080"
  mutable      = false
}

# --- Preset ---

data "coder_workspace_preset" "default" {
  name    = "Template Creator"
  default = true
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are a Coder template engineer. You create, update, and deploy Coder workspace templates using Terraform and the Coder MCP tools. You have access to the coder-templates repo and can deploy directly to the Coder platform.

      -- What You Do --
      1. Create new Coder templates (Terraform .tf files) following the repo's two-layer architecture
      2. Update existing templates (modify presets, setup scripts, system prompts, infrastructure)
      3. Deploy templates to Coder by flattening module + template into a tar, uploading, and creating/updating template versions
      4. Manage workspaces: create, start, stop, delete workspaces from templates for testing

      -- Repo Architecture (coder-templates) --
      Two layers:
      - modules/dev-base/: shared infrastructure (agent, container, volume, IDEs, Claude Code, preview app)
      - templates/<name>/main.tf: each template has 4 parameters + 1 preset + module "dev-base" call

      Standard 4 parameters (MUST be in root template, not module):
      - system_prompt (string/textarea): Claude Code system prompt
      - setup_script (string/textarea): post-install script
      - container_image (string): Docker image
      - preview_port (number): preview app port

      -- Deployment Process --
      Coder tar upload doesn't support subdirectories. To deploy:
      1. Read all dev-base module files (main.tf, variables.tf, claude.tf, apps.tf, ide.tf, outputs.tf)
      2. Read the template's main.tf
      3. In the template main.tf, rewrite `source = "../../modules/dev-base"` to `source = "./"`
      4. Upload all files as a flat tar via coder_upload_tar_file
      5. Create a template version from the uploaded tar
      6. Check template version logs to verify successful import
      7. Either create a new template or update an existing template's active version

      -- MCP Tools Available --
      You have Coder MCP tools for:
      - coder_upload_tar_file: upload flattened template files
      - coder_create_template_version: create version from uploaded tar
      - coder_get_template_version_logs: verify import succeeded
      - coder_create_template: create new template
      - coder_update_template_active_version: update existing template
      - coder_create_workspace: test a template by creating a workspace
      - coder_create_workspace_build: start/stop/delete workspaces
      - coder_list_templates, coder_get_workspace, etc.

      -- Key Rules --
      - NEVER use "variable" or "output" blocks in template Terraform (use coder_parameter data sources instead)
      - Parameters MUST be in the root template (Coder validates presets before terraform init)
      - Always check template version logs after creation to verify import
      - Container user is "coder" (not root)
      - Setup scripts must be idempotent (safe to re-run)
      - One preset per template, set default = true

      -- Context --
      Read CLAUDE.md in the project root for full repo documentation.
      The coder-templates repo is cloned to /home/coder/projects/coder-templates.
    EOT

    "setup_script" = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_DIR="/home/coder/projects/coder-templates"
    REPO_URL="https://github.com/maximblack/coder-templates.git"

    # --- Clone or update repository ---
    mkdir -p /home/coder/projects
    if [ ! -d "$PROJECT_DIR/.git" ]; then
      rm -rf "$PROJECT_DIR"
      git clone "$REPO_URL" "$PROJECT_DIR"
    else
      cd "$PROJECT_DIR"
      git fetch
      if git diff-index --quiet HEAD -- && \
        [ -z "$(git status --porcelain --untracked-files=no)" ] && \
        [ -z "$(git log --branches --not --remotes)" ]; then
        echo "Repo is clean. Pulling latest changes..."
        git pull
      else
        echo "Repo has uncommitted or unpushed changes. Skipping pull."
      fi
    fi

    # --- Install Terraform ---
    if ! command -v terraform >/dev/null 2>&1; then
      echo "Installing Terraform..."
      sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
      wget -O- https://apt.releases.hashicorp.com/gpg | \
        gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update && sudo apt-get install -y terraform
    fi

    echo "========================================"
    echo "  Template Creator environment ready!"
    echo "  Terraform: $(terraform version -json | jq -r '.terraform_version')"
    echo "  Coder CLI: $(coder version 2>/dev/null || echo 'available via PATH')"
    echo "========================================"
    EOT

    "preview_port"    = "8080"
    "container_image" = "codercom/example-universal:ubuntu"
  }
}

# --- Module ---

module "dev-base" {
  source = "../../modules/dev-base"

  arch                  = data.coder_provisioner.me.arch
  workspace_id          = data.coder_workspace.me.id
  workspace_name        = data.coder_workspace.me.name
  workspace_start_count = data.coder_workspace.me.start_count
  owner_name            = data.coder_workspace_owner.me.name
  owner_id              = data.coder_workspace_owner.me.id
  owner_email           = data.coder_workspace_owner.me.email
  owner_full_name       = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  project_dir           = "/home/coder/projects/coder-templates"
  container_image       = data.coder_parameter.container_image.value
  setup_script          = data.coder_parameter.setup_script.value
  system_prompt         = data.coder_parameter.system_prompt.value
  ai_prompt             = data.coder_task.me.prompt
  preview_port          = data.coder_parameter.preview_port.value
  preview_display_name  = "Preview"
  preview_icon          = "${data.coder_workspace.me.access_url}/emojis/1f6e0.png"
}
