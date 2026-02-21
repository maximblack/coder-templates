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
  combined_setup = <<-SETUP
    #!/bin/bash
    set -e

    # Base init
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~ 2>/dev/null || true
      touch ~/.init_done
    fi

    # Git clone/update
    if [ -n "${var.repo_url}" ] && [ -n "${var.project_dir}" ]; then
      if [ ! -d "${var.project_dir}/.git" ]; then
        git clone "${var.repo_url}" "${var.project_dir}"
      else
        cd "${var.project_dir}" && git pull --ff-only 2>/dev/null || true
      fi
    fi

    # entire.io CLI
    if ! command -v entire &> /dev/null; then
      curl -fsSL https://get.entire.io | sh 2>/dev/null || true
    fi
    if [ -n "${var.project_dir}" ] && [ -d "${var.project_dir}" ]; then
      cd "${var.project_dir}"
      entire enable --strategy manual-commit 2>/dev/null || true
    fi

    # Project-specific setup
    ${var.setup_script}
  SETUP
}

resource "coder_agent" "main" {
  arch = var.arch
  os   = "linux"
  dir  = var.project_dir

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
  count    = var.workspace_start_count
  image    = var.container_image
  name     = "coder-${var.owner_name}-${var.workspace_name}"
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
