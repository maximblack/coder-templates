module "claude-code" {
  count          = var.workspace_start_count
  source         = "registry.coder.com/coder/claude-code/coder"
  version        = "4.7.5"
  agent_id       = coder_agent.main.id
  folder         = data.coder_parameter.project_dir.value
  oauth2_token   = var.oauth_token
  system_prompt  = data.coder_parameter.system_prompt.value
}

resource "coder_ai_task" "task" {
  count    = var.ai_prompt != "" ? 1 : 0
  sidebar_app {
    id    = module.claude-code[0].app_id
    agent_id = coder_agent.main.id
  }
}
