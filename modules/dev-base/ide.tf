# --- code-server ---

module "code-server" {
  count    = var.workspace_start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  folder   = var.project_dir
  order    = 1
  settings = {
    "workbench.colorTheme" : "Default Dark Modern"
  }
}

# --- Windsurf ---

module "windsurf" {
  count    = var.workspace_start_count
  source   = "registry.coder.com/coder/windsurf/coder"
  version  = "1.3.0"
  agent_id = coder_agent.main.id
}

# --- Cursor ---

module "cursor" {
  count    = var.workspace_start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.4.0"
  agent_id = coder_agent.main.id
}

# --- JetBrains ---

module "jetbrains" {
  count      = var.workspace_start_count
  source     = "registry.coder.com/coder/jetbrains/coder"
  version    = "~> 1.0"
  agent_id   = coder_agent.main.id
  agent_name = "main"
  folder     = var.project_dir
}
