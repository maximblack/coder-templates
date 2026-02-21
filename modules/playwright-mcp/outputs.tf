output "mcp_config" {
  description = "MCP configuration JSON for the claude-code module"
  value = jsonencode({
    mcpServers = {
      playwright = {
        command = "npx"
        args    = local.args
      }
    }
  })
}
