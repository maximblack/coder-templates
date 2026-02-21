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
  description  = "The port for game preview (noVNC)"
  type         = "number"
  default      = "6080"
  mutable      = false
}

# --- Preset ---

data "coder_workspace_preset" "default" {
  name    = "Godot 4.x Game"
  default = true
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are a helpful assistant for Godot 4.x game development. You work with GDScript, scene trees, resources, and the Godot engine CLI. Stay focused on the game project, debug thoroughly, and don't change architecture without checking the user first.

      -- Tech Stack --
      - Godot 4.4.1 (headless mode for CLI operations)
      - GDScript as the primary scripting language
      - Scene tree architecture with nodes and resources
      - .tscn (text scene) and .tres (text resource) file formats

      -- Tool Selection --
      - Built-in tools for file operations, git, one-off commands
      - Use `godot --headless --script res://path/to/script.gd` to run scripts
      - Use `godot --headless --export-release` for builds
      - Use `godot --headless --import` to reimport assets

      -- Conventions --
      - Scenes: one root node per scene, descriptive node names
      - Scripts: attach to nodes, use signal-based communication
      - Resources: .tres for data, .tscn for scenes
      - Folders: res://scenes/, res://scripts/, res://assets/, res://autoload/
      - Follow GDScript style guide: snake_case for functions/variables, PascalCase for classes
      - Read CLAUDE.md or README.md in the project root for project-specific notes.
    EOT

    "setup_script" = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_DIR="/home/coder/projects/game"
    REPO_URL="$${REPO_URL:-}"
    GODOT_VERSION="4.4.1"
    GODOT_RELEASE="stable"

    # --- Clone or update repository ---
    mkdir -p /home/coder/projects
    if [ -n "$REPO_URL" ]; then
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
    else
      mkdir -p "$PROJECT_DIR"
    fi

    # --- Install Godot headless ---
    GODOT_BIN="/usr/local/bin/godot"
    if ! "$GODOT_BIN" --version 2>/dev/null | grep -q "$GODOT_VERSION"; then
      echo "Installing Godot $GODOT_VERSION headless..."
      GODOT_URL="https://github.com/godotengine/godot/releases/download/$GODOT_VERSION-$GODOT_RELEASE/Godot_v$GODOT_VERSION-${GODOT_RELEASE}_linux.x86_64.zip"
      wget -q "$GODOT_URL" -O /tmp/godot.zip
      sudo unzip -o /tmp/godot.zip -d /usr/local/bin/
      sudo mv "/usr/local/bin/Godot_v$GODOT_VERSION-${GODOT_RELEASE}_linux.x86_64" "$GODOT_BIN"
      sudo chmod +x "$GODOT_BIN"
      rm /tmp/godot.zip
    fi

    # --- Import project assets ---
    cd "$PROJECT_DIR"
    if [ -f "project.godot" ]; then
      echo "Importing Godot project assets..."
      godot --headless --import 2>/dev/null || true
    fi

    echo "========================================"
    echo "  Godot $GODOT_VERSION dev environment ready!"
    echo "========================================"
    EOT

    "preview_port"    = "6080"
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
  project_dir           = "/home/coder/projects/game"
  container_image       = data.coder_parameter.container_image.value
  setup_script          = data.coder_parameter.setup_script.value
  system_prompt         = data.coder_parameter.system_prompt.value
  ai_prompt             = data.coder_task.me.prompt
  preview_port          = data.coder_parameter.preview_port.value
  preview_display_name  = "Game Preview"
  preview_icon          = "${data.coder_workspace.me.access_url}/emojis/1f3ae.png"
}
