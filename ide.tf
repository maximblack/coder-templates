module "code-server" {
  count    = var.workspace_start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "1.4.2"
  agent_id = coder_agent.main.id
  folder   = data.coder_parameter.project_dir.value
}

module "cursor" {
  count    = var.workspace_start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.4.0"
  agent_id = coder_agent.main.id
  folder   = data.coder_parameter.project_dir.value
}

module "windsurf" {
  count    = var.workspace_start_count
  source   = "registry.coder.com/coder/windsurf/coder"
  version  = "1.3.0"
  agent_id = coder_agent.main.id
  folder   = data.coder_parameter.project_dir.value
}

module "jetbrains" {
  count    = var.workspace_start_count
  source   = "registry.coder.com/coder/jetbrains/coder"
  version  = "1.3.0"
  agent_id = coder_agent.main.id
  folder   = data.coder_parameter.project_dir.value
}
