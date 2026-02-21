# --- Preview App ---

resource "coder_app" "preview" {
  agent_id     = coder_agent.main.id
  slug         = "preview"
  display_name = var.preview_display_name
  icon         = var.preview_icon
  url          = "http://localhost:${var.preview_port}"
  share        = "authenticated"
  subdomain    = true
  open_in      = "tab"
  order        = 0
  healthcheck {
    url       = "http://localhost:${var.preview_port}/"
    interval  = 5
    threshold = 15
  }
}
