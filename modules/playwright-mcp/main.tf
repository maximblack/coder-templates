# Config-only module — no resources, just computes MCP JSON for claude-code.

locals {
  base_args = ["@playwright/mcp@latest"]

  flag_args = compact([
    var.headless ? "" : "--no-headless",
    var.browser != "chromium" ? "--browser=${var.browser}" : "",
    var.viewport_width != 1280 ? "--viewport-size=${var.viewport_width},${var.viewport_height}" : "",
  ])

  args = concat(local.base_args, local.flag_args)
}
