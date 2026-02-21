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

locals {
  # Combined setup script: base init + git clone/update + entire.io + user script
  combined_setup = <<-SETUP
    #!/bin/bash
    set -e

    # --- Base init ---
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~ 2>/dev/null || true
      touch ~/.init_done
    fi

    # --- Git clone/update ---
    REPO_URL="${data.coder_parameter.repo_url.value}"
    PROJECT_DIR="${data.coder_parameter.project_dir.value}"
    if [ -n "$REPO_URL" ] && [ -n "$PROJECT_DIR" ]; then
      if [ ! -d "$PROJECT_DIR/.git" ]; then
        git clone "$REPO_URL" "$PROJECT_DIR"
      else
        cd "$PROJECT_DIR" && git pull --ff-only 2>/dev/null || true
      fi
    fi

    # --- entire.io CLI ---
    if ! command -v entire &> /dev/null; then
      curl -fsSL https://get.entire.io | sh 2>/dev/null || true
    fi
    if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
      cd "$PROJECT_DIR"
      entire enable --strategy manual-commit 2>/dev/null || true
    fi

    # --- Project-specific setup ---
    ${data.coder_parameter.setup_script.value}
  SETUP
}

resource "coder_agent" "main" {
  arch = var.arch
  os   = "linux"
  dir  = data.coder_parameter.project_dir.value

  metadata {
    display_name = "CPU Usage"
    key          = "cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "home_disk"
    script       = "coder stat disk --path /home/coder"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Freq"
    key          = "cpu_freq"
    script       = "cat /proc/cpuinfo | awk '/cpu MHz/{printf \"%.1f GHz\", $4/1000}' | head -1"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average"
    key          = "load_average"
    script       = "cat /proc/loadavg | awk '{print $1, $2, $3}'"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Swap Usage"
    key          = "swap_usage"
    script       = "free -h | awk '/Swap/{printf \"%s / %s\", $3, $2}'"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Processes"
    key          = "processes"
    script       = "ps aux | wc -l"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Uptime"
    key          = "uptime"
    script       = "uptime -p | sed 's/up //'"
    interval     = 60
    timeout      = 1
  }

  startup_script = local.combined_setup
}

resource "docker_volume" "home_volume" {
  name = "coder-${var.workspace_id}-home"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_container" "workspace" {
  count = var.workspace_start_count
  image = data.coder_parameter.container_image.value
  name  = "coder-${var.owner_name}-${var.workspace_name}"
  hostname = var.workspace_name

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = var.owner_name
  }
  labels {
    label = "coder.owner_id"
    value = var.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = var.workspace_id
  }
  labels {
    label = "coder.workspace_name"
    value = var.workspace_name
  }
}
