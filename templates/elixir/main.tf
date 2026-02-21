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
  description  = "The port the web app is running on to preview"
  type         = "number"
  default      = "4000"
  mutable      = false
}

# --- Preset ---

data "coder_workspace_preset" "default" {
  name    = "Pente 5G Core"
  default = true
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are a helpful assistant for Elixir/OTP development. You are working on Pente, a 5G core network implementation in Elixir with Phoenix LiveView. Stay on track, debug thoroughly, and don't change architecture without checking the user first.

      -- Tech Stack --
      - Elixir 1.19.5 / OTP 28 with Phoenix 1.8.3 + LiveView + DaisyUI
      - Mnesia for all persistent data, ETS for hot-path caching
      - Go codec (native/goport/) for NGAP/NAS/PFCP encoding/decoding
      - Rust UPF (pente-upf/) for user plane forwarding
      - SCTP for N2 interface (gNB communication)

      -- Tool Selection --
      - Built-in tools for file operations, git, builds, one-off commands
      - Use `mix test` to run tests, `mix phx.server` to start the dev server
      - Use `cd native/goport && make` to rebuild the Go codec
      - Preview app runs on port 4000

      -- Context --
      Read CLAUDE.md in the project root for detailed architecture notes.
      The project uses TDD - write tests first, then implement.
      Phoenix dev server runs on port 4000.
    EOT

    "setup_script" = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_DIR="/home/coder/projects/pente-elixir"
    REPO_URL="https://github.com/maximblack/max-core.git"

    # --- System Dependencies ---
    if ! dpkg -l | grep -q lksctp-tools 2>/dev/null; then
      sudo apt-get update && sudo apt-get install -y \
        build-essential git curl wget ca-certificates \
        lksctp-tools inotify-tools \
        autoconf libncurses-dev libssl-dev \
        unzip
    fi

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

    # --- Install mise (version manager) ---
    if ! command -v mise >/dev/null 2>&1; then
      curl https://mise.run | sh
    fi
    export PATH="$HOME/.local/bin:$PATH"
    grep -q '.local/bin' ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    eval "$(mise activate bash)"
    grep -q 'mise activate' ~/.bashrc 2>/dev/null || echo 'eval "$(mise activate bash)"' >> ~/.bashrc

    # --- Install Erlang + Elixir via mise ---
    export KERL_BUILD_DOCS=no
    export KERL_CONFIGURE_OPTIONS="--without-javac --without-wx --without-debugger --without-observer --without-et"

    if ! mise list erlang 2>/dev/null | grep -q 28; then
      echo "Installing Erlang OTP 28 (this may take a while on first run)..."
      mise install erlang@28.0
    fi
    mise use -g erlang@28.0

    if ! mise list elixir 2>/dev/null | grep -q 1.19.5; then
      mise install elixir@1.19.5-otp-28
    fi
    mise use -g elixir@1.19.5-otp-28

    # --- Install Go 1.25.5 (if not the right version) ---
    WANT_GO="go1.25.5"
    if ! go version 2>/dev/null | grep -q "$WANT_GO"; then
      wget -q https://go.dev/dl/go1.25.5.linux-amd64.tar.gz -O /tmp/go.tar.gz
      sudo rm -rf /usr/local/go
      sudo tar -C /usr/local -xzf /tmp/go.tar.gz
      rm /tmp/go.tar.gz
    fi
    export PATH=/usr/local/go/bin:$PATH
    grep -q '/usr/local/go/bin' ~/.bashrc 2>/dev/null || echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc

    # --- Bootstrap Elixir Project ---
    cd "$PROJECT_DIR"

    mix local.hex --force
    mix local.rebar --force
    mix deps.get
    mix compile

    # Build Go codec
    cd native/goport && make && cd ../..

    # Setup assets
    mix assets.setup 2>/dev/null || true
    mix assets.build 2>/dev/null || true

    echo "========================================"
    echo "  Pente dev environment ready!"
    echo "  Starting Phoenix dev server..."
    echo "========================================"

    # Start Phoenix dev server in background
    cd "$PROJECT_DIR"
    mix phx.server > /tmp/phoenix.log 2>&1 &
    EOT

    "preview_port"    = "4000"
    "container_image" = "codercom/example-universal:ubuntu"
  }
}

# --- Sensitive Variables (injected via TF_VAR_*) ---

variable "claude_code_oauth_token" {
  type        = string
  description = "OAuth token for Claude Code (set via TF_VAR_claude_code_oauth_token)"
  sensitive   = true
  default     = ""
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
  project_dir           = "/home/coder/projects/pente-elixir"
  container_image       = data.coder_parameter.container_image.value
  setup_script          = data.coder_parameter.setup_script.value
  system_prompt         = data.coder_parameter.system_prompt.value
  ai_prompt             = data.coder_task.me.prompt
  preview_port          = data.coder_parameter.preview_port.value
  preview_display_name  = "Phoenix LiveView"
  preview_icon          = "${data.coder_workspace.me.access_url}/emojis/1f525.png"
  oauth_token           = var.claude_code_oauth_token
}
