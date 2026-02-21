# --- Claude Code ---

module "claude-code" {
  count                  = var.workspace_start_count
  source                 = "registry.coder.com/coder/claude-code/coder"
  version                = "4.7.5"
  agent_id               = coder_agent.main.id
  workdir                = var.project_dir
  order                  = 999
  claude_api_key         = ""
  ai_prompt              = var.ai_prompt
  system_prompt          = var.system_prompt
  model                  = "sonnet"
  permission_mode        = "plan"
  post_install_script    = var.setup_script
  claude_code_oauth_token = var.oauth_token
}

# --- AI Task ---

resource "coder_ai_task" "task" {
  count  = var.workspace_start_count
  app_id = module.claude-code[count.index].task_app_id
}
