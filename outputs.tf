output "agent_id" {
  value       = coder_agent.main.id
  description = "The ID of the Coder agent"
}

output "project_dir" {
  value       = var.project_dir
  description = "The project directory path"
}
