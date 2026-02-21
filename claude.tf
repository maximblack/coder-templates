module "claude-code" {
  count                   = var.workspace_start_count
  source                  = "registry.coder.com/coder/claude-code/coder"
  version                 = "4.7.5"
  agent_id                = coder_agent.main.id
  workdir                 = var.project_dir
  claude_code_oauth_token = var.oauth_token
  system_prompt           = var.system_prompt
  ai_prompt               = var.ai_prompt
}

resource "coder_ai_task" "task" {
  count  = var.ai_prompt != "" ? 1 : 0
  app_id = module.claude-code[0].task_app_id
}
