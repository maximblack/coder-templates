resource "coder_app" "preview" {
  agent_id     = coder_agent.main.id
  slug         = "preview"
  display_name = "Preview"
  icon         = "/icon/globe.svg"
  url          = "http://localhost:${var.preview_port}"
  subdomain    = true

  healthcheck {
    url       = "http://localhost:${var.preview_port}/healthz"
    interval  = 5
    threshold = 3
  }
}
