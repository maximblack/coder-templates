resource "coder_app" "preview" {
  agent_id     = coder_agent.main.id
  slug         = "preview"
  display_name = "Preview"
  icon         = "/icon/globe.svg"
  url          = "http://localhost:${data.coder_parameter.preview_port.value}"
  subdomain    = true

  healthcheck {
    url       = "http://localhost:${data.coder_parameter.preview_port.value}/healthz"
    interval  = 5
    threshold = 3
  }
}
