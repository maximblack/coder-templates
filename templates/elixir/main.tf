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

    # --- Start Docker daemon (sysbox-runc provides DinD) ---
    if ! docker ps >/dev/null 2>&1; then
      echo "Starting Docker daemon (sysbox DinD)..."
      sudo rm -f /var/run/docker.pid
      sudo dockerd > /tmp/dockerd.log 2>&1 &
      for i in $(seq 1 30); do
        docker ps >/dev/null 2>&1 && break
        sleep 1
      done
      docker ps >/dev/null 2>&1 && echo "Docker is ready." || echo "Warning: Docker daemon did not start. Check /tmp/dockerd.log"
    else
      echo "Docker daemon already running."
    fi

    # --- System Dependencies ---
    if ! dpkg -l | grep -q libsctp-dev 2>/dev/null; then
      sudo apt-get update && sudo apt-get install -y \
        build-essential git curl wget ca-certificates \
        lksctp-tools libsctp-dev inotify-tools \
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
    # MISE_ERLANG_COMPILE=1 forces source build (needed for SCTP support via libsctp-dev)
    export MISE_ERLANG_COMPILE=1
    export KERL_BUILD_DOCS=no
    export KERL_CONFIGURE_OPTIONS="--without-javac --without-wx --without-debugger --without-observer --without-et --enable-sctp"

    if ! mise list erlang 2>/dev/null | grep -q 28; then
      echo "Installing Erlang OTP 28 from source (this may take a while on first run)..."
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

    # Start Phoenix dev server with SCTP enabled (N2 interface for gNB connections)
    cd "$PROJECT_DIR"
    N2_ADDRESS=0.0.0.0 N2_PORT=38412 mix phx.server > /tmp/phoenix.log 2>&1 &

    # Wait for Phoenix to be ready, then seed test data
    echo "Waiting for Phoenix to start..."
    for i in $(seq 1 60); do
      curl -sf http://localhost:4000/ >/dev/null 2>&1 && break
      sleep 1
    done
    cd "$PROJECT_DIR" && mix run priv/repo/seeds.exs 2>&1 | tee /tmp/seeds.log

    # --- UERANSIM gNB auto-start (requires Docker-in-Docker) ---
    if docker ps >/dev/null 2>&1; then
      echo "Pre-pulling UERANSIM image..."
      docker pull free5gc/ueransim:latest 2>/dev/null &
      PULL_PID=$!

      # Create workspace gNB config (host networking — connects to localhost SCTP)
      mkdir -p /tmp/ueransim
      cat > /tmp/ueransim/gnb.yaml <<'GNBEOF'
mcc: '001'
mnc: '01'
nci: '0x000000010'
idLength: 32
tac: 1
linkIp: 0.0.0.0
ngapIp: 127.0.0.1
amfConfigs:
  - address: 127.0.0.1
    port: 38412
gtpIp: 127.0.0.1
slices:
  - sst: 1
    sd: '000001'
ignoreStreamIds: true
GNBEOF

      # Wait for image pull and Phoenix SCTP to be ready
      wait $PULL_PID
      echo "Waiting for SCTP listener..."
      for i in $(seq 1 30); do
        grep -q 38412 /proc/net/sctp/eps 2>/dev/null && break
        sleep 1
      done

      # Start gNB with host networking so it reaches SCTP on localhost
      docker run -d --name ueransim-gnb --network host \
        -v /tmp/ueransim/gnb.yaml:/etc/ueransim/gnb.yaml:ro \
        free5gc/ueransim:latest \
        /ueransim/nr-gnb -c /etc/ueransim/gnb.yaml \
        && echo "UERANSIM gNB started (auto-registering with AMF)." \
        || echo "Warning: UERANSIM gNB failed to start."
    fi
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
  docker_runtime        = "sysbox-runc"
  sctp_port             = 38412
}
