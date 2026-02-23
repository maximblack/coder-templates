terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

# --- Agent ---

resource "coder_agent" "main" {
  arch           = var.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi
    # Install Entire.io (AI session capture)
    if ! command -v entire >/dev/null 2>&1; then
      curl -fsSL https://entire.io/install.sh | bash
      grep -q '/.local/bin' ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
  EOT

  env = merge({
    GIT_AUTHOR_NAME     = coalesce(var.owner_full_name, var.owner_name)
    GIT_AUTHOR_EMAIL    = var.owner_email
    GIT_COMMITTER_NAME  = coalesce(var.owner_full_name, var.owner_name)
    GIT_COMMITTER_EMAIL = var.owner_email
  }, var.agent_env)

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    script       = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%%0.2f", $1/$2 }'
    EOT
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

# --- Docker Volume ---

resource "docker_volume" "home_volume" {
  name = "coder-${var.workspace_id}-home"
  lifecycle {
    ignore_changes = all
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
    label = "coder.workspace_name_at_creation"
    value = var.workspace_name
  }
}

# --- Docker Container ---

resource "docker_container" "workspace" {
  count    = var.workspace_start_count
  image    = var.container_image
  name     = "coder-${var.owner_name}-${lower(var.workspace_name)}"
  hostname = var.workspace_name
  user     = "coder"
  runtime  = var.docker_runtime != "" ? var.docker_runtime : null
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\\\.0\\\\.0\\\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  # SCTP N2 interface — expose to host for external gNB connections
  dynamic "ports" {
    for_each = var.sctp_port > 0 ? [var.sctp_port] : []
    content {
      internal = ports.value
      external = ports.value
      protocol = "sctp"
    }
  }
  # TCP ports — expose to host (e.g. Phoenix 4000 for metrics scraping)
  dynamic "ports" {
    for_each = var.tcp_ports
    content {
      internal = ports.value
      external = ports.value
      protocol = "tcp"
    }
  }
  # UDP ports — expose to host (e.g. PFCP 8805, GTP-U 2152)
  dynamic "ports" {
    for_each = var.udp_ports
    content {
      internal = ports.value
      external = ports.value
      protocol = "udp"
    }
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
