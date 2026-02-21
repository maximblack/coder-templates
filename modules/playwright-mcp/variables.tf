variable "headless" {
  type        = bool
  description = "Run browser in headless mode"
  default     = true
}

variable "browser" {
  type        = string
  description = "Browser to use (chromium, firefox, webkit)"
  default     = "chromium"
}

variable "viewport_width" {
  type        = number
  description = "Browser viewport width in pixels"
  default     = 1280
}

variable "viewport_height" {
  type        = number
  description = "Browser viewport height in pixels"
  default     = 720
}
