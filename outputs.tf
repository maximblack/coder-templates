output "agent_id" {
  value       = coder_agent.main.id
  description = "The ID of the Coder agent"
}

output "project_dir" {
  value       = data.coder_parameter.project_dir.value
  description = "The project directory path"
}
